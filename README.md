# AstroNova — Full-Stack Book Management System

A production-grade full-stack application with complete DevOps pipeline: **Python/FastAPI** backend, **Vue.js** frontend, containerized with **Docker**, deployed on **Kubernetes** (kubeadm) provisioned via **Terraform** on AWS.

---

## Project Structure

```
assignment_1/
├── backend/                    # Python/FastAPI REST API
│   ├── app/
│   │   ├── main.py             # FastAPI application entry point
│   │   ├── models.py           # Pydantic schemas (BookCreate, BookUpdate, BookResponse)
│   │   ├── store.py            # In-memory data store with seed data
│   │   └── routes/
│   │       ├── books.py        # CRUD endpoints: GET, POST, PATCH, DELETE
│   │       └── health.py       # Health check endpoint
│   ├── requirements.txt
│   ├── Dockerfile              # Multi-stage: python-slim builder → production
│   └── .dockerignore
│
├── frontend/                   # Vue.js 3 + Vite SPA
│   ├── src/
│   │   ├── main.js             # Vue app entry
│   │   ├── App.vue             # Root component with CRUD orchestration
│   │   ├── assets/main.css     # Global design system (dark theme, glassmorphism)
│   │   ├── components/
│   │   │   ├── BookCard.vue    # Book display card with edit/delete actions
│   │   │   └── BookForm.vue    # Create/Edit form with validation
│   │   └── services/
│   │       └── api.js          # Axios API service layer
│   ├── nginx.conf              # Nginx config with SPA fallback + API proxy
│   ├── Dockerfile              # Multi-stage: node builder → nginx-alpine
│   └── .dockerignore
│
├── terraform/                  # AWS Infrastructure as Code
│   ├── main.tf                 # VPC, Security Groups, 3x EC2 instances
│   ├── variables.tf            # Configurable variables
│   ├── outputs.tf              # IPs, SSH commands, SG IDs
│   └── terraform.tfvars.example
│
├── scripts/
│   ├── k8s-setup.sh            # kubeadm cluster setup (Ubuntu 22.04)
│   └── deploy.sh               # Master automation script (all 8 stages)
│
├── helm/astronova/             # Helm chart for application deployment
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/
│       ├── _helpers.tpl
│       ├── configmap.yaml
│       ├── backend-deployment.yaml
│       ├── backend-service.yaml
│       ├── frontend-deployment.yaml
│       ├── frontend-service.yaml
│       └── ingress.yaml
│
├── k8s/                        # Standalone Kubernetes manifests
│   ├── cluster-issuer.yaml     # Let's Encrypt ClusterIssuer
│   ├── ingress.yaml            # Standalone Ingress resource
│   └── ingress-setup.sh        # NGINX Ingress + cert-manager installer
│
└── README.md
```

---

## 1. Backend (Python/FastAPI)

### API Endpoints

| Method | Endpoint | Description | Status Codes |
|--------|----------|-------------|-------------|
| `GET` | `/health` | Health check | `200` |
| `GET` | `/api/books` | List all books | `200` |
| `GET` | `/api/books/{id}` | Get a single book | `200`, `404` |
| `POST` | `/api/books` | Create a new book | `201`, `422` |
| `PATCH` | `/api/books/{id}` | Partially update a book | `200`, `400`, `404` |
| `DELETE` | `/api/books/{id}` | Delete a book | `204`, `404` |

### Book Schema

```json
{
  "id": "auto-generated UUID",
  "title": "required, 1-300 chars",
  "author": "required, 1-200 chars",
  "isbn": "optional, max 20 chars",
  "publishedYear": "optional, 1000-2100"
}
```

### Run Locally

```bash
cd backend
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```

API docs available at: `http://localhost:8000/docs`

---

## 2. Frontend (Vue.js)

### Features
- List, create, update, and delete books
- Dark theme with glassmorphism design
- Toast notifications for all actions
- Modal dialogs for forms and confirmations
- Responsive grid layout
- Animated transitions

### Run Locally

```bash
cd frontend
npm install
npm run dev
```

The dev server proxies `/api/*` to `http://localhost:8000` automatically.

---

## 3. Docker

### Build Images

```bash
# Backend
docker build -t astronova-backend ./backend

# Frontend
docker build -t astronova-frontend ./frontend
```

### Run with Docker

```bash
# Backend
docker run -d -p 8000:8000 --name backend astronova-backend

# Frontend (connects to backend container)
docker run -d -p 80:80 --name frontend --link backend astronova-frontend
```

---

## 4. Terraform (AWS Infrastructure)

### Setup

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

terraform init
terraform plan
terraform apply
```

### What It Creates
- **3 EC2 instances** (Ubuntu 22.04): `control-plane`, `worker-1`, `worker-2`
- **3 Security Groups**: SSH, HTTP/HTTPS + NodePort, Kubernetes inter-node
- All in the **default VPC** with public IPs

---

## 5. Kubernetes Setup

```bash
# On ALL nodes:
sudo ./scripts/k8s-setup.sh install

# On the control plane:
sudo ./scripts/k8s-setup.sh init

# On workers (use the join command from init output):
sudo kubeadm join <control-plane-ip>:6443 --token <token> --discovery-token-ca-cert-hash <hash>
```

---

## 6. Helm Deployment

```bash
helm upgrade --install astronova ./helm/astronova \
  --set backend.image.repository=yourusername/astronova-backend \
  --set frontend.image.repository=yourusername/astronova-frontend \
  --set ingress.host=astronova.example.com
```

---

## 7. Ingress & SSL

```bash
# Install NGINX Ingress + cert-manager + ClusterIssuer
bash k8s/ingress-setup.sh

# Or apply standalone manifests
kubectl apply -f k8s/cluster-issuer.yaml
kubectl apply -f k8s/ingress.yaml
```

---

## 8. Master Automation

```bash
# Full deployment pipeline
export DOCKERHUB_USERNAME=yourusername
export APP_DOMAIN=astronova.example.com
export SSH_KEY_PATH=~/.ssh/your-key.pem
export LETSENCRYPT_EMAIL=you@example.com

./scripts/deploy.sh
```

### Flags
- `--skip-build` — Skip Docker build & push
- `--skip-infra` — Skip Terraform provisioning
- `--skip-k8s-setup` — Skip kubeadm setup instructions

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Backend | Python 3.12, FastAPI, Pydantic, Uvicorn |
| Frontend | Vue.js 3, Vite, Axios |
| Containers | Docker (multi-stage), Nginx |
| IaC | Terraform, AWS (EC2, VPC, Security Groups) |
| Orchestration | Kubernetes (kubeadm), Flannel CNI |
| Packaging | Helm 3 |
| Ingress | NGINX Ingress Controller |
| TLS | cert-manager, Let's Encrypt |

---

## License

MIT
