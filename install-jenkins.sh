#!/bin/bash
set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

echo -e "${GREEN}=== Mise à jour du système ===${NC}"
apt update && apt upgrade -y

echo -e "${GREEN}=== Installation des dépendances ===${NC}"
apt install -y curl wget gnupg jq unzip openssh-client python3-pip python3-venv pipx

# Initialiser pipx
pipx ensurepath
source ~/.bashrc 2>/dev/null || true

# ---------------------- JENKINS ----------------------
echo -e "${GREEN}=== Installation de Jenkins ===${NC}"
rm -f /etc/apt/sources.list.d/jenkins.list /usr/share/keyrings/jenkins-keyring.* 2>/dev/null || true
mkdir -p /etc/apt/keyrings

# Importer la clé GPG de Jenkins
wget -q -O /etc/apt/keyrings/jenkins-keyring.asc https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key

# Ajouter le repository avec la clé correctement référencée
echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" | tee /etc/apt/sources.list.d/jenkins.list > /dev/null

apt update

# Installer Jenkins avec Java 21
apt install -y fontconfig openjdk-21-jdk jenkins

# Configurer Jenkins pour utiliser Java 21 explicitement
if [ -f /etc/default/jenkins ]; then
    sed -i 's|#JAVA_HOME=.*|JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64|' /etc/default/jenkins
fi

systemctl daemon-reload
systemctl enable --now jenkins
echo -e "${YELLOW}Jenkins installé. Mot de passe : /var/lib/jenkins/secrets/initialAdminPassword${NC}"

# ---------------------- K3S ----------------------
echo -e "${GREEN}=== Installation de k3s ===${NC}"

# Installation de k3s (mode serveur)
export K3S_KUBECONFIG_MODE="644"
curl -sfL https://get.k3s.io | sh -s - \
    --write-kubeconfig-mode 644 \
    --flannel-backend=wireguard-native \
    --disable=traefik \
    --disable=servicelb

# Attendre que k3s soit complètement prêt
echo -e "${YELLOW}Attente du démarrage de k3s...${NC}"
sleep 10

# Attendre que l'API server soit accessible
echo "Vérification de l'API Kubernetes..."
MAX_RETRIES=30
RETRY_COUNT=0
while ! kubectl get nodes &>/dev/null; do
    RETRY_COUNT=$((RETRY_COUNT+1))
    if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
        echo -e "${YELLOW}Erreur: k3s n'a pas démarré après $MAX_RETRIES tentatives${NC}"
        echo "Vérifiez les logs: journalctl -u k3s --no-pager -n 50"
        exit 1
    fi
    echo "En attente de l'API Kubernetes... ($RETRY_COUNT/$MAX_RETRIES)"
    sleep 5
done

