#!/bin/bash
# Setup for Jenkins + Docker + SonarQube + Trivy (fixed: 2026 Jenkins key, Java 21,
# SonarQube kernel setting, restart policy). Output goes to /var/log/cloud-init-output.log
export DEBIAN_FRONTEND=noninteractive
mkdir -p /etc/apt/keyrings

apt-get update -y

# ---- Java 21 (Temurin) ----
wget -O - https://packages.adoptium.net/artifactory/api/gpg/key/public | tee /etc/apt/keyrings/adoptium.asc
. /etc/os-release
echo "deb [signed-by=/etc/apt/keyrings/adoptium.asc] https://packages.adoptium.net/artifactory/deb $VERSION_CODENAME main" | tee /etc/apt/sources.list.d/adoptium.list
apt-get update -y
apt-get install -y temurin-21-jdk fontconfig libatomic1
/usr/bin/java --version

# ---- Jenkins (2026 signing key) ----
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key | tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" | tee /etc/apt/sources.list.d/jenkins.list > /dev/null
apt-get update -y
apt-get install -y jenkins
systemctl enable --now jenkins

# ---- Docker ----
apt-get install -y docker.io
usermod -aG docker ubuntu
usermod -aG docker jenkins
systemctl enable --now docker

# ---- SonarQube (needs a higher kernel map limit) ----
sysctl -w vm.max_map_count=524288
echo "vm.max_map_count=524288" >> /etc/sysctl.conf
docker run -d --name sonar --restart unless-stopped -p 9000:9000 sonarqube:lts-community

# ---- Trivy ----
apt-get install -y wget apt-transport-https gnupg lsb-release
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --dearmor | tee /usr/share/keyrings/trivy.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/trivy.list
apt-get update -y
apt-get install -y trivy

# Restart Jenkins so it picks up the docker group
systemctl restart jenkins
echo "SETUP FINISHED"
