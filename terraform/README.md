# Terraform Infrastructure

## Structure

```
modules/              # Reusable modules
├── vpc/              # VPC, subnets, NAT, route tables
├── eks/              # EKS cluster + managed node group
└── ecr/              # ECR repositories with lifecycle policies

environments/         # Environment-specific configurations
└── production/       # Production environment
```

## Prerequisites

1. AWS CLI configured with appropriate credentials
2. Terraform >= 1.5.0 installed
3. S3 bucket for state: `fampay-terraform-state`
4. DynamoDB table for locking: `fampay-terraform-locks`

## Usage

```bash
# Initialize (first time)
cd environments/production
terraform init

# Plan changes
terraform plan

# Apply infrastructure
terraform apply

# Configure kubectl after cluster creation
aws eks update-kubeconfig --region ap-south-1 --name fampay-production
```

## Destroy

```bash
cd environments/production
terraform destroy
```
