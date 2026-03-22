#!/usr/bin/env python3
"""
Bunkerised n8n MCP Bridge
Acts as a Model Context Protocol (MCP) server for Cerberus.
Routes agent tool calls (like CRM updates, LinkedIn posts, Cal.com checks) 
securely through a local n8n instance to prevent direct external egress from the agent.
"""

import sys
import json
import os
import urllib.request
import urllib.error

# n8n webhook URL defaults to local bunker instance
N8N_WEBHOOK_URL = os.environ.get("N8N_WEBHOOK_URL", "http://127.0.0.1:5678/webhook/mcp-gateway")

def handle_tool_call(tool_name, arguments):
    """Forward the tool request to n8n to execute the external platform logic."""
    payload = {
        "tool": tool_name,
        "arguments": arguments,
        "source": "nexa_cerberus_mcp"
    }
    
    data = json.dumps(payload).encode('utf-8')
    req = urllib.request.Request(
        N8N_WEBHOOK_URL, 
        data=data, 
        headers={'Content-Type': 'application/json', 'User-Agent': 'Aura/MCP'}
    )
    
    try:
        with urllib.request.urlopen(req, timeout=10) as response:
            result = json.loads(response.read().decode('utf-8'))
            return {"content": [{"type": "text", "text": json.dumps(result)}]}
    except urllib.error.URLError as e:
        return {"content": [{"type": "text", "text": f"Error communicating with n8n bunker gateway: {e}"}], "isError": True}

def main():
    # Very basic stdio MCP implementation loop
    # In a full production scenario, this uses the official mcp-python SDK.
    # For this skeleton, we just document the bridge concept.
    
    print("Starting n8n MCP Bunker Bridge...", file=sys.stderr)
    
    while True:
        line = sys.stdin.readline()
        if not line:
            break
        
        try:
            req = json.loads(line)
            
            if req.get("method") == "initialize":
                resp = {
                    "jsonrpc": "2.0",
                    "id": req.get("id"),
                    "result": {
                        "protocolVersion": "2024-11-05",
                        "capabilities": {"tools": {}},
                        "serverInfo": {"name": "n8n-bunker-bridge", "version": "1.0.0"}
                    }
                }
                print(json.dumps(resp), flush=True)
                
            elif req.get("method") == "tools/list":
                resp = {
                    "jsonrpc": "2.0",
                    "id": req.get("id"),
                    "result": {
                        "tools": [
                            {
                                "name": "n8n_execute_workflow",
                                "description": "Trigger an automated workflow in n8n (interfaces with HubSpot, LinkedIn, Cal.com).",
                                "inputSchema": {
                                    "type": "object",
                                    "properties": {
                                        "workflow_name": {"type": "string"},
                                        "payload": {"type": "object"}
                                    },
                                    "required": ["workflow_name", "payload"]
                                }
                            }
                        ]
                    }
                }
                print(json.dumps(resp), flush=True)
                
            elif req.get("method") == "tools/call":
                params = req.get("params", {})
                tool_name = params.get("name")
                args = params.get("arguments", {})
                
                result = handle_tool_call(tool_name, args)
                
                resp = {
                    "jsonrpc": "2.0",
                    "id": req.get("id"),
                    "result": result
                }
                print(json.dumps(resp), flush=True)
                
        except json.JSONDecodeError:
            continue

if __name__ == "__main__":
    main()
