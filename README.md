# FamPay SRE Assignment

Production-grade deployment of two microservices (Hodr & Bran) with high availability, auto-scaling, and observability.

## Architecture

```
                    ┌─────────────────────────────────────────┐
                    │              AWS Cloud                    │
                    │                                          │
Internet ──────►   │  ┌──────────────────────────────────┐   │
                    │  │     EKS Cluster (fampay-prod)     │   │
                    │  │                                    │   │
                    │  │  ┌────────────┐                   │   │
                    │  │  │  Ingress   │                   │   │
                    │  │  │  (nginx)   │                   │   │
                    │  │  └─────┬──────┘                   │   │
                    │  │        │                           │   │
                    │  │   ┌────┴────┐                     │   │
                    │  │   │         │                     │   │
                    │  │   ▼         ▼                     │   │
                    │  │ ┌─────┐  ┌─────┐                 │   │
                    │  │ │Hodr │  │Bran │──►Hodr (allowed)│   │
                    │  │ │(Go) │  │(Py) │                 │   │
                    │  │ └─────┘  └─────┘                 │   │
                    │  │  2-10     2-10                    │   │
                    │  │  pods     pods                    │   │
                    │  └──────────────────────────────────┘   │
                    │                                          │
                    │  ┌──────┐  ┌─────┐  ┌───────────────┐  │
                    │  │ ECR  │  │ VPC │  │ Prometheus +   │  │
                    │  │      │  │     │  │ Grafana        │  │
                    │  └──────┘  └─────┘  └───────────────┘  │
                    └─────────────────────────────────────────┘
```

## Services

| Service | Language | Port | Endpoint | Description |
|---------|----------|------|----------|-------------|
| Hodr | Go 1.21 | 8888 | `/hodr/*` | HTTP service returning "hodor" |
| Bran | Python/Django | 8000 | `/bran/*` | REST API listing users |

## Quick Start (Local Docker)

```bash
docker-compose up --build
```

- http://localhost/hodr/ → Hodr service
- http://localhost/bran/ → Bran service
- http://localhost/health → Nginx health check

## Project Structure

```
├── apps/
│   ├── hodr/                  # Go service + Dockerfile
│   └── bran/                  # Django service + Dockerfile
├── docker/
│   └── nginx/nginx.conf       # Reverse proxy config
├── kubernetes/
│   └── base/                  # Raw K8s manifests (kustomize)
├── helm/
│   └── fampay/                # Helm umbrella chart
│       ├── charts/hodr/       # Hodr subchart
│       └── charts/bran/       # Bran subchart
├── modules/                   # Terraform modules
│   ├── vpc/                   # VPC + subnets
│   ├── eks/                   # EKS cluster + nodes
│   └── ecr/                   # Container registries
├── environments/
│   └── production/            # Production Terraform config
├── monitoring/
│   ├── prometheus/            # Metrics collection
│   ├── grafana/               # Dashboards
│   └── alerting/              # Alert rules + Alertmanager
├── scripts/
│   ├── deploy.sh              # One-click deployment
│   ├── infra.sh               # Infrastructure provisioning
│   └── load-test.sh           # Load testing with oha
├── .github/workflows/
│   ├── ci-cd.yaml             # Build + Deploy pipeline
│   └── terraform.yaml         # Infrastructure pipeline
└── docker-compose.yml         # Local development
```

## Deployment Strategy

### Infrastructure Provisioning (One-time)

```bash
# Provision AWS infrastructure
./scripts/infra.sh apply
```

This creates:
- VPC with public/private subnets across 2 AZs
- EKS cluster (K8s 1.28)
- Managed node group (2-5 t3.medium instances)
- ECR repositories for both services

### Application Deployment

```bash
# One-click deploy
./scripts/deploy.sh production
```

Or via CI/CD: Push to `main` branch triggers automatic build and deploy.

### Helm Deployment (Manual)

```bash
helm upgrade --install fampay ./helm/fampay \
  --namespace fampay --create-namespace
```

## Scaling Strategy

### Horizontal Pod Autoscaling (HPA)
- Both services scale from 2 to 10 pods
- Triggers: CPU > 70% or Memory > 80%
- Configured in `helm/fampay/charts/*/templates/hpa.yaml`

### Node Auto-scaling
- EKS managed node group: 2 min, 5 max nodes
- Cluster Autoscaler adds nodes when pods are pending
- Configured in `modules/eks/main.tf`

### Load Testing

```bash
./scripts/load-test.sh http://localhost
```

## Network Policy (Security)

| From | To | Allowed |
|------|----|---------|
| Ingress → Hodr | ✅ | Via nginx ingress controller |
| Ingress → Bran | ✅ | Via nginx ingress controller |
| Bran → Hodr | ✅ | Direct pod-to-pod |
| Hodr → Bran | ❌ | **Blocked by NetworkPolicy** |
| External → Pods | ❌ | Only via Ingress |

## Secrets & Configuration Management

### Strategy
- **ConfigMaps** for non-sensitive config (ALLOWED_HOSTS, DEBUG, TIME_ZONE)
- **Kubernetes Secrets** for sensitive data (SECRET_KEY, DATABASE_URL)
- **Helm values** override per environment

### Updating Secrets Across Fleet
1. Update values in `helm/fampay/values.yaml` or use external secrets manager
2. Run `helm upgrade` — triggers rolling update across all pods
3. Pods pick up new env vars on restart (zero-downtime via rolling strategy)

For large fleets, use **AWS Secrets Manager** + **External Secrets Operator**:
```bash
# Secrets sync automatically from AWS Secrets Manager to K8s Secrets
# All pods referencing the secret get rolling-restarted
kubectl rollout restart deployment/bran -n fampay
```

## CI/CD Pipeline

```
Push to main
    │
    ├── Build Hodr image → Push to ECR
    ├── Build Bran image → Push to ECR
    │
    └── Deploy to EKS via Helm (tagged with git SHA)
```

- **Trigger**: Push to `main` branch
- **Build**: Parallel Docker builds for both services
- **Deploy**: Helm upgrade with `--wait` (waits for rollout)
- **Rollback**: `helm rollback fampay` if deployment fails

## Monitoring & Alerting

### Metrics Collection
- Both services expose `/metrics` (Prometheus format)
- Prometheus scrapes pods via annotations

### Alerts
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
cd monitoring
docker-compose up
```
- Prometheus: http://localhost:9090
- Grafana: http://localhost:3000 (admin/admin)
- Alertmanager: http://localhost:9093

## Production Checklist

- [x] Multi-stage Docker builds (minimal images)
- [x] Non-root containers
- [x] Health checks (liveness + readiness probes)
- [x] Resource limits and requests
- [x] Horizontal Pod Autoscaling
- [x] Node auto-scaling (EKS managed)
- [x] Network policies (zero-trust)
- [x] Single URL ingress routing
- [x] Bran → Hodr allowed, Hodr → Bran blocked
- [x] Secrets management
- [x] CI/CD automation
- [x] Infrastructure as Code (Terraform)
- [x] Monitoring and alerting
- [x] One-click deployment

## Prerequisites

- AWS CLI configured
- Terraform >= 1.5.0
- Helm >= 3.13
- kubectl
- Docker
- oha (for load testing)
