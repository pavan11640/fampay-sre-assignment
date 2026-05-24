#!/bin/bash
set -e

# FamPay SRE - Infrastructure provisioning script
# Usage: ./scripts/infra.sh [plan|apply|destroy]

ACTION=${1:-plan}
TF_DIR="environments/production"

echo "=== FamPay Infrastructure ==="
echo "Action: ${ACTION}"
echo "Directory: ${TF_DIR}"
echo ""

cd $TF_DIR

# Initialize
echo "[1/2] Initializing Terraform..."
terraform init

# Execute action
echo "[2/2] Running terraform ${ACTION}..."
case $ACTION in
  plan)
    terraform plan
    ;;
  apply)
    terraform apply -auto-approve
    echo ""
    echo "Cluster ready. Run:"
    echo "  $(terraform output -raw configure_kubectl)"
    ;;
  destroy)
    terraform destroy -auto-approve
    ;;
  *)
    echo "Usage: $0 [plan|apply|destroy]"
    exit 1
    ;;
esac

echo ""
echo "=== Infrastructure ${ACTION} Complete ==="
