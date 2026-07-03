#!/usr/bin/env bash
set -euo pipefail

DOCKERHUB_USERNAME="${DOCKERHUB_USERNAME:-manojcs197}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
BACKEND_IMAGE="${DOCKERHUB_USERNAME}/astronova_backend:${IMAGE_TAG}"
FRONTEND_IMAGE="${DOCKERHUB_USERNAME}/astronova_frontend:${IMAGE_TAG}"
APP_DOMAIN="${APP_DOMAIN:-astronova.example.com}"
SSH_KEY_PATH="${SSH_KEY_PATH:-~/.ssh/astronova.pem}"
LETSENCRYPT_EMAIL="${LETSENCRYPT_EMAIL:-admin@example.com}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BACKEND_DIR="${PROJECT_ROOT}/backend"
FRONTEND_DIR="${PROJECT_ROOT}/frontend"
TERRAFORM_DIR="${PROJECT_ROOT}/terraform"
HELM_DIR="${PROJECT_ROOT}/helm/astronova"
K8S_DIR="${PROJECT_ROOT}/k8s"

SKIP_BUILD=false
SKIP_INFRA=false
SKIP_K8S_SETUP=false

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log()    { echo -e "${GREEN}[INFO]${NC}    $1"; }
warn()   { echo -e "${YELLOW}[WARN]${NC}    $1"; }
error()  { echo -e "${RED}[ERROR]${NC}   $1"; exit 1; }
header() { echo -e "\n${CYAN}${BOLD}═══════════════════════════════════════════════════${NC}"; echo -e "${CYAN}${BOLD}  $1${NC}"; echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════${NC}\n"; }
step()   { echo -e "\n${BOLD}→ $1${NC}"; }

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-build)    SKIP_BUILD=true ;;
            --skip-infra)    SKIP_INFRA=true ;;
            --skip-k8s-setup) SKIP_K8S_SETUP=true ;;
            --help|-h)
                echo "Usage: $0 [--skip-build] [--skip-infra] [--skip-k8s-setup]"
                exit 0
                ;;
            *) error "Unknown option: $1. Use --help for usage." ;;
        esac
        shift
    done
}

check_prerequisites() {
    header "Checking Prerequisites"

    local missing=()
    for cmd in docker terraform helm kubectl aws jq; do
        if command -v "$cmd" &>/dev/null; then
            log "$(printf '%-12s' "$cmd") ✓"
        else
            missing+=("$cmd")
            echo -e "  ${RED}$(printf '%-12s' "$cmd") ✗${NC}"
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        error "Missing tools: ${missing[*]}. Please install them first."
    fi

    log "All prerequisites met."
}

build_images() {
    if $SKIP_BUILD; then
        warn "Skipping Docker build (--skip-build)"
        return
    fi

    header "Step 1: Building Docker Images"

    step "Building backend image: ${BACKEND_IMAGE}"
    docker build -t "${BACKEND_IMAGE}" "${BACKEND_DIR}"
    log "Backend image built successfully."

    step "Building frontend image: ${FRONTEND_IMAGE}"
    docker build \
        --build-arg VITE_API_URL="" \
        -t "${FRONTEND_IMAGE}" \
        "${FRONTEND_DIR}"
    log "Frontend image built successfully."
}

push_images() {
    if $SKIP_BUILD; then
        warn "Skipping Docker push (--skip-build)"
        return
    fi

    header "Step 2: Pushing Images to Docker Hub"

    log "Logging into Docker Hub..."
    docker login

    step "Pushing backend image..."
    docker push "${BACKEND_IMAGE}"
    log "Backend image pushed."

    step "Pushing frontend image..."
    docker push "${FRONTEND_IMAGE}"
    log "Frontend image pushed."
}

provision_infra() {
    if $SKIP_INFRA; then
        warn "Skipping Terraform provisioning (--skip-infra)"
        return
    fi

    header "Step 3: Provisioning AWS Infrastructure with Terraform"

    step "Initializing Terraform..."
    terraform -chdir="${TERRAFORM_DIR}" init

    step "Planning infrastructure..."
    terraform -chdir="${TERRAFORM_DIR}" plan -out=tfplan

    step "Applying infrastructure..."
    terraform -chdir="${TERRAFORM_DIR}" apply tfplan

    log "Infrastructure provisioned."
}

wait_for_instances() {
    if $SKIP_INFRA; then
        warn "Skipping instance wait (--skip-infra)"
        return
    fi

    header "Step 4: Waiting for EC2 Instances"

    local cp_ip
    cp_ip=$(terraform -chdir="${TERRAFORM_DIR}" output -raw control_plane_public_ip)
    local w1_ip
    w1_ip=$(terraform -chdir="${TERRAFORM_DIR}" output -raw worker_1_public_ip)
    local w2_ip
    w2_ip=$(terraform -chdir="${TERRAFORM_DIR}" output -raw worker_2_public_ip)

    log "Control Plane: ${cp_ip}"
    log "Worker 1:      ${w1_ip}"
    log "Worker 2:      ${w2_ip}"

    step "Waiting for SSH access on all nodes..."
    for ip in "$cp_ip" "$w1_ip" "$w2_ip"; do
        local retries=30
        while ! ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -i "${SSH_KEY_PATH}" "ubuntu@${ip}" "echo ready" &>/dev/null; do
            retries=$((retries - 1))
            if [[ $retries -le 0 ]]; then
                error "Timeout waiting for ${ip} to become accessible"
            fi
            echo -n "."
            sleep 10
        done
        log "  ${ip} — SSH accessible ✓"
    done
}

