# FamPay SRE Assignment - Documentation

## Author: Pavan
## Repository: https://github.com/pavan11640/fampay-sre-assignment.git

---

## 1. Overview

This project deploys two microservices (Hodr & Bran) on AWS EKS with:
- Production-grade Docker containers
- Kubernetes orchestration with auto-scaling
- Infrastructure as Code (Terraform)
- CI/CD automation (GitHub Actions)
- Monitoring & Alerting (Prometheus + Grafana)
- Network security policies
- Single URL access via Ingress

---

## 2. Architecture

```
Internet → NLB (AWS) → Nginx Ingress Controller → /hodr/* → Hodr Pods (2-10)
                                                 → /bran/* → Bran Pods (2-10)
```

**Infrastructure:**
- VPC: 10.0.0.0/16 with 2 public + 2 private subnets across 2 AZs
- EKS Cluster: Kubernetes 1.31, 2-5 t3.medium worker nodes
- ECR: Container registries for both services
- Region: ap-south-1 (Mumbai)

---

## 3. Services

| Service | Language | Port | Image Size | Endpoint |
|---------|----------|------|-----------|----------|
| Hodr | Go 1.21 | 8888 | 10.6 MB | `/hodr/*` |
| Bran | Python/Django | 8000 | 160 MB | `/bran/*` |

---

## 4. Dockerfiles (Production-Grade)

### Hodr (Go)
- Multi-stage build: golang:1.21-alpine → gcr.io/distroless/static:nonroot
- Static binary compilation (CGO_ENABLED=0)
- Stripped debug symbols (-ldflags="-s -w")
- Non-root user (UID 65532)
- Final image: **10.6 MB**

### Bran (Django)
- Multi-stage build: python:3.12-slim (builder) → python:3.12-slim (runtime)
- Poetry for dependency management
- Gunicorn WSGI server (3 workers, 120s timeout)
- Non-root user (UID 1000)
- Final image: **160 MB**

---

## 5. Orchestration & Deployment Strategy

### Kubernetes Resources
- **Deployments**: 2 replicas each (high availability)
- **Services**: ClusterIP (internal only)
- **Ingress**: Nginx ingress controller with path-based routing
- **HPA**: Auto-scale 2→10 pods (CPU > 70%, Memory > 80%)
- **NetworkPolicy**: Bran → Hodr allowed, Hodr → Bran blocked

### Deployment Flow
```
1. terraform apply          → Creates VPC, EKS, ECR
2. docker build & push      → Images to ECR
3. helm install             → Deploys to EKS
4. Ingress controller       → Exposes single URL
```

### Rolling Updates (Zero Downtime)
- Helm upgrade triggers rolling deployment
- New pods start before old ones terminate
- Readiness probes ensure traffic only goes to healthy pods
- Rollback: `helm rollback fampay`

---

## 6. Scaling Strategy

### Pod Auto-scaling (HPA)
```yaml
minReplicas: 2
maxReplicas: 10
metrics:
  - cpu: 70% utilization
  - memory: 80% utilization
```

### Node Auto-scaling
- EKS Managed Node Group: 2 min, 5 max nodes (t3.medium)
- Cluster Autoscaler adds nodes when pods are pending

### Load Testing
```bash
./scripts/load-test.sh http://<ingress-url>
# Uses oha for HTTP benchmarking
```

---

## 7. Network Security

| From | To | Allowed | Enforcement |
|------|----|---------|-------------|
| Internet → Hodr | ✅ | Via Ingress only |
| Internet → Bran | ✅ | Via Ingress only |
| Bran → Hodr | ✅ | NetworkPolicy allows |
| Hodr → Bran | ❌ | NetworkPolicy blocks |
| Direct pod access | ❌ | ClusterIP services |

---

## 8. Secrets & Configuration Management

### Current Implementation
- **ConfigMaps**: Non-sensitive config (ALLOWED_HOSTS, DEBUG, TIME_ZONE)
- **Kubernetes Secrets**: Sensitive data (SECRET_KEY, DATABASE_URL)
- **Helm values**: Environment-specific overrides

### Updating Secrets Across Fleet
1. Update `helm/fampay/values.yaml`
2. Run `helm upgrade fampay ./helm/fampay` → triggers rolling update
3. All pods pick up new env vars on restart (zero-downtime)

### Production Recommendation (Large Fleet)
- Use **AWS Secrets Manager** + **External Secrets Operator**
- Secrets sync automatically from AWS to K8s
- `kubectl rollout restart deployment/bran -n fampay` for immediate propagation

---

## 9. CI/CD Pipeline

