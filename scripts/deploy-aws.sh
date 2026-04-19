#!/bin/bash
# ─────────────────────────────────────────────────────────────────
# deploy-aws.sh
# Full AWS deployment: Terraform → Upload CSV → Ansible → Done
# Mirrors paper: AWS EC2 T2.medium, ap-northeast-2, 25GB SSD
# ─────────────────────────────────────────────────────────────────
set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1"; exit 1; }
info() { echo -e "${BLUE}[→]${NC} $1"; }

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║        FRAUD DETECTION — AWS DEPLOYMENT (Paper Replica)     ║"
echo "║  Terraform → Ansible → Docker → Jenkins → Kubernetes         ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# ── Pre-flight checks ─────────────────────────────────────────────
command -v terraform >/dev/null 2>&1 || err "terraform not installed. Download: https://developer.hashicorp.com/terraform/downloads"
command -v ansible-playbook >/dev/null 2>&1 || err "ansible not installed. Run: pip install ansible"

if [ ! -f "creditcard.csv" ]; then
  err "creditcard.csv not found!\nDownload: https://www.kaggle.com/datasets/mlg-ulb/creditcardfraud\nPlace in: $PROJECT_ROOT/"
fi

if [ ! -f "terraform/terraform.tfvars" ]; then
  err "terraform/terraform.tfvars not found!\nRun: cp terraform/terraform.tfvars.example terraform/terraform.tfvars\nThen edit it and set key_pair_name."
fi

# ── Step 1: Terraform ─────────────────────────────────────────────
info "Step 1/4 — Running Terraform (provisions AWS EC2)..."
cd terraform
terraform init -upgrade
terraform apply -auto-approve
PUBLIC_IP=$(terraform output -raw public_ip)
cd "$PROJECT_ROOT"
log "EC2 provisioned. Public IP: $PUBLIC_IP"

# ── Step 2: Update Ansible inventory ─────────────────────────────
info "Step 2/4 — Updating Ansible inventory with IP: $PUBLIC_IP"
KEY_FILE=$(grep private_key_file ansible/ansible.cfg | awk -F'=' '{print $2}' | tr -d ' ')
sed -i "s/SERVER_IP/$PUBLIC_IP/g" ansible/inventory.ini
log "Inventory updated"

# ── Step 3: Wait for EC2 SSH ──────────────────────────────────────
info "Waiting for EC2 SSH to become available (~60s)..."
for i in $(seq 1 12); do
  ssh -i "$KEY_FILE" -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
    ec2-user@$PUBLIC_IP "echo ok" >/dev/null 2>&1 && break
  echo "  SSH attempt $i/12..."
  sleep 10
done
log "SSH is up"

# ── Step 4: Upload creditcard.csv ────────────────────────────────
info "Step 3/4 — Uploading creditcard.csv to server..."
ssh -i "$KEY_FILE" -o StrictHostKeyChecking=no ec2-user@$PUBLIC_IP \
  "mkdir -p /home/ec2-user/fraud-detection"
scp -i "$KEY_FILE" -o StrictHostKeyChecking=no \
  creditcard.csv ec2-user@$PUBLIC_IP:/home/ec2-user/fraud-detection/
log "Dataset uploaded"

# ── Step 5: Ansible ───────────────────────────────────────────────
info "Step 4/4 — Running Ansible playbook (installs Docker, Jenkins, deploys stack)..."
cd ansible
ansible-playbook site.yml
cd "$PROJECT_ROOT"
log "Ansible complete"

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║               AWS DEPLOYMENT COMPLETE                       ║"
echo "╠══════════════════════════════════════════╦═══════════════════╣"
echo "║  Service                                 ║  URL              ║"
echo "╠══════════════════════════════════════════╬═══════════════════╣"
echo "║  🔍 Fraud API                            ║  :5000            ║"
echo "║  📈 Prometheus                           ║  :9090            ║"
echo "║  📊 Grafana (admin/admin)                ║  :3000            ║"
echo "║  🐳 Portainer                            ║  :9000            ║"
echo "║  🔧 Jenkins                              ║  :8080            ║"
echo "╚══════════════════════════════════════════╩═══════════════════╝"
echo ""
echo "  Public IP: $PUBLIC_IP"
echo "  SSH:       ssh -i $KEY_FILE ec2-user@$PUBLIC_IP"
echo ""
log "Done! Open http://$PUBLIC_IP:5000"
