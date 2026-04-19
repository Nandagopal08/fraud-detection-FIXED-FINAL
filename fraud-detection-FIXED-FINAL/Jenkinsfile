// Jenkinsfile
// Paper-aligned CI/CD pipeline: Kim et al. 2022, Section 3.3
// Stages mirror Figure 7 (Jenkins automation job list):
//   Checkout → Build Image → Test → Push to Docker Hub → Deploy → Verify

pipeline {
    agent any

    environment {
        DOCKERHUB_USER = 'ameyab16'                          // ← CHANGE TO YOUR DOCKERHUB USERNAME
        IMAGE_NAME     = "${DOCKERHUB_USER}/fraud-api"
        IMAGE_TAG      = "${BUILD_NUMBER}"
        REGISTRY_CREDS = 'dockerhub-credentials'             // Jenkins credential ID
    }

    stages {

        // ── Stage 1: Checkout ───────────────────────────────────────
        stage('Checkout') {
            steps {
                echo '📥 Checking out source code...'
                checkout scm
            }
        }

        // ── Stage 2: Build Docker Image ─────────────────────────────
        // Paper Figure 8: "docker build -t ... -f Dockerfile"
        stage('Build Docker Image') {
            steps {
                echo '🐳 Building Docker image (trains ML model inside)...'
                sh """
                    docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .
                    docker tag  ${IMAGE_NAME}:${IMAGE_TAG} ${IMAGE_NAME}:latest
                    echo "✅ Built ${IMAGE_NAME}:${IMAGE_TAG}"
                """
            }
        }

        // ── Stage 3: Test – Health & Predict Endpoints ──────────────
        // Paper Section 4.3: Rest-API endpoints /health /prediction /score
        stage('Test - API Smoke Test') {
            steps {
                echo '🧪 Running container smoke test...'
                sh """
                    # Start a throwaway test container on port 5001
                    docker run -d --name test-fraud-api-${BUILD_NUMBER} \\
                        -p 5001:5000 \\
                        ${IMAGE_NAME}:${IMAGE_TAG}

                    # Model trains during Docker build so 30s is enough at runtime
                    echo "Waiting 45s for API startup..."
                    sleep 45

                    # ── Health check ──────────────────────────────────
                    HEALTH=\$(curl -sf http://localhost:5001/health | \\
                        python3 -c "import sys,json; print(json.load(sys.stdin).get('status',''))" 2>/dev/null || echo "fail")
                    echo "Health status: \$HEALTH"
                    [ "\$HEALTH" = "healthy" ] || { docker logs test-fraud-api-${BUILD_NUMBER}; docker rm -f test-fraud-api-${BUILD_NUMBER}; exit 1; }

                    # ── Predict endpoint (/api/predict) ───────────────
                    # Paper Section 4.3: Prediction outputs results of four ML models
                    PRED=\$(curl -sf -X POST http://localhost:5001/api/predict \\
                        -H "Content-Type: application/json" \\
                        -d '{"amount": 150}' | \\
                        python3 -c "import sys,json; print(json.load(sys.stdin).get('success',''))" 2>/dev/null || echo "fail")
                    echo "Predict success: \$PRED"
                    [ "\$PRED" = "True" ] || { docker logs test-fraud-api-${BUILD_NUMBER}; docker rm -f test-fraud-api-${BUILD_NUMBER}; exit 1; }

                    # ── Metrics endpoint (Prometheus scrape target) ────
                    METRICS_STATUS=\$(curl -so /dev/null -w "%{http_code}" http://localhost:5001/metrics)
                    echo "Metrics HTTP status: \$METRICS_STATUS"
                    [ "\$METRICS_STATUS" = "200" ] || { echo "❌ /metrics returned \$METRICS_STATUS"; docker rm -f test-fraud-api-${BUILD_NUMBER}; exit 1; }

                    echo "✅ All tests passed"
                    docker rm -f test-fraud-api-${BUILD_NUMBER}
                """
            }
        }

        // ── Stage 4: Push to Docker Hub ─────────────────────────────
        // Paper Figure 8-9: "docker push jmk9996/smartfactory_capstone" → Docker Hub registry
        stage('Push to Docker Hub') {
            steps {
                echo '📤 Pushing image to Docker Hub registry...'
                withCredentials([usernamePassword(
                    credentialsId: "${REGISTRY_CREDS}",
                    usernameVariable: 'DOCKER_USER',
                    passwordVariable: 'DOCKER_PASS'
                )]) {
                    sh """
                        echo "\$DOCKER_PASS" | docker login -u "\$DOCKER_USER" --password-stdin
                        docker push ${IMAGE_NAME}:${IMAGE_TAG}
                        docker push ${IMAGE_NAME}:latest
                        docker logout
                        echo "✅ Pushed ${IMAGE_NAME}:${IMAGE_TAG} and :latest to Docker Hub"
                    """
                }
            }
        }

        // ── Stage 5: Deploy with Docker Compose ─────────────────────
        // Paper Section 3.3: "deployment, management, scaling via Docker Swarm/Compose"
        stage('Deploy with Docker Compose') {
            steps {
                echo '🚀 Deploying stack with Docker Compose...'
                sh """
                    export IMAGE_TAG=${IMAGE_TAG}
                    export DOCKERHUB_USER=${DOCKERHUB_USER}

                    # Pull latest pushed image
                    docker pull ${IMAGE_NAME}:${IMAGE_TAG}

                    # Rolling update - only restart fraud-api service
                    # (Prometheus/Grafana/Portainer keep running)
                    docker compose up -d --no-deps --force-recreate fraud-api

                    echo "✅ Deployment triggered"
                """
            }
        }

        // ── Stage 6: Post-Deploy Verification ───────────────────────
        stage('Post-Deploy Verification') {
            steps {
                echo '🔍 Verifying deployed service...'
                sh """
                    # Allow up to 90s for the new container to become healthy
                    for i in \$(seq 1 9); do
                        STATUS=\$(curl -sf http://localhost:5000/health | \\
                            python3 -c "import sys,json; print(json.load(sys.stdin)['status'])" 2>/dev/null || echo "starting")
                        echo "Check \$i/9: \$STATUS"
                        [ "\$STATUS" = "healthy" ] && break
                        sleep 10
                    done
                    [ "\$STATUS" = "healthy" ] || echo "⚠️  Service still starting — check http://localhost:5000/health manually"
                    echo "Deployed service status: \$STATUS"
                """
            }
        }
    }

    post {
        always {
            echo '🧹 Pruning dangling Docker images...'
            sh 'docker image prune -f || true'
        }
        success {
            echo """
✅ PIPELINE SUCCESS
Image     : ${IMAGE_NAME}:${IMAGE_TAG}
Dashboard : http://localhost:5000
Grafana   : http://localhost:3000   (admin/admin)
Prometheus: http://localhost:9090
Portainer : http://localhost:9000
Jenkins   : http://localhost:8080
"""
        }
        failure {
            echo '❌ Pipeline failed — check stage logs above'
            sh "docker rm -f test-fraud-api-${BUILD_NUMBER} || true"
        }
    }
}
