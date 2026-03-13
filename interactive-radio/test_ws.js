const WebSocket = require('ws');
const ws = new WebSocket('ws://127.0.0.1:3030');
ws.on('open', () => {
  console.log('Connected, sending START...');
  ws.send('START');
});
ws.on('message', (data) => {
  console.log('Received:', data.toString());
});
ws.on('error', console.error);
ws.on('close', () => console.log('Closed'));
