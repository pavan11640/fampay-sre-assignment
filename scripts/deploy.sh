#!/bin/bash
set -e

# FamPay SRE - One-click deployment script
# Usage: ./scripts/deploy.sh [environment]

ENVIRONMENT=${1:-production}
AWS_REGION="ap-south-1"
CLUSTER_NAME="fampay-${ENVIRONMENT}"
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
IMAGE_TAG=$(git rev-parse --short HEAD)

echo "=== FamPay Deployment ==="
echo "Environment: ${ENVIRONMENT}"
echo "Cluster: ${CLUSTER_NAME}"
echo "Image Tag: ${IMAGE_TAG}"
echo ""

# Step 1: Build and push images
echo "[1/4] Building and pushing Docker images..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REGISTRY

docker build -t $ECR_REGISTRY/fampay/hodr:$IMAGE_TAG ./apps/hodr
docker build -t $ECR_REGISTRY/fampay/bran:$IMAGE_TAG ./apps/bran

docker push $ECR_REGISTRY/fampay/hodr:$IMAGE_TAG
docker push $ECR_REGISTRY/fampay/bran:$IMAGE_TAG

# Step 2: Update kubeconfig
echo "[2/4] Configuring kubectl..."
aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME

# Step 3: Deploy with Helm
echo "[3/4] Deploying with Helm..."
helm upgrade --install fampay ./helm/fampay \
  --namespace fampay \
  --create-namespace \
  --set hodr.image.repository=$ECR_REGISTRY/fampay/hodr \
  --set hodr.image.tag=$IMAGE_TAG \
  --set bran.image.repository=$ECR_REGISTRY/fampay/bran \
  --set bran.image.tag=$IMAGE_TAG \
  --wait --timeout 300s

# Step 4: Verify
echo "[4/4] Verifying deployment..."
kubectl get pods -n fampay
kubectl get ingress -n fampay

echo ""
echo "=== Deployment Complete ==="
