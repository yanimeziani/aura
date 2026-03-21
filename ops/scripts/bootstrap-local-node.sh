#!/bin/bash
set -e

echo "🚀 Bootstrapping Aura Sovereign Node (AI & PaaS)..."

# 1. System Update & Essentials
echo "📦 Updating system and installing base tools..."
sudo apt-get update && sudo apt-get upgrade -y
sudo apt-get install -y curl wget git build-essential software-properties-common ufw

# 2. NVIDIA CUDA Drivers (The Engine)
echo "🟢 Installing NVIDIA Drivers & CUDA Toolkit..."
sudo apt-get install -y linux-headers-$(uname -r)
sudo apt-get install -y nvidia-driver firmware-misc-nonfree
# Note: A reboot is usually required after this step before Docker GPU works.

# 3. Docker & NVIDIA Container Toolkit (The PaaS Foundation)
echo "🐳 Installing Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
  sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
sudo apt-get update && sudo apt-get install -y nvidia-container-toolkit
sudo systemctl restart docker

# 4. Ollama (The AI API)
echo "🦙 Installing Ollama for local inference..."
curl -fsSL https://ollama.com/install.sh | sh

# 5. Tailscale (The Secure Mesh)
echo "🌐 Installing Tailscale..."
curl -fsSL https://tailscale.com/install.sh | sh

echo "✅ Bootstrap Phase 1 Complete."
echo "--- NEXT STEPS ---"
echo "1. Reboot the machine: sudo reboot"
echo "2. Run: sudo tailscale up"
echo "3. Run: ollama run llama3.2"
echo "4. Run: ollama pull nomic-embed-text"
