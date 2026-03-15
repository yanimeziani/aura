import http.server
import socketserver
import os
import signal
from urllib.parse import urlparse, parse_qs

PORT = 9090
TOKEN = "AuraSovereign2026"
FILE_TO_SERVE = "/tmp/Aura_Full_Documentation_Export.txt"

class SecureFileHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        parsed_url = urlparse(self.path)
        query_params = parse_qs(parsed_url.query)
        
        if query_params.get("token", [""])[0] != TOKEN:
            self.send_response(403)
            self.end_headers()
            self.wfile.write(b"Forbidden: Invalid or missing token.")
            return
            
        if parsed_url.path == "/download":
            if os.path.exists(FILE_TO_SERVE):
                self.send_response(200)
                self.send_header("Content-Disposition", f'attachment; filename="Aura_Full_Documentation_Export.txt"')
                self.send_header("Content-Length", str(os.path.getsize(FILE_TO_SERVE)))
                self.send_header("Content-Type", "text/plain")
                self.end_headers()
                with open(FILE_TO_SERVE, "rb") as f:
                    self.wfile.write(f.read())
            else:
                self.send_response(404)
                self.end_headers()
                self.wfile.write(b"File not found on server.")
        else:
            self.send_response(404)
            self.end_headers()
            self.wfile.write(b"Endpoint not found.")

def run_server():
    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.TCPServer(("0.0.0.0", PORT), SecureFileHandler) as httpd:
        print(f"Secure File Server listening on port {PORT}...")
        httpd.serve_forever()

if __name__ == "__main__":
    run_server()
