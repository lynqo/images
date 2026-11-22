import json
import socket
import sys
import time

deadline = time.time() + 600
while time.time() < deadline:
    try:
        with socket.socket(socket.AF_UNIX) as agent:
            agent.settimeout(5)
            agent.connect(sys.argv[1])
            agent.sendall(b'{"execute": "guest-get-osinfo"}\n')
            reply = json.loads(agent.makefile().readline())
            print("guest agent up:", reply["return"]["pretty-name"])
            sys.exit(0)
    except Exception:
        time.sleep(5)
sys.exit("guest agent did not answer")
