#!/bin/bash
set -e

# [CONFIGURAÇÕES] 
INTERFACE="eth0"
IP_FIXO="192.168.56.110/24" # ⚠️ Confirme que este IP está na sua rede Host-Only
GATEWAY="192.168.56.1"
DNS_PRIMARIO="8.8.8.8"
DNS_SECUNDARIO="1.1.1.1"
NETPLAN_FILE="/etc/netplan/01-netcfg.yaml"
USER_HOME="/home/k8s"

# # --- CONFIGURAÇÃO DE REDE COM NETPLAN ---
# echo "[1/9] Configurando Netplan com IP Fixo..."
# rm -rf /etc/netplan/50-cloud-init.yaml

# CONFIG_CONTENT="
# network:
#   version: 2
#   renderer: networkd
#   ethernets:
#     $INTERFACE:
#       dhcp4: no
#       addresses:
#         - $IP_FIXO
#       routes:
#         - to: default
#           via: $GATEWAY
#       nameservers:
#           addresses: [$DNS_PRIMARIO, $DNS_SECUNDARIO]
# "
# echo "$CONFIG_CONTENT" | sudo tee "$NETPLAN_FILE" > /dev/null
# sudo chmod 600 "$NETPLAN_FILE"
# sudo echo "network: {config: disabled}" | sudo tee /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg > /dev/null
#sudo netplan apply # Aplica a rede imediatamente

# --- CONFIGURAÇÃO DE USUÁRIO E DEPENDÊNCIAS BÁSICAS ---
echo "[2/9] Configurando usuário 'k8s' e instalando dependências básicas..."
# Verifica se o usuário já existe para não quebrar a execução
if ! id "k8s" &>/dev/null; then
    sudo useradd -m -s /bin/bash k8s
    echo 'k8s:k8s' | sudo chpasswd
    sudo usermod -aG sudo k8s
    echo 'k8s ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/k8s > /dev/null
fi

sudo apt update
sudo apt install -y openssh-server bash-completion apt-transport-https ca-certificates curl gnupg lsb-release software-properties-common ssh net-tools

# --- CONFIGURAÇÃO DE KERNEL (CRÍTICO PARA REDE) ---
echo "[3/9] Carregando e persistindo módulos de kernel..."
sudo modprobe overlay
sudo modprobe br_netfilter

# Arquivo para carregar módulos ao iniciar
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

echo "[4/9] Configurando sysctl para Kubernetes (iptables e IP Forward)..."
# Arquivo para configurar sysctl
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

# Aplica as configurações do sysctl
sudo sysctl --system 

# --- DESATIVAÇÃO DE SWAP ---
echo "[5/9] Desativando swap..."
sudo sed -i 's/^/#/' /etc/fstab
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
sudo swapoff -a

# --- INSTALAÇÃO DO CONTAINERD E KUBERNETES ---
echo "[6/9] Instalando container runtime containerd..."
# ... (Seus comandos de instalação do containerd, Docker GPG e apt repo estão aqui e parecem corretos) ...
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor | sudo tee /etc/apt/keyrings/docker.gpg > /dev/null
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-focal}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y containerd.io

echo "[7/9] Configurando containerd (cgroupfs systemd)..."
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
# Garante que systemd seja usado para cgroup
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd

echo "[8/9] Instalando o Kubernetes (kubelet, kubeadm, kubectl)..."
# ... (Seus comandos de instalação do Kubernetes GPG e apt repo estão aqui e parecem corretos) ...
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.33/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
sudo chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.33/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo chmod 644 /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
sudo systemctl enable --now kubelet

echo "✅ Script de Pre-Configuração Concluído. Prossiga com 'kubeadm init' manualmente."