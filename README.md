# Fraud Detection — Cloud Docker Application
### Based on: Kim et al. 2022 — *"Design and Implementation of Cloud Docker Application Architecture Based on Machine Learning in Container Management for Smart Manufacturing"*


- ML model → Logistic Regression trained on Bank Fraud (creditcard.csv)
- Monitoring → Prometheus + Grafana (replaces paper's DataDog)
- Added cAdvisor for container CPU/memory metrics (matches paper Figures 14–16)

---

## Architecture (mirrors paper Figure 3)

```
┌─────────────────────────────────────────────────────────────────┐
│                      AWS Cloud (Terraform)                      │
│   EC2 T2.medium │ ap-northeast-2 │ 25GB SSD  ← paper Table 2  │
│                                                                  │
│  ┌──────────────┐  ┌─────────────┐  ┌──────────┐  ┌─────────┐ │
│  │  fraud-api   │  │ Prometheus  │  │ Grafana  │  │Portainer│ │
│  │  Flask+ML    │  │  :9090      │  │  :3000   │  │  :9000  │ │
│  │  :5000       │  └─────────────┘  └──────────┘  └─────────┘ │
│  └──────────────┘         ↑                                     │
│        ↑           scrapes /metrics                             │
│  ┌─────────┐  ┌──────────┐  ┌──────────┐  ┌─────────────────┐ │
│  │ Jenkins │  │Docker Hub│  │cAdvisor  │  │   Kubernetes    │ │
│  │  :8080  │  │ Registry │  │  :8088   │  │   (Minikube)    │ │
│  └─────────┘  └──────────┘  └──────────┘  └─────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

**CI/CD Flow** (paper Figure 7-8):
`Jenkins` → `docker build` (trains model) → `docker push` → `Docker Hub` → `docker compose up`

---

## Prerequisites

| Tool | Purpose | Install |
|---|---|---|
| Docker Desktop | Run containers | [docker.com](https://www.docker.com/products/docker-desktop/) |
| creditcard.csv | Training dataset | [Kaggle](https://www.kaggle.com/datasets/mlg-ulb/creditcardfraud) |
| Terraform | AWS EC2 provisioning | [terraform.io](https://developer.hashicorp.com/terraform/downloads) |
| Ansible | Server configuration | `pip install ansible` |
| kubectl | Kubernetes CLI | [kubernetes.io](https://kubernetes.io/docs/tasks/tools/) |
| Minikube | Local Kubernetes | [minikube.sigs.k8s.io](https://minikube.sigs.k8s.io/docs/start/) |

---

##  — Local Deployment 

```bash
 Run one-command deployment
bash scripts/deploy-local.sh          # Mac/Linux
# OR
deploy-local.bat                      # Windows CMD/PowerShell
```

**Services after deployment:**

| Service | URL | Credentials |
|---|---|---|
| Fraud Detection Dashboard | http://localhost:5000 | — |
| Prometheus | http://localhost:9090 | — |
| Grafana | http://localhost:3000 | admin / admin |
| Portainer | http://localhost:9000 | Set on first login |
| Jenkins | http://localhost:8080 | See step below |
| cAdvisor | http://localhost:8088 | — |

**Jenkins first-time setup:**
```bash
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

---

## Option B — AWS Deployment (Full Paper Reproduction)

```bash
# 1. Configure Terraform
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# Edit terraform.tfvars: set key_pair_name = "your-aws-keypair"

# 2. Edit Ansible config
# ansible/ansible.cfg: set private_key_file = ~/.ssh/your-key.pem

# 3. Run full deployment (Terraform + upload CSV + Ansible)
bash scripts/deploy-aws.sh
```

This provisions EC2 (matching paper Table 2 exactly), uploads the dataset, installs Docker + Jenkins + Minikube, and deploys the full stack.

---

## Option C — Kubernetes Only

```bash
# Requires: Docker image pushed to Docker Hub, Minikube installed
bash scripts/deploy-kubernetes.sh
```

Access via Minikube NodePorts:

| Service | NodePort |
|---|---|
| fraud-api | 30500 |
| Prometheus | 30909 |
| Grafana | 30300 |
| Portainer | 30900 |

---

## Jenkins CI/CD Pipeline Setup

1. Start Jenkins: `docker compose -f jenkins/docker-compose.jenkins.yml up -d`
2. Open http://localhost:8080
3. Get initial password: `docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword`
4. Install suggested plugins
5. **Add DockerHub credentials:**
   - Manage Jenkins → Credentials → System → Global → Add Credentials
   - Kind: Username with password
   - ID: `dockerhub-credentials`
   - Username/Password: your Docker Hub login
6. **Create Pipeline job:**
   - New Item → Pipeline
   - Pipeline → Definition: Pipeline script from SCM
   - SCM: Git → enter your repo URL
   - Script Path: `Jenkinsfile`
7. **Edit `Jenkinsfile`:** change `DOCKERHUB_USER = 'ameyab16'` to your Docker Hub username
8. Click **Build Now**

---

## Paper-to-Project Mapping

| Paper Section | Paper Component | This Project |
|---|---|---|
| Table 2 | EC2 T2.medium, ap-northeast-2, 25GB SSD | `terraform/main.tf` |
| Figure 3 | System Architecture | `docker-compose.yml` |
| Figure 4 | Docker Container key features | `Dockerfile` |
| Figure 7 | Jenkins automation job list | `Jenkinsfile` |
| Figure 8 | docker build/run + Docker Hub push | Jenkinsfile stages 2+4 |
| Figure 9 | Docker Hub registry | `ameyab16/fraud-api` on Docker Hub |
| Figure 11 | ML model → Docker image → container | `train_model.py` + `Dockerfile` |
| Figure 12 | REST API documentation | `/api/predict`, `/api/stats`, `/health` |
| Figure 13 | DataDog monitoring (replaced) | Prometheus + Grafana |
| Figure 14-16 | CPU/memory/execution time graphs | cAdvisor + Grafana |
| Section 3.3 | Portainer management UI | Portainer container |

---

## API Endpoints

| Endpoint | Method | Description |
|---|---|---|
| `/` | GET | Interactive dashboard |
| `/api/predict` | POST | `{"amount": 500}` → fraud prediction |
| `/api/stats` | GET | Aggregate transaction stats |
| `/api/transactions` | GET | Recent transaction history |
| `/health` | GET | Health check (model/scaler/dataset loaded) |
| `/metrics` | GET | Prometheus metrics (scraped every 5s) |
| `/api/info` | GET | Model info |

---

## Stopping Everything

```bash
# Stop main stack
docker compose down

# Stop Jenkins
docker compose -f jenkins/docker-compose.jenkins.yml down

# Stop all + remove volumes (full reset)
docker compose down -v
docker compose -f jenkins/docker-compose.jenkins.yml down -v
```
