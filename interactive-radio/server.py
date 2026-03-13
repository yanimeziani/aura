import os, json, asyncio, uuid, base64
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from faster_whisper import WhisperModel
import httpx

print("Loading Whisper model...")
# CPU, int8 for speed
whisper_model = WhisperModel("tiny.en", device="cpu", compute_type="int8")
print("Whisper loaded.")

app = FastAPI()

if not os.path.exists("public"):
    os.makedirs("public")

app.mount("/public", StaticFiles(directory="public"), name="public")

@app.get("/")
def read_root():
    return FileResponse("public/index.html")

OLLAMA_URL = "http://127.0.0.1:11434/api/generate"
MODEL = "qwen3.5:2b"

# Edge TTS voices
VOICES = {
    "David": "en-US-ChristopherNeural", 
    "Sarah": "en-US-AriaNeural",       
    "Chloe": "en-US-AnaNeural",        
    "Director": "en-US-GuyNeural"      
}

def get_briefing():
    path = "briefing.json"
    if os.path.exists(path):
        try:
            with open(path, "r") as f:
                data = json.load(f)
                return "\n".join([f"- {b['source']}: {b['update']}" for b in data])
        except:
            pass
    return "No recent system updates."

def get_system_prompt():
    briefing = get_briefing()
    return f"""You are producing a hyper-realistic, continuous live radio broadcast.
The studio has 3 hosts:
1. David (grounded man, lead anchor)
2. Sarah (insightful woman, analyst)
3. Chloe (energetic young woman, technical)

The 4th wall: "The Director" (the user listening). The Director pipes their voice directly into the studio intercom. The hosts MUST react to them in real-time!

LATEST SYSTEM UPDATES (FOR CONTEXT):
{briefing}

CRITICAL INSTRUCTIONS:
1. They are sitting in the same room. Use filler words ("umm", "uh", "mhm", "well") organically.
2. They MUST frequently overlap and talk over each other gently.
3. Use the LATEST SYSTEM UPDATES to drive conversation naturally. Mention PRD changes, vault crypto, or git logs.
4. FORMAT: EXACTLY ONE turn per line. No markdown formatting.
Syntax -> Speaker: [OVERLAP] (Optional) text.
"""

async def generate_audio(text: str, speaker: str) -> str:
    """Generates MP3 using Edge-TTS, returns Base64 string"""
    voice = VOICES.get(speaker, "en-US-ChristopherNeural")
    out_path = f"/tmp/{uuid.uuid4()}.mp3"
    
    proc = await asyncio.create_subprocess_exec(
        "edge-tts", "--voice", voice, "--text", text, "--write-media", out_path,
        stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE
    )
    await proc.communicate()
    
    if os.path.exists(out_path):
        with open(out_path, "rb") as f:
            data = f.read()
        os.remove(out_path)
        return base64.b64encode(data).decode('utf-8')
    return ""

