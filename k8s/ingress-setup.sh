#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
# AstroNova — NGINX Ingress & cert-manager Installation Script
#
# Installs:
#   1. NGINX Ingress Controller (via Helm)
#   2. cert-manager (via Helm)
#   3. Let's Encrypt ClusterIssuer
# ════════════════════════════════════════════════════════════════

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

log()   { echo -e "${GREEN}[INFO]${NC}  $1"; }
header(){ echo -e "\n${CYAN}══════════════════════════════════════════${NC}"; echo -e "${CYAN}  $1${NC}"; echo -e "${CYAN}══════════════════════════════════════════${NC}\n"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ─── Check Prerequisites ────────────────────────────────────
check_prereqs() {
    for cmd in helm kubectl; do
        if ! command -v "$cmd" &>/dev/null; then
            echo -e "${RED}[ERROR]${NC} '$cmd' is not installed. Please install it first."
            exit 1
        fi
    done
}

# ─── Install NGINX Ingress Controller ───────────────────────
install_nginx_ingress() {
    header "Installing NGINX Ingress Controller"

    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx 2>/dev/null || true
    helm repo update

    helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
        --namespace ingress-nginx \
        --create-namespace \
        --set controller.replicaCount=2 \
        --set controller.service.type=NodePort \
        --set controller.service.nodePorts.http=30080 \
        --set controller.service.nodePorts.https=30443 \
        --wait \
        --timeout 5m

    log "NGINX Ingress Controller installed."
    log "HTTP:  NodePort 30080"
    log "HTTPS: NodePort 30443"
}

# ─── Install cert-manager ───────────────────────────────────
install_cert_manager() {
    header "Installing cert-manager"

    helm repo add jetstack https://charts.jetstack.io 2>/dev/null || true
    helm repo update

    helm upgrade --install cert-manager jetstack/cert-manager \
        --namespace cert-manager \
        --create-namespace \
        --set crds.enabled=true \
        --wait \
        --timeout 5m

    log "cert-manager installed."

    # Wait for cert-manager webhook to be ready
    log "Waiting for cert-manager webhook to be ready..."
    kubectl wait --for=condition=Available deployment/cert-manager-webhook \
        -n cert-manager --timeout=120s
}

# ─── Apply ClusterIssuer ────────────────────────────────────
apply_cluster_issuer() {
    header "Applying Let's Encrypt ClusterIssuer"

    kubectl apply -f "${SCRIPT_DIR}/cluster-issuer.yaml"

    log "ClusterIssuer 'letsencrypt-prod' applied."
}

# ─── Main ────────────────────────────────────────────────────
main() {
    check_prereqs
    install_nginx_ingress
    install_cert_manager
    apply_cluster_issuer

    header "Installation Complete!"
    log "NGINX Ingress Controller: Running"
    log "cert-manager: Running"
    log "ClusterIssuer: letsencrypt-prod (Let's Encrypt production)"
    echo ""
    log "Next: Deploy your application with the Helm chart:"
    log "  helm upgrade --install astronova ./helm/astronova"
}

main "$@"
