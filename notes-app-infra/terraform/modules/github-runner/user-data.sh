#!/bin/bash
set -euo pipefail

# ──────────────────────────────────────────────
# GitHub Actions Self-Hosted Runner Setup Script
# Installs: Docker, kubectl, Helm, Terraform, Trivy, AWS CLI
# Token fetched from SSM at boot — never hardcoded
# ──────────────────────────────────────────────

export DEBIAN_FRONTEND=noninteractive

# System updates
apt-get update -y
apt-get upgrade -y

# ── Docker ──
apt-get install -y ca-certificates curl gnupg unzip jq git
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin

# ── kubectl ──
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.33/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.33/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list
apt-get update -y
apt-get install -y kubectl

# ── Helm ──
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# ── Terraform ──
apt-get install -y software-properties-common
curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list
apt-get update -y
apt-get install -y terraform

# ── Trivy ──
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin

# ── AWS CLI v2 ──
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
unzip -q /tmp/awscliv2.zip -d /tmp
/tmp/aws/install
rm -rf /tmp/aws /tmp/awscliv2.zip

# ── Create runner user ──
useradd -m -s /bin/bash runner
usermod -aG docker runner

# ── Fetch GitHub Runner token from SSM at boot ──
# Token is never hardcoded — fetched securely at runtime
echo "Fetching GitHub runner token from SSM..."
RUNNER_TOKEN=$(aws ssm get-parameter \
  --name "${ssm_token_path}" \
  --with-decryption \
  --region "${aws_region}" \
  --query Parameter.Value \
  --output text)

if [ -z "$RUNNER_TOKEN" ]; then
  echo "ERROR: Failed to fetch runner token from SSM. Aborting."
  exit 1
fi

# ── Install GitHub Actions Runner ──
RUNNER_VERSION=$(curl -s https://api.github.com/repos/actions/runner/releases/latest | jq -r '.tag_name' | sed 's/v//')
mkdir -p /home/runner/actions-runner
cd /home/runner/actions-runner
curl -o actions-runner-linux-x64.tar.gz -L "https://github.com/actions/runner/releases/download/v$${RUNNER_VERSION}/actions-runner-linux-x64-$${RUNNER_VERSION}.tar.gz"
tar xzf actions-runner-linux-x64.tar.gz
rm actions-runner-linux-x64.tar.gz
chown -R runner:runner /home/runner/actions-runner

# ── Configure runner ──
su - runner -c "
  cd /home/runner/actions-runner && \
  ./config.sh \
    --url ${github_runner_url} \
    --token $RUNNER_TOKEN \
    --name ${runner_name} \
    --labels ${runner_labels} \
    --unattended \
    --replace
"

# ── Install and start as service ──
cd /home/runner/actions-runner
./svc.sh install runner
./svc.sh start

# ── Clear token from memory — no longer needed ──
unset RUNNER_TOKEN

echo "GitHub Actions self-hosted runner setup complete!"