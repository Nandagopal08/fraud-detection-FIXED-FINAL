# Fraud Detection — Complete Fix Guide & Proof Walkthrough

> **Three bugs fixed, serial proof screenshots listed, step-by-step commands explained.**

---

## What Was Fixed (Summary)

| # | Problem | Root Cause | Fix Applied |
|---|---------|-----------|-------------|
| 1 | `kubectl` gives SSL/certificate errors | Stale or corrupted Minikube cluster certs | `deploy-kubernetes.sh` now detects broken SSL, deletes+recreates cluster with `--embed-certs` |
| 2 | Jenkins shows no password in terminal | `JAVA_OPTS=-Djenkins.install.runSetupWizard=false` was suppressing password generation | Removed that flag; deploy script now auto-waits and prints the password |
| 3 | cAdvisor failing to get metrics | Modern Linux kernels block `perf_event` subsystem in containers; missing `/dev/kmsg` device | Added `--disable_metrics=perf_event,...`, `/dev/kmsg` device mount, and `--docker_only=true` |

---

## Prerequisites (Install These First)

Run all commands in your terminal/PowerShell. Check each with its version command.

```bash
# 1. Docker Desktop — must be RUNNING before anything else
docker --version          # should print Docker version 24.x or higher

# 2. kubectl
kubectl version --client  # should print Client Version

# 3. Minikube
minikube version          # should print minikube version

# 4. Git (to clone/manage the project)
git --version
```

**Windows users:** Use PowerShell or Git Bash. Do NOT use CMD for bash scripts.

---

## PART 1 — Local Docker Compose Deployment (Run This First)

### Where to run:
Open a terminal, `cd` into the project root (the folder containing `docker-compose.yml`).

```
fraud-detection-fixed/       ← you must be HERE
├── docker-compose.yml
├── Dockerfile
├── creditcard.csv            ← REQUIRED — download from Kaggle first
├── scripts/
│   └── deploy-local.sh
...
```

### Step 0 — Download the dataset

Download `creditcard.csv` from:
https://www.kaggle.com/datasets/mlg-ulb/creditcardfraud

Place it directly in the project root folder (same folder as `docker-compose.yml`).

### Step 1 — Run the deployment script

**Linux / Mac / WSL:**
```bash
cd /path/to/fraud-detection-fixed
bash scripts/deploy-local.sh
```

**Windows (PowerShell):**
```powershell
cd C:\path\to\fraud-detection-fixed
.\deploy-local.bat
```

