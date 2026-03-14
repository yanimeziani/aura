#!/bin/bash

echo "=== RADIO STREAM SWEEP STATUS ==="

# 1. Ollama
if curl -s http://127.0.0.1:11434/api/tags > /dev/null; then
    echo "[OK] Ollama is running."
    if curl -s http://127.0.0.1:11434/api/tags | grep -q "qwen3.5:2b"; then
        echo "     [OK] Model qwen3.5:2b is available."
    else
        echo "     [FAIL] Model qwen3.5:2b NOT available."
    fi
else
    echo "[FAIL] Ollama is NOT running."
fi

# 2. Edge-TTS
if command -v edge-tts > /dev/null; then
    echo "[OK] edge-tts CLI is available."
else
    echo "[FAIL] edge-tts CLI NOT found."
fi

# 3. Faster Whisper
if python3 -c "from faster_whisper import WhisperModel; print('Whisper model loaded')" 2>/dev/null; then
    echo "[OK] faster-whisper is functional."
else
    echo "[FAIL] faster-whisper NOT functional or model missing."
fi

# 4. Port 3030
PID=$(lsof -t -i:3030)
if [ -n "$PID" ]; then
    echo "[OK] Port 3030 is active (PID: $PID)."
    ps -p $PID -o comm=
else
    echo "[WARN] Port 3030 is NOT active. Radio server is likely down."
fi

# 5. Check logs
echo "--- Recent Logs (python_server.log) ---"
tail -n 10 interactive-radio/python_server.log || echo "No log found."

echo "=== SWEEP COMPLETE ==="
