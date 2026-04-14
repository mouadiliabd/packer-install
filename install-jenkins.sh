#!/bin/bash
set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

echo -e "${GREEN}=== Mise à jour du système ===${NC}"
apt update && apt upgrade -y

echo -e "${GREEN}=== Installation des dépendances ===${NC}"
apt install -y curl wget gnupg jq unzip openssh-client python3-pip python3-venv

# ---------------------- JENKINS ----------------------
echo -e "${GREEN}=== Installation de Jenkins ===${NC}"
rm -f /etc/apt/sources.list.d/jenkins.list /usr/share/keyrings/jenkins-keyring.* 2>/dev/null || true
mkdir -p /etc/apt/keyrings

# Importer la clé GPG de Jenkins (mise à jour pour 2026)
wget -q -O /etc/apt/keyrings/jenkins-keyring.asc https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key

# Ajouter le repository avec la clé correctement référencée
echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" | tee /etc/apt/sources.list.d/jenkins.list > /dev/null

apt update

# Pour Debian 13, installer openjdk-21-jdk (plus complet que jre)
apt install -y fontconfig openjdk-21-jdk jenkins

# Configurer Jenkins pour utiliser Java 21 explicitement
if [ -f /etc/default/jenkins ]; then
    sed -i 's|#JAVA_HOME=.*|JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64|' /etc/default/jenkins
fi

systemctl daemon-reload
systemctl enable --now jenkins
echo -e "${YELLOW}Jenkins installé. Mot de passe : /var/lib/jenkins/secrets/initialAdminPassword${NC}"

# ---------------------- TERRAFORM ----------------------
echo -e "${GREEN}=== Installation de Terraform ===${NC}"
TERRAFORM_VERSION="1.7.5"
# Vérifier si l'architecture est ARM64 (possible sur Debian 13)
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

# ---------------------- ANSIBLE (via pip avec venv) ----------------------
echo -e "${GREEN}=== Installation de Ansible ===${NC}"
# Debian 13 préfère pipx ou venv pour les packages Python
if command -v pipx &> /dev/null; then
    pipx install --system-site-packages ansible
    pipx ensurepath
else
    # Alternative avec venv
    python3 -m venv /opt/ansible-venv
    /opt/ansible-venv/bin/pip install --upgrade pip
    /opt/ansible-venv/bin/pip install ansible
    # Créer un lien symbolique pour un accès facile
    ln -sf /opt/ansible-venv/bin/ansible /usr/local/bin/ansible
    ln -sf /opt/ansible-venv/bin/ansible-playbook /usr/local/bin/ansible-playbook
    ln -sf /opt/ansible-venv/bin/ansible-galaxy /usr/local/bin/ansible-galaxy
fi

# ---------------------- KUBECTL ----------------------
echo -e "${GREEN}=== Installation de kubectl ===${NC}"
# Détection d'architecture pour kubectl
if [ "$ARCH" = "aarch64" ]; then
    KUBECTL_ARCH="arm64"
else
    KUBECTL_ARCH="amd64"
fi

curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/${KUBECTL_ARCH}/kubectl"
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl && rm kubectl

# ---------------------- HELM (optionnel mais utile pour k8s) ----------------------
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

# ---------------------- CONFIGURATION SUPPLÉMENTAIRE POUR DEBIAN 13 ----------------------
echo -e "${GREEN}=== Optimisations pour Debian 13 ===${NC}"

# S'assurer que Jenkins a les bons droits sur /var/lib/jenkins
chown -R jenkins:jenkins /var/lib/jenkins 2>/dev/null || true

# Ajouter Jenkins au groupe sudo (optionnel, pour certaines tâches)
usermod -aG sudo jenkins 2>/dev/null || true

# Configurer le firewall si ufw est installé
if command -v ufw &> /dev/null; then
    ufw allow 8080/tcp comment 'Jenkins web interface'
    ufw allow 22/tcp comment 'SSH'
    echo -e "${YELLOW}Firewall configuré: port 8080 ouvert pour Jenkins${NC}"
fi

# Vérifier les versions installées
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Versions installées:${NC}"
java --version 2>/dev/null | head -n1 || echo "Java non trouvé"
echo "Terraform: $(terraform version 2>/dev/null | head -n1 || echo 'Non trouvé')"
echo "kubectl: $(kubectl version --client 2>/dev/null | head -n1 || echo 'Non trouvé')"
echo "Helm: $(helm version 2>/dev/null | head -n1 || echo 'Non trouvé')"
if command -v ansible &> /dev/null; then
    echo "Ansible: $(ansible --version 2>/dev/null | head -n1)"
else
    echo "Ansible installé dans /opt/ansible-venv"
fi

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Installation terminée !${NC}"
echo "Mot de passe Jenkins : $(cat /var/lib/jenkins/secrets/initialAdminPassword 2>/dev/null || echo 'Non trouvé')"
echo -e "${YELLOW}URL Jenkins: http://$(hostname -I | awk '{print $1}'):8080${NC}"