The script will:
1. Build the Docker image (trains the ML model inside the image)
2. Create the `monitoring` Docker network
3. Start all services (Fraud API, Prometheus, Grafana, Portainer, cAdvisor)
4. Start Jenkins
5. **Auto-print the Jenkins password** (FIX #2 applied here)
6. Wait for the Fraud API to become healthy

### Step 2 — Verify all services are up

Run each of these commands and check the output:

```bash
# See all running containers
docker ps

# Expected output — all 6 containers should show "Up" and "healthy":
# fraud-api       Up X minutes (healthy)
# prometheus      Up X minutes
# grafana         Up X minutes
# portainer       Up X minutes
# cadvisor        Up X minutes
# jenkins         Up X minutes
```

### Step 3 — Get Jenkins password (if you missed it in the script output)

```bash
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

This prints a 32-character string like: `a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4`

---

## PART 2 — Service-by-Service Proof (Serial Order)

Follow this exact order to generate screenshots/proofs for each tool.

---

### PROOF 1 — Fraud Detection API (:5000)

**URL:** http://localhost:5000

**Command to verify in terminal:**
```bash
curl http://localhost:5000/health
# Expected: {"status":"healthy","model_loaded":true,...}

curl -X POST http://localhost:5000/api/predict \
  -H "Content-Type: application/json" \
  -d '{"amount": 500}'
# Expected: {"success":true,"fraud_probability":...}
```

**Screenshot to take:** Open http://localhost:5000 in browser → shows the fraud detection dashboard.

---

### PROOF 2 — Prometheus (:9090)

**URL:** http://localhost:9090

**Command to verify:**
```bash
curl http://localhost:9090/-/healthy
# Expected: Prometheus Server is Healthy.
```

**Browser steps for screenshot:**
1. Go to http://localhost:9090/targets
2. All targets should show status **UP** (fraud-api, prometheus, cadvisor)
3. Screenshot this "Targets" page — this is your Prometheus proof

**If cadvisor shows DOWN on Prometheus targets:**
```bash
# Restart cadvisor with the fixed compose file
docker compose up -d --force-recreate cadvisor
# Wait 15 seconds, then refresh the targets page
```

---

### PROOF 3 — Grafana (:3000)

**URL:** http://localhost:3000  
**Login:** `admin` / `admin`

**Browser steps for screenshot:**
1. Log in at http://localhost:3000
2. The fraud dashboard auto-loads (pre-configured in the provisioning folder)
3. Screenshot the dashboard showing graphs/panels with data

**If dashboard is empty (no data yet):**
```bash
# Generate some traffic to the API first
for i in {1..10}; do
  curl -s -X POST http://localhost:5000/api/predict \
    -H "Content-Type: application/json" \
    -d "{\"amount\": $((RANDOM % 1000))}" > /dev/null
done
# Wait 30 seconds, then refresh Grafana
```

---

### PROOF 4 — Portainer (:9000)

**URL:** http://localhost:9000

**First-time setup:**
1. Open http://localhost:9000
2. Create a new admin password (set anything you want, minimum 12 characters)
3. Click "Get Started" → click on the "local" environment
4. You will see all running containers listed

**Screenshot to take:** The "Containers" page showing all 6 containers running.

---

### PROOF 5 — cAdvisor (:8088) — FIX #3 APPLIED HERE

**URL:** http://localhost:8088

**The Fix:** The original `docker-compose.yml` was missing `--disable_metrics=perf_event` and `/dev/kmsg` device. Modern Linux kernels block container access to the `perf_event` subsystem causing the "failed to get metrics" error. The fixed compose file disables those broken metrics collectors and mounts the kernel message device properly.

**Command to verify fix:**
```bash
# Check cAdvisor logs — should NOT show "Failed to get" errors anymore
docker logs cadvisor 2>&1 | grep -i "fail\|error" | head -20

# Check it's serving metrics
curl -s http://localhost:8088/metrics | head -20
# Expected: lines starting with "container_cpu_usage_seconds_total" etc.
```

**Browser steps for screenshot:**
1. Open http://localhost:8088
2. Click on "Docker Containers"
3. Click on any container (e.g., "fraud-api")
4. Screenshot the CPU/memory graphs — this is your cAdvisor proof

---

### PROOF 6 — Jenkins (:8080) — FIX #2 APPLIED HERE

**URL:** http://localhost:8080

**The Fix:** The original `docker-compose.jenkins.yml` had `JAVA_OPTS=-Djenkins.install.runSetupWizard=false`. This flag skips the setup wizard which means Jenkins never wrote the `initialAdminPassword` file and never prompted for it — resulting in a blank password prompt with nothing showing in terminal. The fix removes this flag so Jenkins runs its normal first-time setup.

**Steps:**
1. Get the password:
   ```bash
   docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
   ```
   Copy the printed password.

2. Open http://localhost:8080

3. Paste the password into the "Unlock Jenkins" page and click Continue

4. Click "Install suggested plugins" (wait ~3 minutes for plugins to install)

5. Create your admin user account

**Screenshot to take:** The Jenkins dashboard after login showing the main page.

**To set up the CI/CD pipeline:**
```
Manage Jenkins → Credentials → System → Global → Add Credentials
  Kind: Username with password
  ID: dockerhub-credentials
  Username: <your DockerHub username>
  Password: <your DockerHub password>

New Item → Enter name "fraud-detection" → Pipeline → OK
Pipeline → Definition: Pipeline script from SCM
SCM: Git → Repository URL: <your git repo URL>
Script Path: Jenkinsfile
Save → Build Now
```

---

## PART 3 — Kubernetes Deployment — FIX #1 APPLIED HERE

**The Fix:** The SSL/SSH compliance error happens because:
- Old Minikube clusters generate self-signed certificates that expire or get corrupted
- `kubectl` refuses to connect because the cert does not match
- The fix: the script detects this, deletes the broken cluster, and starts fresh with `--embed-certs` which embeds valid certs directly into the kubeconfig

### Where to run:
Same project root, but **Kubernetes is separate from Docker Compose** — you can run both at the same time or just one.

### Step 1 — Run the fixed Kubernetes deployment script

```bash
bash scripts/deploy-kubernetes.sh
```

This will:
1. Check if Minikube is running
2. **Test if kubectl SSL connection works** — if not, delete and recreate
3. Start Minikube with `--embed-certs` (prevents SSL errors)
4. Apply all Kubernetes manifests (namespace, deployments, services)
5. Print the Minikube IP and NodePort URLs

### Step 2 — Verify Kubernetes is working

```bash
# Check all pods are Running
kubectl get pods -n fraud-detection
# Expected (after ~2 minutes):
# fraud-api-xxxxx   1/1   Running   0   2m
# prometheus-xxxxx  1/1   Running   0   2m
# grafana-xxxxx     1/1   Running   0   2m
# portainer-xxxxx   1/1   Running   0   2m

# Check services have NodePorts assigned
kubectl get services -n fraud-detection
# Expected: each service shows the NodePort (30500, 30909, 30300, 30900)

# Get Minikube IP
minikube ip
# Example output: 192.168.49.2
```

### Step 3 — Access Kubernetes services

Replace `MINIKUBE_IP` with the actual IP from `minikube ip`:

| Service | URL |
|---------|-----|
| Fraud API | http://MINIKUBE_IP:30500 |
| Prometheus | http://MINIKUBE_IP:30909 |
| Grafana | http://MINIKUBE_IP:30300 |
| Portainer | http://MINIKUBE_IP:30900 |

```bash
# Test from terminal
MINIKUBE_IP=$(minikube ip)
curl http://$MINIKUBE_IP:30500/health
```

### If kubectl SSL error persists after the script:

Run these commands manually, in order:

```bash
# Step A: Completely wipe the broken cluster
minikube delete

# Step B: Start fresh with embedded certs
minikube start --driver=docker --cpus=2 --memory=3072 --embed-certs

# Step C: Verify the connection works
kubectl cluster-info

# Step D: Apply manifests again
cd /path/to/fraud-detection-fixed
kubectl apply -f kubernetes/namespace.yml
kubectl apply -f kubernetes/fraud-api-deployment.yml
kubectl apply -f kubernetes/fraud-api-service.yml
kubectl apply -f kubernetes/prometheus-deployment.yml
kubectl apply -f kubernetes/prometheus-service.yml
kubectl apply -f kubernetes/grafana-deployment.yml
kubectl apply -f kubernetes/grafana-service.yml
kubectl apply -f kubernetes/portainer-deployment.yml
```

### PROOF 7 — Kubernetes proof screenshot

```bash
# These two commands together are your Kubernetes proof:
kubectl get pods -n fraud-detection
kubectl get services -n fraud-detection
```

Screenshot the terminal showing all pods with status `Running`.

---

## PART 4 — Stopping Everything

```bash
# Stop main Docker Compose stack
docker compose down

# Stop Jenkins
docker compose -f jenkins/docker-compose.jenkins.yml down

# Stop Minikube (Kubernetes)
minikube stop

# Full reset (deletes all data/volumes — use only if starting over)
docker compose down -v
docker compose -f jenkins/docker-compose.jenkins.yml down -v
minikube delete
```

---

## Proof Screenshot Checklist (Serial Order)

| # | Tool | What to Screenshot | URL |
|---|------|--------------------|-----|
| 1 | **Fraud API** | Dashboard homepage or `/health` JSON in browser | http://localhost:5000 |
| 2 | **Prometheus** | Targets page showing fraud-api + cadvisor both UP | http://localhost:9090/targets |
| 3 | **Grafana** | Pre-loaded fraud dashboard with live graphs | http://localhost:3000 |
| 4 | **Portainer** | Containers list showing all 6 containers | http://localhost:9000 |
| 5 | **cAdvisor** | Container CPU/memory graphs for fraud-api | http://localhost:8088 |
| 6 | **Jenkins** | Dashboard after first login, or pipeline build | http://localhost:8080 |
| 7 | **Kubernetes** | Terminal output of `kubectl get pods -n fraud-detection` | terminal |

---

## Quick Troubleshooting

| Symptom | Command to diagnose | Fix |
|---------|--------------------|----|
| Container not starting | `docker logs <container-name>` | Read the error, usually a port conflict |
| Port already in use | `docker ps -a` | `docker rm -f <old-container>` |
| cAdvisor still failing | `docker logs cadvisor 2>&1 \| grep -i fail` | Run `docker compose up -d --force-recreate cadvisor` |
| Jenkins password blank | Nothing in `/var/jenkins_home/secrets/` | Wait 60s then retry; or `docker restart jenkins` |
| kubectl SSL error | `kubectl cluster-info` shows TLS error | `minikube delete && minikube start --embed-certs` |
| Grafana no data | Prometheus targets down | Check `docker logs prometheus` for config errors |
| API not healthy | `docker logs fraud-api` | Usually still training model — wait 90s |
