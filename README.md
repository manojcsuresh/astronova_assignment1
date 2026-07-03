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
├── backend/                    # FastAPI REST API
│   ├── Dockerfile
│   ├── requirements.txt
│   └── app/
│       ├── main.py             # FastAPI app entry point
│       ├── models.py           # Pydantic schemas
│       ├── store.py            # In-memory data store
│       └── routes/
│           ├── books.py        # CRUD endpoints
│           └── health.py       # Health check endpoint
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
│       └── ingress.yaml
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
