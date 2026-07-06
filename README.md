# AstroNova — Full-Stack Kubernetes Deployment

A production-grade Books Management application deployed on a kubeadm-based Kubernetes cluster on AWS, with HTTPS via Let's Encrypt, load-balanced across worker nodes, and fully automated with Terraform and Helm.

**Live URL:** [https://astronova.15.206.176.33.nip.io](https://astronova.15.206.176.33.nip.io)

---

## Architecture Diagram

```
                        ┌──────────────────────────────────┐
                        │          User's Browser          │
                        └────────────────┬─────────────────┘
                                         │
                                    HTTPS (443)
                                         │
                        ┌────────────────▼─────────────────┐
                        │     AWS Network Load Balancer     │
                        │     Elastic IP: 15.206.176.33     │
                        └──────┬─────────────────┬─────────┘
                               │                 │
                          Port 30443         Port 30443
                               │                 │
               ┌───────────────▼──┐      ┌───────▼──────────────┐
               │   Worker Node 1  │      │   Worker Node 2      │
               │  (EC2 t3.medium) │      │  (EC2 t3.medium)     │
               │                  │      │                      │
               │ ┌──────────────┐ │      │ ┌──────────────┐     │
               │ │NGINX Ingress │ │      │ │NGINX Ingress │     │
               │ │  Controller  │ │      │ │  Controller  │     │
               │ └──────┬───────┘ │      │ └──────┬───────┘     │
               │        │         │      │        │             │
               │  ┌─────▼──────┐  │      │  ┌─────▼──────┐     │
               │  │  Frontend  │  │      │  │  Frontend  │     │
               │  │  (Vue.js)  │  │      │  │  (Vue.js)  │     │
               │  └────────────┘  │      │  └────────────┘     │
               │  ┌────────────┐  │      │  ┌────────────┐     │
               │  │  Backend   │  │      │  │  Backend   │     │
               │  │ (FastAPI)  │  │      │  │ (FastAPI)  │     │
               │  └────────────┘  │      │  └────────────┘     │
               └──────────────────┘      └──────────────────────┘

               ┌──────────────────────────────────────────────────┐
               │              Control Plane Node                  │
               │             (EC2 t3.medium)                      │
               │                                                  │
               │  kube-apiserver  etcd  kube-scheduler            │
               │  kube-controller-manager  cert-manager           │
               └──────────────────────────────────────────────────┘
```

**Traffic Flow:**
1. Browser resolves `astronova.15.206.176.33.nip.io` → `15.206.176.33` (Elastic IP)
2. AWS NLB forwards port 443 to NodePort 30443 on **both** worker nodes (round-robin)
3. NGINX Ingress Controller terminates TLS using the Let's Encrypt certificate
4. Ingress routes `/api/*` → Backend Service, `/` → Frontend Service
5. Kubernetes Services load-balance across 2 replicas of each pod

---

## Project Structure

```
assignment_1/
├── .github/workflows/          # CI/CD Pipelines
│   ├── ci.yml                  # Lint, test, build, push Docker images
│   └── cd.yml                  # Deploy to Kubernetes via Helm
├── backend/                    # FastAPI REST API
│   ├── Dockerfile
│   ├── requirements.txt
│   ├── app/
│   │   ├── main.py             # FastAPI app entry point
│   │   ├── models.py           # Pydantic schemas
│   │   ├── store.py            # In-memory data store
│   │   ├── logging_config.py   # Structured JSON logging & middleware
│   │   └── routes/
│   │       ├── books.py        # CRUD endpoints
│   │       └── health.py       # Health check endpoint
│   └── tests/
│       └── test_books.py       # pytest unit tests (20 tests)
├── frontend/                   # Vue.js SPA
│   ├── Dockerfile
│   ├── nginx.conf              # NGINX reverse proxy config
│   ├── package.json
│   └── src/
│       ├── App.vue
│       ├── main.js
│       ├── services/api.js     # Axios API client
│       └── components/
│           ├── BookCard.vue
│           └── BookForm.vue
├── terraform/                  # Infrastructure as Code
│   ├── main.tf                 # EC2 instances + security groups
│   ├── nlb.tf                  # Network Load Balancer
│   ├── variables.tf            # Input variable definitions
│   ├── outputs.tf              # Instance IPs + SSH commands
│   ├── nlb_outputs.tf          # Load Balancer IP + DNS
│   └── terraform.tfvars.example
├── helm/astronova/             # Helm chart
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/
│       ├── _helpers.tpl
│       ├── backend-deployment.yaml
│       ├── backend-service.yaml
│       ├── frontend-deployment.yaml
│       ├── frontend-service.yaml
│       ├── configmap.yaml
│       ├── ingress.yaml
│       └── network-policy.yaml # Network policies (default deny + whitelist)
├── k8s/                        # Kubernetes manifests
│   ├── cluster-issuer.yaml     # Let's Encrypt ClusterIssuer
│   ├── ingress.yaml            # Standalone ingress (alternative)
│   └── ingress-setup.sh        # NGINX Ingress + cert-manager installer
├── scripts/
│   ├── k8s-setup.sh            # kubeadm cluster bootstrap script
│   └── deploy.sh               # End-to-end deployment automation
├── .gitignore
└── README.md
```

---

## Deployment Steps

### Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| Docker | 20+ | Build container images |
| Terraform | 1.5+ | Provision AWS infrastructure |
| Helm | 3.x | Deploy Kubernetes applications |
| kubectl | 1.30 | Interact with the K8s cluster |
| AWS CLI | 2.x | Manage AWS resources |

### Step 1: Clone and Configure

```bash
git clone <repository-url>
cd assignment_1

# Configure AWS credentials
aws configure

# Create terraform.tfvars from the example
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# Edit terraform.tfvars with your key_name and ami_id
```

### Step 2: Build and Push Docker Images

```bash
# Login to Docker Hub
docker login

# Build and push backend
docker build -t <username>/astronova_backend:latest ./backend
docker push <username>/astronova_backend:latest

# Build and push frontend
docker build --build-arg VITE_API_URL="" -t <username>/astronova_frontend:latest ./frontend
docker push <username>/astronova_frontend:latest
```

### Step 3: Provision AWS Infrastructure

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

This creates:
- 3 EC2 instances (1 control plane, 2 workers)
- 3 security groups (SSH, Web, K8s inter-node)
- 1 Network Load Balancer with Elastic IP
- Target groups attaching both workers on ports 30080/30443

### Step 4: Bootstrap Kubernetes with kubeadm

```bash
# Copy setup script to all nodes
scp -i ~/.ssh/astronova scripts/k8s-setup.sh ubuntu@<CONTROL_PLANE_IP>:~/
scp -i ~/.ssh/astronova scripts/k8s-setup.sh ubuntu@<WORKER_1_IP>:~/
scp -i ~/.ssh/astronova scripts/k8s-setup.sh ubuntu@<WORKER_2_IP>:~/

# Initialize control plane
ssh -i ~/.ssh/astronova ubuntu@<CONTROL_PLANE_IP>
sudo ./k8s-setup.sh init
# Save the 'kubeadm join' command from the output

# Join worker nodes
ssh -i ~/.ssh/astronova ubuntu@<WORKER_1_IP>
sudo ./k8s-setup.sh install
sudo kubeadm join <CP_PRIVATE_IP>:6443 --token <token> --discovery-token-ca-cert-hash <hash>

# Repeat for Worker 2
```

### Step 5: Install Ingress and cert-manager

```bash
# On the control plane node
scp -i ~/.ssh/astronova -r k8s ubuntu@<CONTROL_PLANE_IP>:~/
ssh -i ~/.ssh/astronova ubuntu@<CONTROL_PLANE_IP>
bash ~/k8s/ingress-setup.sh
```

This installs:
- NGINX Ingress Controller (NodePort 30080/30443)
- cert-manager with CRDs
- Let's Encrypt production ClusterIssuer

### Step 6: Deploy with Helm

```bash
# Copy Helm chart to control plane
scp -i ~/.ssh/astronova -r helm/astronova ubuntu@<CONTROL_PLANE_IP>:~/

# Deploy
ssh -i ~/.ssh/astronova ubuntu@<CONTROL_PLANE_IP>
helm upgrade --install astronova ~/astronova
```

### Automated Deployment

All steps above can be run via the master script:

```bash
./scripts/deploy.sh
```

Flags: `--skip-build`, `--skip-infra`, `--skip-k8s-setup`

---

## Kubernetes Architecture

### Nodes

| Role | Count | Instance | Purpose |
|------|-------|----------|---------|
| Control Plane | 1 | t3.medium | Runs kube-apiserver, etcd, scheduler, controller-manager |
| Worker | 2 | t3.medium | Runs application pods |

### Pods and Replicas

| Component | Replicas | Image |
|-----------|----------|-------|
| Backend (FastAPI) | 2 | `manojcs197/astronova_backend:latest` |
| Frontend (Vue.js + NGINX) | 2 | `manojcs197/astronova_frontend:latest` |
| NGINX Ingress Controller | 2 | `registry.k8s.io/ingress-nginx/controller` |
| cert-manager | 1 | `quay.io/jetstack/cert-manager-controller` |

### Services

| Service | Type | Port | Target |
|---------|------|------|--------|
| astronova-backend | ClusterIP | 8000 | Backend pods |
| astronova-frontend | ClusterIP | 80 | Frontend pods |
| ingress-nginx-controller | NodePort | 30080 (HTTP), 30443 (HTTPS) | Ingress pods |

### Networking

- **CNI Plugin:** Flannel (VXLAN overlay, pod CIDR `10.244.0.0/16`)
- **Service Discovery:** CoreDNS resolves service names to ClusterIPs
- **External Access:** NLB → NodePort → Ingress → Service → Pod

---

## Terraform Explanation

### `main.tf`

Defines the core AWS resources:
- Uses the **default VPC** and a public subnet
- Creates 3 **security groups**: SSH access, web traffic (80/443 + NodePorts), and Kubernetes inter-node communication (API server 6443, etcd 2379-2380, kubelet 10250, VXLAN 8472)
- Provisions **3 EC2 instances** from Ubuntu 22.04 AMI with 30GB gp3 encrypted volumes, tagged as `control-plane`, `worker-1`, `worker-2`

### `nlb.tf`

Provisions the **Network Load Balancer** for production access:
- Allocates an **Elastic IP** for a stable public address
- Creates HTTP and HTTPS **target groups** pointing to NodePorts 30080 and 30443
- Attaches **both worker nodes** to each target group for load balancing
- Listens on standard ports **80 and 443** so users don't need custom port numbers

### `variables.tf`

Parameterizes: `aws_region`, `instance_type`, `key_name`, `ami_id`, `allowed_ssh_cidr`, `project_name`, `environment`, `root_volume_size`

### `outputs.tf` + `nlb_outputs.tf`

Prints after `terraform apply`: public/private IPs of all 3 nodes, SSH commands, security group IDs, load balancer IP and DNS name

---

## Helm Deployment Guide

### Chart Structure

The `helm/astronova/` chart packages the entire application:

- `values.yaml` — Central configuration (image repos, replica counts, ingress host, resource limits)
- `templates/_helpers.tpl` — Reusable label definitions
- `templates/backend-deployment.yaml` — 2-replica Deployment with health probes
- `templates/backend-service.yaml` — ClusterIP Service on port 8000
- `templates/frontend-deployment.yaml` — 2-replica Deployment with health probes
- `templates/frontend-service.yaml` — ClusterIP Service on port 80
- `templates/configmap.yaml` — Stores `BACKEND_URL` for frontend
- `templates/ingress.yaml` — NGINX Ingress with TLS and cert-manager annotation

### Install

```bash
helm upgrade --install astronova ./helm/astronova
```

### Customize

```bash
helm upgrade --install astronova ./helm/astronova \
  --set ingress.host="yourdomain.com" \
  --set backend.replicaCount=3 \
  --set frontend.image.tag="v2.0.0"
```

### Uninstall

```bash
helm uninstall astronova
```

---

## API Documentation

**Base URL:** `https://astronova.15.206.176.33.nip.io`

**Interactive Docs:** [/docs](https://astronova.15.206.176.33.nip.io/docs) (Swagger UI)

### Endpoints

| Method | Endpoint | Description | Status Codes |
|--------|----------|-------------|--------------|
| `GET` | `/api/books` | List all books | 200 |
| `GET` | `/api/books/{id}` | Get a book by ID | 200, 404 |
| `POST` | `/api/books` | Create a new book | 201, 422 |
| `PATCH` | `/api/books/{id}` | Update a book partially | 200, 400, 404 |
| `DELETE` | `/api/books/{id}` | Delete a book | 204, 404 |
| `GET` | `/health` | Health check | 200 |

### Book Schema

```json
{
  "id": "auto-generated UUID",
  "title": "string (required, 1-300 chars)",
  "author": "string (required, 1-200 chars)",
  "isbn": "string (optional, max 20 chars)",
  "publishedYear": "integer (optional, 1000-2100)"
}
```

### Example: Create a Book

```bash
curl -X POST https://astronova.15.206.176.33.nip.io/api/books \
  -H "Content-Type: application/json" \
  -d '{"title": "Kubernetes in Action", "author": "Marko Luksa", "publishedYear": 2018}'
```

### Example: List All Books

```bash
curl https://astronova.15.206.176.33.nip.io/api/books
```

---

## HTTPS / TLS Implementation

| Component | Detail |
|-----------|--------|
| Certificate Authority | Let's Encrypt (Production) |
| Certificate Manager | cert-manager v1.x |
| ClusterIssuer | `letsencrypt-prod` (ACME HTTP-01 solver) |
| TLS Termination | NGINX Ingress Controller |
| HTTP → HTTPS Redirect | Enabled via `nginx.ingress.kubernetes.io/ssl-redirect: "true"` |

The Ingress resource includes `cert-manager.io/cluster-issuer: "letsencrypt-prod"` annotation. cert-manager automatically:
1. Creates a `Certificate` resource
2. Initiates an ACME HTTP-01 challenge
3. Stores the signed certificate in the `astronova-tls` Kubernetes Secret
4. NGINX Ingress loads the certificate for TLS termination

---

## In-Memory Store: Multi-Replica Considerations

The current backend uses a Python dictionary (`books_db`) as its data store. With `replicaCount: 2`, each pod maintains its own independent copy of the store. This means:

- A book created via Pod A is **not visible** from Pod B
- Deleting a book on one pod leaves it accessible on the other
- The NLB/Ingress round-robins requests, so users see **inconsistent data**

### Production Solutions

| Approach | Pros | Cons | Effort |
|----------|------|------|--------|
| **Redis (Recommended)** | Shared state, sub-millisecond reads, easy Helm chart | Adds a dependency | Low |
| **PostgreSQL / MySQL** | ACID compliance, persistent data | Heavier, schema migrations | Medium |
| **Sticky Sessions** | No backend changes needed | Breaks if pod restarts, uneven load | Low |
| **SQLite + PVC** | Simple, no extra service | Single-writer limitation, can't scale replicas | Low |

#### Recommended: Redis Shared Store

```python
# store.py — Redis-backed implementation
import json
import os
import redis

redis_client = redis.Redis(
    host=os.getenv("REDIS_HOST", "localhost"),
    port=int(os.getenv("REDIS_PORT", 6379)),
    db=0,
    decode_responses=True,
)

def get_all_books():
    keys = redis_client.keys("book:*")
    return [json.loads(redis_client.get(k)) for k in keys]

def get_book(book_id: str):
    data = redis_client.get(f"book:{book_id}")
    return json.loads(data) if data else None

def create_book(book_id: str, book: dict):
    redis_client.set(f"book:{book_id}", json.dumps(book))

def delete_book(book_id: str):
    redis_client.delete(f"book:{book_id}")
```

Add Redis to the Helm chart:

```yaml
# values.yaml
redis:
  enabled: true
  image: redis:7-alpine
  port: 6379
```

#### Alternative: Sticky Sessions (Quick Fix)

```yaml
# ingress.yaml annotation
nginx.ingress.kubernetes.io/affinity: "cookie"
nginx.ingress.kubernetes.io/session-cookie-name: "astronova-session"
nginx.ingress.kubernetes.io/session-cookie-max-age: "3600"
```

> **Note:** For this demo, the in-memory store is intentional to keep the focus on Kubernetes infrastructure. The solutions above would be applied before any production deployment.

---

## Security Considerations

### SSH Access

The `allowed_ssh_cidr` Terraform variable defaults to `0.0.0.0/0` for demo convenience. **In production:**

```hcl
# terraform.tfvars — restrict to your IP or VPN CIDR
allowed_ssh_cidr = "203.0.113.50/32"  # Your office/VPN IP
```

### NodePort Exposure

The web security group currently allows `0.0.0.0/0` on the NodePort range (30000–32767). **Production hardening:**

```hcl
# Restrict NodePorts to NLB subnets only
ingress {
  description = "NodePort range - NLB only"
  from_port   = 30000
  to_port     = 32767
  protocol    = "tcp"
  cidr_blocks = ["<NLB_SUBNET_CIDR>"]  # e.g., "172.31.0.0/16"
}
```

### Additional Production Recommendations

| Area | Recommendation |
|------|---------------|
| **SSH** | Replace SSH keys with AWS SSM Session Manager (no open ports needed) |
| **Secrets** | Use Kubernetes Secrets or AWS Secrets Manager for sensitive config |
| **RBAC** | Implement Kubernetes RBAC with least-privilege service accounts |
| **Pod Security** | Enable Pod Security Standards (restricted profile) |
| **Image Scanning** | Scan Docker images with Trivy or Snyk in CI pipeline |
| **Audit Logging** | Enable Kubernetes audit logging for compliance |

---

## CI/CD Pipeline

GitHub Actions workflows are defined in `.github/workflows/`:

### CI Pipeline (`ci.yml`)

Triggered on every push to `main`/`develop` and on pull requests:

```
┌──────────────┐    ┌───────────────┐    ┌────────────┐
│ Backend Test  │    │ Frontend Build│    │ Helm Lint  │
│              │    │               │    │            │
│ • flake8     │    │ • npm ci      │    │ • helm lint│
│ • pytest     │    │ • npm build   │    │ • template │
└──────┬───────┘    └──────┬────────┘    └──────┬─────┘
       │                   │                    │
       └───────────────────┼────────────────────┘
                           │
                    ┌──────▼──────┐
                    │ Docker Build │  (main branch only)
                    │ & Push       │
                    │              │
                    │ • backend    │
                    │ • frontend   │
                    └──────────────┘
```

### CD Pipeline (`cd.yml`)

Triggered after successful CI on `main`:

1. Copies Helm chart to control plane via SSH
2. Runs `helm upgrade --install` with the new image tag (`$GITHUB_SHA`)
3. Verifies rollout status for both deployments
4. Runs a smoke test against `/health`

### Required GitHub Secrets

| Secret | Description |
|--------|-------------|
| `DOCKER_USERNAME` | Docker Hub username |
| `DOCKER_TOKEN` | Docker Hub access token |
| `SSH_PRIVATE_KEY` | SSH key for control plane access |
| `CONTROL_PLANE_HOST` | Public IP of the K8s control plane |

---

## Network Policies

Network policies are defined in `helm/astronova/templates/network-policy.yaml` and enabled by default (`networkPolicies.enabled: true`).

### Policy Summary

```
┌─────────────────────────────────────────────────┐
│               Default: DENY ALL                 │
│              Ingress Traffic                     │
└─────────────────────────────────────────────────┘

Exceptions:

  ingress-nginx namespace ──► Frontend pods (port 80)
  ingress-nginx namespace ──► Backend pods  (port 8000)
  Frontend pods            ──► Backend pods  (port 8000)
```

| Policy | From | To | Port |
|--------|------|----|------|
| Default deny | * | * | — (blocked) |
| Backend ingress | Frontend pods | Backend | 8000 |
| Backend ingress | ingress-nginx namespace | Backend | 8000 |
| Frontend ingress | ingress-nginx namespace | Frontend | 80 |

To disable:
```bash
helm upgrade astronova ./helm/astronova --set networkPolicies.enabled=false
```

---

## Unit Tests

Unit tests are located in `backend/tests/` using **pytest** with the FastAPI `TestClient`.

### Running Tests

```bash
cd backend
pip install pytest httpx
pytest tests/ -v
```

### Test Coverage

| Test Class | Tests | Description |
|------------|-------|-------------|
| `TestListBooks` | 3 | Empty list, single book, multiple books |
| `TestGetBook` | 2 | Get by ID, 404 for non-existent |
| `TestCreateBook` | 7 | Full creation, minimal fields, validation errors, persistence |
| `TestUpdateBook` | 4 | Partial update, multi-field, 404, empty body |
| `TestDeleteBook` | 3 | Successful delete, 404, removal from list |
| `TestHealthCheck` | 1 | Health endpoint returns healthy status |
| **Total** | **20** | |

Each test runs with an isolated store (cleared before and after via `autouse` fixture).

---

## Logging

The backend uses structured JSON logging via Python's `logging` module, configured in `backend/app/logging_config.py`.

### Log Format

```json
{
  "timestamp": "2026-07-06T12:00:00+0000",
  "level": "INFO",
  "logger": "astronova.http",
  "message": "request_id=a1b2c3d4 method=GET path=/api/books status=200 duration_ms=1.23"
}
```

### Features

- **Request/Response middleware:** Logs every HTTP request with method, path, status code, and duration
- **Request ID:** Each request gets a unique ID (`X-Request-ID` header) for tracing
- **JSON format:** Compatible with log aggregation tools (Fluentd, Loki, CloudWatch)
- **stdout output:** Works with `kubectl logs` and container log drivers

### Viewing Logs

```bash
# Via kubectl
kubectl logs -l app.kubernetes.io/name=astronova-backend -f

# Structured log parsing with jq
kubectl logs -l app.kubernetes.io/name=astronova-backend | jq .
```

### Log Rotation

Log rotation is handled at two levels:

**1. Application-level (RotatingFileHandler)** — configured in `logging_config.py`:

| Setting | Default | Env Variable | Description |
|---------|---------|-------------|-------------|
| Log directory | `/var/log/astronova` | `LOG_DIR` | Where log files are written |
| Max file size | 10 MB | `LOG_MAX_BYTES` | Size before rotation triggers |
| Backup count | 5 | `LOG_BACKUP_COUNT` | Number of rotated files to keep |
| Total max disk | ~60 MB | — | `10MB × (5+1)` files |

Files produced: `app.log` → `app.log.1` → `app.log.2` → ... → `app.log.5`

To customize via Helm environment variables, add to the backend deployment:
```yaml
env:
  - name: LOG_DIR
    value: "/var/log/astronova"
  - name: LOG_MAX_BYTES
    value: "20971520"      # 20 MB
  - name: LOG_BACKUP_COUNT
    value: "10"
```

**2. Container-level (kubelet)** — configure on each node:

```bash
# /var/lib/kubelet/config.yaml
containerLogMaxSize: "50Mi"
containerLogMaxFiles: 5
```

> **Note:** The application gracefully falls back to stdout-only logging if the log directory is not writable (e.g., no volume mount). In Kubernetes, stdout logs are captured by the container runtime and managed by kubelet's rotation policy.

---

## Cleanup Instructions

### Remove Application

```bash
ssh -i ~/.ssh/astronova ubuntu@<CONTROL_PLANE_IP>
helm uninstall astronova
```

### Remove Ingress and cert-manager

```bash
helm uninstall ingress-nginx -n ingress-nginx
helm uninstall cert-manager -n cert-manager
```

### Destroy AWS Infrastructure

```bash
cd terraform
terraform destroy -auto-approve
```

This removes all 3 EC2 instances, security groups, the Network Load Balancer, and the Elastic IP. No AWS resources will remain.

### Stop Instances (Pause Billing)

To temporarily stop billing without losing cluster state:

```bash
aws ec2 stop-instances --instance-ids $(aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=astronova" "Name=instance-state-name,Values=running" \
  --query "Reservations[*].Instances[*].InstanceId" --output text)
```

---

## Docker Images

| Image | Registry |
|-------|----------|
| Backend | [manojcs197/astronova_backend](https://hub.docker.com/r/manojcs197/astronova_backend) |
| Frontend | [manojcs197/astronova_frontend](https://hub.docker.com/r/manojcs197/astronova_frontend) |

---

## Cost Estimate

| Resource | Monthly Cost |
|----------|-------------|
| 3× t3.medium EC2 | ~$100/mo (or ~$3.34/day) |
| Network Load Balancer | ~$18/mo |
| Elastic IP (in use) | Free |
| EBS (3× 30GB gp3) | ~$7.20/mo |
| **Total** | **~$125/mo** (~$4.17/day) |

Stop instances when not in use to minimize costs.

