#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
# AstroNova — Kubernetes Cluster Setup Script
# Sets up a kubeadm-based K8s cluster on Ubuntu 22.04
#
# Usage:
#   Control Plane:  sudo ./k8s-setup.sh init
#   Worker Node:    sudo ./k8s-setup.sh join <join-command>
#   All Nodes:      sudo ./k8s-setup.sh install  (installs prereqs only)
# ════════════════════════════════════════════════════════════════

set -euo pipefail

# ─── Configuration ────────────────────────────────────────────
KUBE_VERSION="1.30"
POD_CIDR="10.244.0.0/16"
CONTAINERD_VERSION="1.7.18"

# ─── Colors ───────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log()   { echo -e "${GREEN}[INFO]${NC}  $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
header(){ echo -e "\n${CYAN}══════════════════════════════════════════${NC}"; echo -e "${CYAN}  $1${NC}"; echo -e "${CYAN}══════════════════════════════════════════${NC}\n"; }

# ─── Pre-checks ──────────────────────────────────────────────
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root (use sudo)"
    fi
}

check_ubuntu() {
    if ! grep -qi "ubuntu" /etc/os-release 2>/dev/null; then
        error "This script is designed for Ubuntu 22.04"
    fi
}

# ─── Step 1: System Preparation ──────────────────────────────
prepare_system() {
    header "Preparing System"

    log "Disabling swap..."
    swapoff -a
    sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

    log "Loading required kernel modules..."
    cat > /etc/modules-load.d/k8s.conf <<EOF
overlay
br_netfilter
EOF
    modprobe overlay
    modprobe br_netfilter

    log "Setting sysctl parameters..."
    cat > /etc/sysctl.d/k8s.conf <<EOF
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
    sysctl --system > /dev/null 2>&1

    log "Updating system packages..."
    apt-get update -qq
    apt-get install -y -qq apt-transport-https ca-certificates curl gnupg lsb-release > /dev/null

    log "System preparation complete."
}

# ─── Step 2: Install containerd ──────────────────────────────
install_containerd() {
    header "Installing containerd"

    if command -v containerd &>/dev/null; then
        warn "containerd is already installed, skipping..."
        return
    fi

    log "Adding Docker repository for containerd..."
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list

    apt-get update -qq
    apt-get install -y -qq containerd.io > /dev/null

    log "Configuring containerd with SystemdCgroup..."
    mkdir -p /etc/containerd
    containerd config default > /etc/containerd/config.toml
    sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

    systemctl restart containerd
    systemctl enable containerd

    log "containerd installed and configured."
}

# ─── Step 3: Install kubeadm, kubelet, kubectl ──────────────
install_kube_tools() {
    header "Installing kubeadm, kubelet, kubectl (v${KUBE_VERSION})"

    if command -v kubeadm &>/dev/null; then
        warn "kubeadm is already installed, skipping..."
        return
    fi

    log "Adding Kubernetes repository..."
    mkdir -p /etc/apt/keyrings
    curl -fsSL "https://pkgs.k8s.io/core:/stable:/v${KUBE_VERSION}/deb/Release.key" | \
        gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

    echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${KUBE_VERSION}/deb/ /" > \
        /etc/apt/sources.list.d/kubernetes.list

    apt-get update -qq
    apt-get install -y -qq kubelet kubeadm kubectl > /dev/null

    # Prevent automatic updates
    apt-mark hold kubelet kubeadm kubectl

    systemctl enable kubelet

    log "kubeadm, kubelet, kubectl installed and held."
}

# ─── Step 4: Initialize Control Plane ────────────────────────
init_control_plane() {
    header "Initializing Kubernetes Control Plane"

    log "Running kubeadm init..."
    kubeadm init \
        --pod-network-cidr="${POD_CIDR}" \
        --cri-socket=unix:///var/run/containerd/containerd.sock \
        | tee /root/kubeadm-init.log

    # Setup kubectl for root
    log "Configuring kubectl for root..."
    mkdir -p /root/.kube
    cp -f /etc/kubernetes/admin.conf /root/.kube/config
    chown root:root /root/.kube/config

    # Setup kubectl for the ubuntu user (if exists)
    if id "ubuntu" &>/dev/null; then
        log "Configuring kubectl for ubuntu user..."
        UBUNTU_HOME=$(eval echo ~ubuntu)
        mkdir -p "${UBUNTU_HOME}/.kube"
        cp -f /etc/kubernetes/admin.conf "${UBUNTU_HOME}/.kube/config"
        chown -R ubuntu:ubuntu "${UBUNTU_HOME}/.kube"
    fi

    # Install Flannel CNI
    log "Installing Flannel CNI plugin..."
    export KUBECONFIG=/etc/kubernetes/admin.conf
    kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

    # Display the join command
    echo ""
    header "Cluster Initialized Successfully!"
    log "Save the following join command for your worker nodes:"
    echo ""
    echo -e "${YELLOW}$(kubeadm token create --print-join-command)${NC}"
    echo ""
    log "Kubeadm init log saved to: /root/kubeadm-init.log"
}

# ─── Main ────────────────────────────────────────────────────
main() {
    check_root
    check_ubuntu

    local action="${1:-install}"

    case "$action" in
        install)
            header "AstroNova K8s Setup — Installing Prerequisites"
            prepare_system
            install_containerd
            install_kube_tools
            echo ""
            log "Prerequisites installed. Next steps:"
            log "  Control plane: sudo ./k8s-setup.sh init"
            log "  Worker node:   sudo kubeadm join <control-plane-ip>:6443 --token <token> --discovery-token-ca-cert-hash <hash>"
            ;;
        init)
            header "AstroNova K8s Setup — Full Control Plane Init"
            prepare_system
            install_containerd
            install_kube_tools
            init_control_plane
            ;;
        join)
            if [[ -z "${2:-}" ]]; then
                error "Usage: $0 join <full-join-command-args>"
            fi
            prepare_system
            install_containerd
            install_kube_tools
            header "Joining Kubernetes Cluster"
            shift
            kubeadm join "$@"
            ;;
        *)
            echo "Usage: $0 {install|init|join <args>}"
            echo ""
            echo "  install  — Install containerd, kubeadm, kubelet, kubectl only"
            echo "  init     — Install all + initialize control plane"
            echo "  join     — Install all + join an existing cluster"
            exit 1
            ;;
    esac
}

main "$@"