# Attendre que le nœud soit Ready
echo "Attente que le nœud soit prêt..."
while [[ $(kubectl get nodes -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do
    RETRY_COUNT=$((RETRY_COUNT+1))
    if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
        echo -e "${YELLOW}Erreur: Le nœud n'est pas devenu Ready${NC}"
        exit 1
    fi
    echo "Nœud en cours d'initialisation... ($RETRY_COUNT/$MAX_RETRIES)"
    sleep 5
done

echo -e "${GREEN}k3s installé avec succès !${NC}"
kubectl get nodes -o wide

# Configurer kubectl pour l'utilisateur courant
mkdir -p $HOME/.kube
cp /etc/rancher/k3s/k3s.yaml $HOME/.kube/config
chmod 600 $HOME/.kube/config

# Ajouter la configuration pour l'utilisateur jenkins
mkdir -p /var/lib/jenkins/.kube
cp /etc/rancher/k3s/k3s.yaml /var/lib/jenkins/.kube/config
chown -R jenkins:jenkins /var/lib/jenkins/.kube
chmod 600 /var/lib/jenkins/.kube/config

# ---------------------- TERRAFORM ----------------------
echo -e "${GREEN}=== Installation de Terraform ===${NC}"
TERRAFORM_VERSION="1.7.5"
# Vérifier si l'architecture est ARM64
ARCH=$(uname -m)
if [ "$ARCH" = "aarch64" ]; then
    TERRAFORM_ARCH="arm64"
else
    TERRAFORM_ARCH="amd64"
fi

wget -q "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_${TERRAFORM_ARCH}.zip"
unzip -o "terraform_${TERRAFORM_VERSION}_linux_${TERRAFORM_ARCH}.zip"
mv terraform /usr/local/bin/
rm "terraform_${TERRAFORM_VERSION}_linux_${TERRAFORM_ARCH}.zip"

# ---------------------- ANSIBLE (via pipx) ----------------------
echo -e "${GREEN}=== Installation de Ansible ===${NC}"
# Installer ansible avec pipx
pipx install --system-site-packages ansible

# Créer des liens symboliques si nécessaire
if [ -f "$HOME/.local/bin/ansible" ]; then
    ln -sf "$HOME/.local/bin/ansible" /usr/local/bin/ansible
    ln -sf "$HOME/.local/bin/ansible-playbook" /usr/local/bin/ansible-playbook
    ln -sf "$HOME/.local/bin/ansible-galaxy" /usr/local/bin/ansible-galaxy
fi

# ---------------------- HELM ----------------------
echo -e "${GREEN}=== Installation de Helm ===${NC}"
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
rm get_helm.sh

# ---------------------- CLÉ SSH ----------------------
SSH_KEY_PATH="/var/lib/jenkins/.ssh/id_rsa_jenkins"
if [ ! -f "$SSH_KEY_PATH" ]; then
    echo -e "${GREEN}=== Génération clé SSH Jenkins ===${NC}"
    mkdir -p /var/lib/jenkins/.ssh
    ssh-keygen -t rsa -b 4096 -f "$SSH_KEY_PATH" -N "" -C "jenkins-control-node"
    chown -R jenkins:jenkins /var/lib/jenkins/.ssh
    chmod 700 /var/lib/jenkins/.ssh
    chmod 600 "$SSH_KEY_PATH"
    echo -e "${YELLOW}Clé publique (à copier dans terraform.tfvars) :${NC}"
    cat "${SSH_KEY_PATH}.pub"
fi

# ---------------------- CONFIGURATION SUPPLÉMENTAIRE ----------------------
echo -e "${GREEN}=== Optimisations pour Debian 13 ===${NC}"

# S'assurer que Jenkins a les bons droits
chown -R jenkins:jenkins /var/lib/jenkins 2>/dev/null || true

# Ajouter Jenkins au groupe sudo (optionnel)
usermod -aG sudo jenkins 2>/dev/null || true

# Ajouter l'utilisateur courant au groupe jenkins
if [ -n "${SUDO_USER:-}" ]; then
    usermod -aG jenkins "$SUDO_USER" 2>/dev/null || true
fi

# Configurer le firewall si ufw est installé
if command -v ufw &> /dev/null; then
    ufw allow 8080/tcp comment 'Jenkins web interface'
    ufw allow 6443/tcp comment 'k3s API server'
    ufw allow 22/tcp comment 'SSH'
    ufw --force enable
    echo -e "${YELLOW}Firewall configuré: ports 8080 et 6443 ouverts${NC}"
fi

# Ajouter /root/.local/bin au PATH
if ! grep -q 'export PATH="$PATH:$HOME/.local/bin"' ~/.bashrc 2>/dev/null; then
    echo 'export PATH="$PATH:$HOME/.local/bin"' >> ~/.bashrc
fi

# Créer un alias pour kubectl
if ! grep -q "alias k=" ~/.bashrc 2>/dev/null; then
    echo "alias k='kubectl'" >> ~/.bashrc
fi

# ---------------------- INFORMATIONS K3S ----------------------
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}=== Informations k3s ===${NC}"
echo "Version k3s:"
kubectl version --short 2>/dev/null || kubectl version
echo -e "\nNœuds du cluster:"
kubectl get nodes -o wide
echo -e "\nPods système:"
kubectl get pods -n kube-system

# ---------------------- VÉRIFICATION FINALE ----------------------
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Versions installées:${NC}"
java --version 2>/dev/null | head -n1 || echo "Java non trouvé"
echo "Terraform: $(terraform version 2>/dev/null | head -n1 || echo 'Non trouvé')"
echo "Helm: $(helm version 2>/dev/null | head -n1 || echo 'Non trouvé')"

# Vérifier Ansible
if command -v ansible &> /dev/null; then
    echo "Ansible: $(ansible --version 2>/dev/null | head -n1)"
elif [ -f "$HOME/.local/bin/ansible" ]; then
    echo "Ansible: $($HOME/.local/bin/ansible --version 2>/dev/null | head -n1)"
else
    echo "Ansible installé avec pipx"
fi

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Installation terminée !${NC}"
echo "Mot de passe Jenkins : $(cat /var/lib/jenkins/secrets/initialAdminPassword 2>/dev/null || echo 'Non trouvé')"
echo -e "${YELLOW}URL Jenkins: http://$(hostname -I | awk '{print $1}'):8080${NC}"
echo -e "${YELLOW}k3s API: https://$(hostname -I | awk '{print $1}'):6443${NC}"
echo -e "${YELLOW}Kubeconfig: /etc/rancher/k3s/k3s.yaml${NC}"
echo -e "${YELLOW}Pour utiliser k9s, lancez: k9s${NC}"
echo -e "${YELLOW}Redémarrez votre session ou exécutez: source ~/.bashrc${NC}"

# Commande pour récupérer le token k3s si nécessaire
echo -e "\n${YELLOW}Token k3s pour ajouter des nœuds:${NC}"
cat /var/lib/rancher/k3s/server/node-token 2>/dev/null || echo "Non trouvé"