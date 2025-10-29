#!/bin/bash
set -e

INTERFACE="eth0"
IP_FIXO="192.168.1.112/24"
GATEWAY="192.168.1.1"
DNS_PRIMARIO="8.8.8.8"
DNS_SECUNDARIO="1.1.1.1"
NETPLAN_FILE="/etc/netplan/01-netcfg.yaml"
KUBECONFIG="$USER_HOME/.kube/config"
USER_HOME="/home/k8s"

rm -rf /etc/netplan/50-cloud-init.yaml

# Cria o conteudo do arquivo de configuracao
CONFIG_CONTENT="
network:
  version: 2
  renderer: networkd
  ethernets:
    $INTERFACE:
      dhcp4: no
      addresses:
        - $IP_FIXO
      routes:
        - to: default
          via: $GATEWAY
      nameservers:
          addresses: [$DNS_PRIMARIO, $DNS_SECUNDARIO]
"
echo "$CONFIG_CONTENT" | sudo tee "$NETPLAN_FILE" > /dev/null
sudo chmod 600 "$NETPLAN_FILE"
sudo echo "network: {config: disabled}" >> /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg
#sudo netplan apply

useradd -m -s /bin/bash k8s
echo 'k8s:k8s' | chpasswd
usermod -aG sudo k8s
echo 'k8s ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/k8s
apt-get update
apt-get install -y openssh-server bash-completion

echo "[1/8] Atualizando pacotes..."
sudo apt-get update && sudo apt-get upgrade -y

echo "[2/8] Instalando dependências..."
sudo apt install -y apt-transport-https ca-certificates curl gnupg lsb-release software-properties-common ssh net-tools

echo "Carregando módulos necessários..."
modprobe overlay
modprobe br_netfilter

cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
net.ipv4.ip_forward = 1
br_netfilter
EOF

echo "Configurando sysctl para Kubernetes..."
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl --system

echo "[5/9] Desativando swap..."
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

echo "[3/9] Instalando container runtime containerd..."
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor | sudo tee /etc/apt/keyrings/docker.gpg > /dev/null
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-focal}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y containerd.io

echo "[3/9] Instalndo CNI plugins..."
sudo wget -P /home/k8s/ https://github.com/containernetworking/plugins/releases/download/v1.7.1/cni-plugins-linux-amd64-v1.7.1.tgz
sudo mkdir -p /opt/cni/bin
cd /home/k8s && sudo tar -xzvf cni-plugins-linux-amd64-v1.7.1.tgz -C /opt/cni/bin

echo "[5/9] Configurando containerd..."
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
sudo sed -i '/^\s*disabled_plugins\s*=.*/s/^/# /' /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd

echo "[5/8] Configurando o maquina ..."
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.33/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
sudo chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.33/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo chmod 644 /etc/apt/sources.list.d/kubernetes.list

echo "[7/8] Instalando o Kubernetes..."
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
sudo systemctl enable --now kubelet