#!/bin/bash
echo "[$(date)] Initializing Aura Launch Sequence: BMAD v6 Protocol" | tee -a /var/log/cerberus/launch.log

# 1. Start Cerberus Unified Gateway
nohup /root/core/cerberus/runtime/cerberus-core/zig-out/bin/cerberus gateway --port 3000 > /var/log/cerberus/gateway.log 2>&1 &
echo "[$(date)] Cerberus Gateway started." | tee -a /var/log/cerberus/launch.log

# 2. Start Web Dashboard (Commercial & Public)
cd /root/apps/web
nohup npm run start > /var/log/cerberus/web.log 2>&1 &
echo "[$(date)] Web Dashboard (meziani.ai / aura.meziani.org) started." | tee -a /var/log/cerberus/launch.log

# 3. Trigger arXiv CP Pipeline
cd /root/research/aura-manifesto
# Compile final version
/root/core/cerberus/runtime/cerberus-core/zig-out/bin/cerberus research render-manifesto --source /root/research/aura-manifesto/main.tex --out /root/research/aura-manifesto/main.pdf
echo "[$(date)] arXiv CP: Aura Manifesto compiled." | tee -a /var/log/cerberus/launch.log

# 4. Launch Spider Infection spread (Canadian Centrist Cluster)
# Note: Using the Media Outreach Agent via CLI to initiate targeting
nohup /root/core/cerberus/runtime/cerberus-core/zig-out/bin/cerberus agent -m "Launch spider infection spread to Algeria, Canada, Australia, and United Nations (Worldwide) clusters (centrist focus). High velocity." --config /root/core/cerberus/configs/media-agent.json > /var/log/cerberus/spider.log 2>&1 &
echo "[$(date)] Spider Infection spread initiated." | tee -a /var/log/cerberus/launch.log

echo "[$(date)] Launch Sequence Complete." | tee -a /var/log/cerberus/launch.log
