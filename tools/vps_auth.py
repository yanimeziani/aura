import os
import pty
import subprocess
import sys
import time

def run_ssh_with_password(cmd_args, password):
    master, slave = pty.openpty()
    proc = subprocess.Popen(cmd_args, stdin=slave, stdout=slave, stderr=slave, close_fds=True)
    os.close(slave)
    
    output = b""
    while proc.poll() is None:
        try:
            line = os.read(master, 1024)
            if not line: break
            output += line
            if b"password:" in line.lower():
                os.write(master, (password + "\n").encode())
        except OSError:
            break
            
    proc.wait()
    return proc.returncode, output.decode()

if __name__ == "__main__":
    host = sys.argv[1]
    password = sys.argv[2]
    # Simple test: ssh root@host "echo ok"
    rc, out = run_ssh_with_password(["ssh", "-o", "StrictHostKeyChecking=accept-new", f"root@{host}", "echo ok"], password)
    print(f"RC: {rc}")
    print(f"Output: {out}")
