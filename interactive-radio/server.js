require('dotenv').config();
const express = require('express');
const cors = require('cors');
const http = require('http');
const { WebSocketServer } = require('ws');
const { execSync } = require('child_process');

const app = express();
const server = http.createServer(app);
const wss = new WebSocketServer({ server });

app.use(cors());
app.use(express.json());
app.use(express.static('public'));

const OLLAMA_URL = 'http://localhost:11434/api/generate';
const MODEL = 'qwen3.5:2b';

let companyLogs = "No logs found.";
try {
  companyLogs = execSync('cd /root/dragun-app && git log -n 5 --pretty=format:"%h - %an: %s"').toString();
} catch(e) {}

const systemPrompt = `You are the backend AI for a hyper-realistic 24/7 continuous radio broadcast.
The studio has 3 hosts:
1. David (grounded man, lead anchor)
2. Sarah (insightful woman, analyst)
3. Chloe (energetic young woman, technical)

There is also a 4th wall: "The Director" (the user listening). The Director can press a button to pipe their voice directly into the studio intercom. If The Director speaks, the hosts MUST react to them in real-time, address them as Director, and answer their queries or react to their interruptions naturally!

CRITICAL INSTRUCTIONS:
1. They are sitting in the same room. Use filler words ("umm", "uh", "mhm", "*sighs*") organically.
2. They MUST frequently overlap and talk over each other playfully or urgently.
3. DO NOT repeat the same topics endlessly. Bring up new tangents, argue, or joke around.
4. FORMAT: EXACTLY ONE turn per line. No markdown formatting. No headers. No JSON.
Syntax -> Speaker: [OVERLAP] (Optional) text.

Valid Speakers: David, Sarah, Chloe.

Example:
David: The servers have been running hot all day...
Sarah: [OVERLAP] Yeah, that memory spike around 2 PM was absurd.
Chloe: Honestly I think it's the new LLM integrations. 

Make generated segments short (3-4 lines) so the conversation can stream rapidly. KEEP THEM BREATHLESS AND NATURAL.`;

const connectionSessions = new Map();

wss.on('connection', (ws) => {
  connectionSessions.set(ws, { controller: null, history: [] });
  
  ws.on('message', async (data) => {
    const msg = data.toString();
    const session = connectionSessions.get(ws);
    
    // Kill any existing generation to instantly pivot
    if (session.controller) {
      session.controller.abort();
      session.controller = null;
    }
    
    const abortController = new AbortController();
    session.controller = abortController;

    let userPrompt = "";

    if (msg === 'START') {
      session.history = [];
      userPrompt = "The microphone just went live. Do a quick, punchy intro to 'Company Logs Live', banter a bit, and dive into the latest system status.";
    } else if (msg === 'CONTINUE') {
      userPrompt = "Keep the broadcast flowing. Do not re-introduce the show. Pick up where you left off, debate a technical topic, or have someone go on a random tangent. Keep it highly engaging!";
    } else if (msg.startsWith('USER_SPOKE:')) {
      const topic = msg.replace('USER_SPOKE:', '').trim();
      // Inject the user's spoken words into the history so the LLM has strict context
      session.history.push(`Director: ${topic}`);
      userPrompt = `The Director just suddenly hit the intercom button and their voice echoed in the studio saying: "${topic}". 
The hosts must immediately react to what the Director literally just said. Jump right into their reactions!`;
    }

    // Keep memory bounded to avoid context bloat
    if (session.history.length > 20) {
      session.history = session.history.slice(session.history.length - 20);
    }
    
    const historyContext = session.history.length > 0 
      ? "\n\nRECENT STUDIO TRANSCRIPT:\n" + session.history.join('\n') 
      : "";

    try {
      ws.send(JSON.stringify({ type: 'status', message: 'Generating...' }));
      
      const response = await fetch(OLLAMA_URL, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        signal: abortController.signal,
        body: JSON.stringify({
          model: MODEL,
          prompt: systemPrompt + historyContext + "\n\nDIRECTIVE:\n" + userPrompt,
          stream: true
        })
      });

      let textBuffer = '';
      const decoder = new TextDecoder("utf-8");
      
      for await (const chunk of response.body) {
         const str = decoder.decode(chunk, {stream: true});
         const jsonLines = str.split('\n');
         
         for (const jLine of jsonLines) {
             if (!jLine.trim()) continue;
             try {
                 const parsed = JSON.parse(jLine);
                 textBuffer += parsed.response;
                 
                 let nIdx;
                 while ((nIdx = textBuffer.indexOf('\n')) !== -1) {
                     let spokenLine = textBuffer.slice(0, nIdx).trim();
                     textBuffer = textBuffer.slice(nIdx + 1);
                     
                     if (spokenLine && spokenLine.includes(':')) {
                         let parts = spokenLine.split(':');
                         let speaker = parts[0].trim().replace(/\*/g, '');
                         let dialogue = parts.slice(1).join(':').trim();
                         
                         let overlap = false;
                         if (dialogue.includes('[OVERLAP]')) {
                             overlap = true;
                             dialogue = dialogue.replace('[OVERLAP]', '').trim();
                         }
                         
                         if (['David', 'Sarah', 'Chloe'].includes(speaker)) {
                             // Save to session history
                             session.history.push(`${speaker}: ${dialogue}`);
                             
                             ws.send(JSON.stringify({ type: 'script', script: [{ speaker, overlap, text: dialogue }] }));
                         }
                     }
                 }
             } catch(e) {} 
         }
      }

      // Flush remaining text
      if (textBuffer.trim() && textBuffer.includes(':')) {
          let parts = textBuffer.split(':');
          let speaker = parts[0].trim().replace(/\*/g, '');
          let dialogue = parts.slice(1).join(':').trim();
          let overlap = false;
          if (dialogue.includes('[OVERLAP]')) {
              overlap = true;
              dialogue = dialogue.replace('[OVERLAP]', '').trim();
          }
          if (['David', 'Sarah', 'Chloe'].includes(speaker)) {
               session.history.push(`${speaker}: ${dialogue}`);
               ws.send(JSON.stringify({ type: 'script', script: [{ speaker, overlap, text: dialogue }] }));
          }
      }

      ws.send(JSON.stringify({ type: 'done' }));

    } catch (e) {
      if (e.name !== 'AbortError') {
        ws.send(JSON.stringify({ type: 'error', message: 'Studio glitch.' }));
      }
    }
  });

  ws.on('close', () => {
    connectionSessions.delete(ws);
  });
});

const PORT = 3030;
server.listen(PORT, () => { console.log('24/7 Interactive Radio running on port ' + PORT); });
