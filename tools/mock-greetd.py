#!/usr/bin/env python3
"""A stand-in for greetd, faithful to the bits that matter here:

- one request at a time per client, and a reply is only written once the PAM
  step behind it finishes (so a fingerprint scan blocks everything queued behind it);
- cancel_session answers "success"; create_session with a session open is an error.

The PAM stack is: pam_fprintd (max-tries=1, timeout=ROUND seconds) then a password.
Touch the reader by creating files in this directory: `touch good` or `touch bad`.
"""
import json, os, socket, struct, sys, time

SOCK, CTL = sys.argv[1], os.path.dirname(os.path.abspath(sys.argv[1]))
ROUND = float(os.environ.get("ROUND", "10"))
PASSWORD = "hunter2"
ENROLLED = os.environ.get("ENROLLED", "1") == "1"

def log(*a): print(f"[{time.strftime('%H:%M:%S')}] greetd:", *a, flush=True)

def send(c, obj):
    b = json.dumps(obj).encode(); c.sendall(struct.pack("=I", len(b)) + b); log("->", obj)

def recv(c):
    h = c.recv(4, socket.MSG_WAITALL)
    if len(h) < 4: return None
    n, = struct.unpack("=I", h); return json.loads(c.recv(n, socket.MSG_WAITALL))

def finger(timeout):
    """Block like pam_fprintd: until a touch or the timeout."""
    end = time.monotonic() + timeout
    while time.monotonic() < end:
        for name in ("good", "bad"):
            p = os.path.join(CTL, name)
            if os.path.exists(p):
                os.unlink(p); log("finger:", name); return name
        time.sleep(0.05)
    log("finger: timed out"); return "timeout"

def pam(user):
    """Generator: yields auth messages, receives responses, returns True/False."""
    if ENROLLED:
        yield ("info", "Place your finger on the fingerprint reader")
        r = finger(ROUND)
        if r == "good": return True
        if r == "bad": yield ("error", "Failed to match fingerprint")
        else: yield ("info", "Verification timed out")
    resp = yield ("secret", "Password: ")
    return resp == PASSWORD

def serve(c):
    session = None; authed = False
    def step(value=None):
        nonlocal session, authed
        try:
            kind, msg = session.send(value)
            send(c, {"type": "auth_message", "auth_message_type": kind, "auth_message": msg})
        except StopIteration as e:
            session = None
            if e.value: authed = True; send(c, {"type": "success"})
            else: send(c, {"type": "error", "error_type": "auth_error", "description": "Authentication failed"})
    while True:
        req = recv(c)
        if req is None: log("client gone"); return
        shown = dict(req); shown.pop("response", None); log("<-", shown, "(with response)" if "response" in req else "")
        t = req["type"]
        if t == "create_session":
            if session or authed: send(c, {"type": "error", "error_type": "error", "description": "a session is already being configured"}); continue
            session = pam(req["username"]); step()
        elif t == "post_auth_message_response":
            if not session: send(c, {"type": "error", "error_type": "error", "description": "no session"}); continue
            step(req.get("response"))
        elif t == "cancel_session":
            session = None; authed = False; send(c, {"type": "success"})
        elif t == "start_session":
            if not authed: send(c, {"type": "error", "error_type": "error", "description": "session not ready"}); continue
            log("STARTED SESSION", req["cmd"]); send(c, {"type": "success"})

if os.path.exists(SOCK): os.unlink(SOCK)
s = socket.socket(socket.AF_UNIX); s.bind(SOCK); s.listen(1); log("listening on", SOCK)
while True:
    c, _ = s.accept(); log("client connected"); serve(c)