k8s_setup_instructions() {
    if $SKIP_K8S_SETUP; then
        warn "Skipping K8s setup instructions (--skip-k8s-setup)"
        return
    fi

    header "Step 5: Kubernetes Cluster Setup"

    local cp_ip
    cp_ip=$(terraform -chdir="${TERRAFORM_DIR}" output -raw control_plane_public_ip 2>/dev/null || echo "<CONTROL_PLANE_IP>")
    local w1_ip
    w1_ip=$(terraform -chdir="${TERRAFORM_DIR}" output -raw worker_1_public_ip 2>/dev/null || echo "<WORKER_1_IP>")
    local w2_ip
    w2_ip=$(terraform -chdir="${TERRAFORM_DIR}" output -raw worker_2_public_ip 2>/dev/null || echo "<WORKER_2_IP>")

    echo -e "${BOLD}Follow these steps to set up the Kubernetes cluster:${NC}"
    echo ""
    echo -e "${CYAN}1. Copy the setup script to all nodes:${NC}"
    echo "   scp -i ${SSH_KEY_PATH} scripts/k8s-setup.sh ubuntu@${cp_ip}:~/"
    echo "   scp -i ${SSH_KEY_PATH} scripts/k8s-setup.sh ubuntu@${w1_ip}:~/"
    echo "   scp -i ${SSH_KEY_PATH} scripts/k8s-setup.sh ubuntu@${w2_ip}:~/"
    echo ""
    echo -e "${CYAN}2. On the control plane node (${cp_ip}):${NC}"
    echo "   ssh -i ${SSH_KEY_PATH} ubuntu@${cp_ip}"
    echo "   sudo chmod +x k8s-setup.sh && sudo ./k8s-setup.sh init"
    echo ""
    echo -e "${CYAN}3. Copy the join command from the output, then on each worker:${NC}"
    echo "   ssh -i ${SSH_KEY_PATH} ubuntu@${w1_ip}"
    echo "   sudo chmod +x k8s-setup.sh && sudo ./k8s-setup.sh install"
    echo "   sudo kubeadm join <control-plane-ip>:6443 --token <token> --discovery-token-ca-cert-hash <hash>"
    echo ""
    echo -e "${CYAN}4. Copy kubeconfig to your local machine:${NC}"
    echo "   scp -i ${SSH_KEY_PATH} ubuntu@${cp_ip}:~/.kube/config ~/.kube/config"
    echo ""

    read -rp "Press Enter when the Kubernetes cluster is ready..."

    log "Verifying cluster..."
    kubectl get nodes || warn "Could not reach cluster — ensure kubeconfig is set."
}

install_ingress_and_certs() {
    header "Step 6: Installing NGINX Ingress & cert-manager"

    sed -i "s/your-email@example.com/${LETSENCRYPT_EMAIL}/" "${K8S_DIR}/cluster-issuer.yaml"

    bash "${K8S_DIR}/ingress-setup.sh"

    log "Ingress and cert-manager are ready."
}

deploy_application() {
    header "Step 7: Deploying AstroNova Application"

    step "Installing/Upgrading Helm chart..."
    helm upgrade --install astronova "${HELM_DIR}" \
        --set backend.image.repository="${DOCKERHUB_USERNAME}/astronova-backend" \
        --set backend.image.tag="${IMAGE_TAG}" \
        --set frontend.image.repository="${DOCKERHUB_USERNAME}/astronova-frontend" \
        --set frontend.image.tag="${IMAGE_TAG}" \
        --set ingress.host="${APP_DOMAIN}" \
        --set ingress.tls.secretName="astronova-tls" \
        --wait \
        --timeout 5m

    log "Application deployed."

    step "Waiting for pods to be ready..."
    kubectl wait --for=condition=Ready pods -l app.kubernetes.io/name=astronova-backend --timeout=120s
    kubectl wait --for=condition=Ready pods -l app.kubernetes.io/name=astronova-frontend --timeout=120s

    log "All pods are ready."
}

output_summary() {
    header "Deployment Complete!"

    echo -e "${GREEN}${BOLD}Application URLs:${NC}"
    echo -e "  Frontend:  ${CYAN}https://${APP_DOMAIN}${NC}"
    echo -e "  Backend:   ${CYAN}https://${APP_DOMAIN}/api/books${NC}"
    echo -e "  API Docs:  ${CYAN}https://${APP_DOMAIN}/docs${NC}"
    echo -e "  Health:    ${CYAN}https://${APP_DOMAIN}/health${NC}"
    echo ""

    echo -e "${GREEN}${BOLD}Docker Images:${NC}"
    echo -e "  Backend:   ${CYAN}${BACKEND_IMAGE}${NC}"
    echo -e "  Frontend:  ${CYAN}${FRONTEND_IMAGE}${NC}"
    echo ""

    echo -e "${GREEN}${BOLD}Useful Commands:${NC}"
    echo "  kubectl get pods"
    echo "  kubectl get svc"
    echo "  kubectl get ingress"
    echo "  kubectl logs -l app.kubernetes.io/name=astronova-backend"
    echo "  kubectl logs -l app.kubernetes.io/name=astronova-frontend"
    echo "  helm status astronova"
    echo ""

    log "Deployment complete. Your app is live at https://${APP_DOMAIN}"
}

main() {
    parse_args "$@"

    header "AstroNova — Full-Stack Deployment Pipeline"
    log "Docker Hub User: ${DOCKERHUB_USERNAME}"
    log "Image Tag:       ${IMAGE_TAG}"
    log "Domain:          ${APP_DOMAIN}"
    echo ""

    check_prerequisites
    build_images
    push_images
    provision_infra
    wait_for_instances
    k8s_setup_instructions
    install_ingress_and_certs
    deploy_application
    output_summary
}

main "$@"
