#!/bin/bash
set -e

echo "🚀 Bootstrapping Jetson Orin Nano (Aura Edge Node)..."

# 1. Update and JetPack Essentials
echo "📦 Updating JetPack system..."
sudo apt-get update && sudo apt-get upgrade -y
sudo apt-get install -y curl wget git build-essential jtop

# 2. NVIDIA Container Runtime (Pre-installed in JetPack, but let's verify)
echo "🐳 Verifying NVIDIA Container Runtime..."
sudo apt-get install -y nvidia-container-toolkit
sudo systemctl restart docker

# 3. Ollama for ARM64 (The AI API)
echo "🦙 Installing Ollama (ARM64 Optimized)..."
curl -fsSL https://ollama.com/install.sh | sh

# 4. Tailscale (The Secure Mesh)
echo "🌐 Installing Tailscale..."
curl -fsSL https://tailscale.com/install.sh | sh

# 5. Optimization for Jetson
echo "⚡ Setting Jetson Power Mode to MAX..."
sudo nvpmodel -m 0
sudo jetson_clocks

echo "✅ Jetson Orin Nano Bootstrap Complete."
echo "--- NEXT STEPS ---"
echo "1. Run: sudo tailscale up"
echo "2. Run: ollama pull llama3.2"
echo "3. Run: jtop (to monitor your GPU and power in real-time)"