async def stream_ollama(prompt: str, websocket: WebSocket, session_history: list):
    history_text = "\n".join(session_history) if session_history else ""
    full_prompt = f"{get_system_prompt()}\n\nHISTORY:\n{history_text}\n\nDIRECTIVE:\n{prompt}"
    
    payload = {
        "model": MODEL,
        "prompt": full_prompt,
        "stream": True
    }
    
    text_buffer = ""
    try:
        async with httpx.AsyncClient(timeout=300.0) as client:
            async with client.stream("POST", OLLAMA_URL, json=payload) as r:
                async for chunk in r.aiter_bytes():
                    lines = chunk.decode("utf-8").split("\n")
                    for line in lines:
                        if not line.strip(): continue
                        try:
                            data = json.loads(line)
                            text_buffer += data.get("response", "")
                            
                            while "\n" in text_buffer:
                                n_idx = text_buffer.find("\n")
                                spoken_line = text_buffer[:n_idx].strip()
                                text_buffer = text_buffer[n_idx+1:]
                                
                                if spoken_line and ":" in spoken_line:
                                    parts = spoken_line.split(":")
                                    speaker = parts[0].strip().replace("*", "")
                                    dialogue = ":".join(parts[1:]).strip()
                                    
                                    overlap = False
                                    if "[OVERLAP]" in dialogue:
                                        overlap = True
                                        dialogue = dialogue.replace("[OVERLAP]", "").strip()
                                        
                                    if speaker in ["David", "Sarah", "Chloe"]:
                                        session_history.append(f"{speaker}: {dialogue}")
                                        if len(session_history) > 20:
                                            session_history.pop(0)
                                            
                                        print(f"Synthesizing {speaker}: {dialogue}")
                                        b64_audio = await generate_audio(dialogue, speaker)
                                        
                                        await websocket.send_json({
                                            "type": "chunk", 
                                            "speaker": speaker, 
                                            "text": dialogue, 
                                            "overlap": overlap,
                                            "audio": b64_audio
                                        })
                        except Exception as e:
                            pass
        
        # Flush remaining
        if text_buffer.strip() and ":" in text_buffer:
            parts = text_buffer.split(":")
            speaker = parts[0].strip().replace("*", "")
            dialogue = ":".join(parts[1:]).strip()
            overlap = False
            if "[OVERLAP]" in dialogue:
                overlap = True
                dialogue = dialogue.replace("[OVERLAP]", "").strip()
                
            if speaker in ["David", "Sarah", "Chloe"]:
                session_history.append(f"{speaker}: {dialogue}")
                b64_audio = await generate_audio(dialogue, speaker)
                await websocket.send_json({
                    "type": "chunk", 
                    "speaker": speaker, 
                    "text": dialogue, 
                    "overlap": overlap,
                    "audio": b64_audio
                })
                
        await websocket.send_json({"type": "done"})
        
    except asyncio.CancelledError:
        print("LLM stream cancelled")
    except Exception as e:
        print("LLM Errror:", e)
        await websocket.send_json({"type": "error", "message": "Failed to generate"})

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()
    session_history = []
    current_task = None
    
    try:
        while True:
            message = await websocket.receive()
            
            if "bytes" in message:
                if current_task and not current_task.done():
                    current_task.cancel()
                    
                await websocket.send_json({"type": "status", "message": "Transcribing audio..."})
                
                audio_bytes = message["bytes"]
                webm_path = f"/tmp/{uuid.uuid4()}.webm"
                with open(webm_path, "wb") as f:
                    f.write(audio_bytes)
                
                try:
                    segments, info = whisper_model.transcribe(webm_path, beam_size=1)
                    text = " ".join([segment.text for segment in segments]).strip()
                    os.remove(webm_path)
                    
                    if not text:
                        await websocket.send_json({"type": "status", "message": "No speech detected."})
                        continue
                        
                    print(f"USER TRANSCRIBED: {text}")
                    session_history.append(f"Director: {text}")
                    
                    await websocket.send_json({"type": "status", "message": "Generating Director TTS..."})
                    user_audiob64 = await generate_audio(text, "Director")
                    await websocket.send_json({
                        "type": "chunk",
                        "speaker": "Director",
                        "text": text,
                        "overlap": True,
                        "audio": user_audiob64
                    })
                    
                    directive = f"The Director just spoke loudly over the intercom: '{text}'\nThe hosts must instantly react to exactly what they said."
                    current_task = asyncio.create_task(stream_ollama(directive, websocket, session_history))
                    
                except Exception as e:
                    print("Whisper Error:", e)
                    await websocket.send_json({"type": "error", "message": "Failed to transcribe."})
                    
            elif "text" in message:
                text_msg = message["text"]
                if current_task and not current_task.done():
                    current_task.cancel()
                    
                if text_msg == "START":
                    session_history = []
                    directive = "Start a fresh broadcast segment. Mention the latest system status if available!"
                    current_task = asyncio.create_task(stream_ollama(directive, websocket, session_history))
                elif text_msg == "CONTINUE":
                    directive = "Continue the conversation naturally. Use the system updates as a pivot point if it makes sense."
                    current_task = asyncio.create_task(stream_ollama(directive, websocket, session_history))

    except WebSocketDisconnect:
        print("Client disconnected")
        if current_task and not current_task.done():
            current_task.cancel()

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=3030)
