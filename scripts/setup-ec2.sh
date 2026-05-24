#!/bin/bash
set -e

# FamPay SRE - Complete Setup Script
# Run on Amazon Linux 2023 EC2 instance
# Usage: chmod +x scripts/setup-ec2.sh && ./scripts/setup-ec2.sh

echo "============================================"
echo "  FamPay SRE - EC2 Setup Script"
echo "============================================"
echo ""

# Step 1: System updates
echo "[1/8] Updating system packages..."
sudo yum update -y

# Step 2: Install Docker
echo "[2/8] Installing Docker..."
sudo yum install -y docker
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker $USER
echo "Docker installed: $(docker --version)"

# Step 3: Install Terraform
echo "[3/8] Installing Terraform..."
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
sudo yum install -y terraform
echo "Terraform installed: $(terraform --version | head -1)"

# Step 4: Install kubectl
echo "[4/8] Installing kubectl..."
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm -f kubectl
echo "kubectl installed: $(kubectl version --client 2>/dev/null | head -1)"

# Step 5: Install Helm
echo "[5/8] Installing Helm..."
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
echo "Helm installed: $(helm version --short)"

# Step 6: Install AWS CLI (already on Amazon Linux, but update)
echo "[6/8] Updating AWS CLI..."
if ! command -v aws &> /dev/null; then
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    sudo yum install -y unzip
    unzip -q awscliv2.zip
    sudo ./aws/install
    rm -rf aws awscliv2.zip
fi
echo "AWS CLI installed: $(aws --version)"

# Step 7: Install oha (load testing)
echo "[7/8] Installing oha..."
curl -sL https://github.com/hatoo/oha/releases/download/v1.4.1/oha-linux-amd64 -o oha
chmod +x oha
sudo mv oha /usr/local/bin/
echo "oha installed"

# Step 8: Install docker-compose
echo "[8/8] Installing docker-compose..."
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
echo "docker-compose installed: $(docker-compose --version)"

# Install git
sudo yum install -y git

echo ""
echo "============================================"
echo "  All tools installed successfully!"
echo "============================================"
echo ""
echo "Next steps:"
echo "  1. Log out and log back in (for docker group): exit, then SSH again"
echo "  2. Configure AWS: aws configure"
echo "  3. Clone repo: git clone <your-repo-url>"
echo "  4. cd fampay-sre-assignment"
echo "  5. Run: ./scripts/infra.sh apply"
echo "  6. Run: ./scripts/deploy.sh production"
echo ""