### GitHub Actions Workflow
```
Push to main branch
    │
    ├── [Parallel] Build Hodr → Push to ECR (tagged with git SHA)
    ├── [Parallel] Build Bran → Push to ECR (tagged with git SHA)
    │
    └── Deploy to EKS via Helm (--wait ensures rollout completes)
```

### Pipeline Features
- Triggered on push to `main`
- Parallel Docker builds
- Immutable image tags (git SHA)
- Helm deploy with `--wait` (fails if rollout fails)
- Separate Terraform pipeline for infrastructure changes

---

## 10. Monitoring & Alerting

### Metrics
- Both services expose `/metrics` (Prometheus format)
- Prometheus scrapes via pod annotations

### Alert Rules
| Alert | Condition | Severity |
|-------|-----------|----------|
| HighErrorRate | 5xx > 5% for 2min | Critical |
| HighLatency | p95 > 5s for 3min | Warning |
| PodCrashLooping | Restarts in 15min | Critical |
| HighCPUUsage | > 80% for 5min | Warning |
| HighMemoryUsage | > 85% limit for 5min | Warning |
| HPAMaxedOut | At max replicas 10min | Warning |

### Local Monitoring Stack
```bash
cd monitoring && docker-compose up
# Prometheus: localhost:9090
# Grafana: localhost:3000 (admin/admin)
# Alertmanager: localhost:9093
```

---

## 11. Infrastructure as Code (Terraform)

### Modules
| Module | Resources |
|--------|-----------|
| `modules/vpc` | VPC, 4 subnets, IGW, NAT, route tables |
| `modules/eks` | EKS cluster, IAM roles, managed node group |
| `modules/ecr` | ECR repositories with lifecycle policies |

### Commands
```bash
# Provision
cd environments/production
terraform init && terraform apply

# Destroy
terraform destroy

# Configure kubectl
aws eks update-kubeconfig --region ap-south-1 --name fampay-production
```

---

## 12. One-Click Deployment

```bash
# Full infrastructure + application deployment
./scripts/deploy.sh production
```

This single command:
1. Builds Docker images
2. Pushes to ECR
3. Configures kubectl
4. Deploys via Helm
5. Verifies deployment

---

## 13. Local Development

```bash
# Run everything locally
docker-compose up --build

# Access:
# http://localhost/hodr/ → Hodr service
# http://localhost/bran/ → Bran service
# http://localhost/health → Health check
```

---

## 14. Production Deployment Evidence

### Terraform Output
```
cluster_endpoint = "https://6DF9D626BBCB8B0007BC01230507567C.gr7.ap-south-1.eks.amazonaws.com"
cluster_name = "fampay-production"
ecr_repository_urls = {
  "bran" = "789343098570.dkr.ecr.ap-south-1.amazonaws.com/fampay/bran"
  "hodr" = "789343098570.dkr.ecr.ap-south-1.amazonaws.com/fampay/hodr"
}
vpc_id = "vpc-01d160894c902e945"
```

### Kubernetes Nodes
```
NAME                                        STATUS   ROLES    AGE   VERSION
ip-10-0-44-53.ap-south-1.compute.internal   Ready    <none>   26m   v1.31.14-eks-3385e9b
ip-10-0-59-27.ap-south-1.compute.internal   Ready    <none>   26m   v1.31.14-eks-3385e9b
```

### Running Pods
```
NAME                           READY   STATUS    AGE
fampay-bran-796cf4979d-crl2t   1/1     Running   10m
fampay-bran-796cf4979d-lln79   1/1     Running   10m
fampay-hodr-6f76b95479-68gmt   1/1     Running   14m
fampay-hodr-6f76b95479-lwf64   1/1     Running   14m
```

### Auto-scaling (HPA)
```
NAME          REFERENCE                MINPODS   MAXPODS   REPLICAS
fampay-bran   Deployment/fampay-bran   2         10        2
fampay-hodr   Deployment/fampay-hodr   2         10        2
```

### Network Policies
```
NAME                 POD-SELECTOR
allow-hodr-ingress   app=hodr
deny-hodr-to-bran    app=bran
```

### Service Access
```
URL: http://a8d4c772dd03e4db58c675b0f4f2545f-88d8d4424c82c724.elb.ap-south-1.amazonaws.com

GET /hodr/ → "hodor... hodor... hodor"
GET /bran/ → [] (empty user list - JSON response)
```

### Docker Images
```
fampay/hodr:v2   10.6MB  (distroless)
fampay/bran:v2   160MB   (python-slim)
```

---

## 15. Prerequisites

- AWS CLI configured
- Terraform >= 1.5.0
- Helm >= 3.13
- kubectl
- Docker
- oha (load testing)
