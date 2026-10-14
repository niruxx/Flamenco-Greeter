#!/bin/sh
# Log-in scenarios against tools/mock-greetd.py, with fingerprint login on.
#
#   tools/test-login.sh
#
# Runs the real greeter (not the preview's fake login) in a window, from a
# desktop session after `make dev`, with a throwaway home so your settings stay
# untouched. Each scenario checks greetd's side of the conversation: one
# session started (or none), and no replies to requests out of order.
set -u

root=$(cd "$(dirname "$0")/.." && pwd)
G=$root/greeter
T=${XDG_CACHE_HOME:-$HOME/.cache}/flamenco-greeter-test
mkdir -p "$T"

[ -e "$G/Commons" ] || { echo "test-login: run 'make dev' first" >&2; exit 1; }

# flamenco-greeter, but reporting a reader + pam_fprintd so the UI turns fingerprint login on
cat > "$T/fake-bin" <<WRAP
#!/bin/sh
if [ "\$1" = fingerprint ] && [ "\$2" = --json ]; then
    echo '{"module": true, "pam": true, "managed": true, "outdated": false, "readers": 1, "fprintd": true}'; exit 0
fi
exec "$root/bin/flamenco-greeter" "\$@"
WRAP
chmod +x "$T/fake-bin"

ipc() { qs -p "$G" ipc call greeter "$@" >/dev/null 2>&1; }

start() {   # start: mock greetd (ROUND / ENROLLED from the environment) + the greeter
    rm -rf "$T/home" "$T/good" "$T/bad"; mkdir -p "$T/home/state"
    python3 "$root/tools/mock-greetd.py" "$T/greetd.sock" > "$T/greetd.log" 2>&1 &
    mock=$!
    sleep 0.5
    HOME=$T/home XDG_CONFIG_HOME=$T/home/config XDG_STATE_HOME=$T/home/state XDG_CACHE_HOME=$T/home/cache \
    GREETD_SOCK=$T/greetd.sock FLAMENCO_GREETER=1 FLAMENCO_GREETER_WINDOWED=1 \
    FLAMENCO_GREETER_CACHE=$T/home FLAMENCO_GREETER_BIN=$T/fake-bin \
        timeout 60 qs -p "$G" > "$T/qs.log" 2>&1 &
}

finger() { touch "$T/$1"; }    # finger good|bad

failed=0
check() {   # check NAME login|nologin
    sleep 2
    qs kill -p "$G" >/dev/null 2>&1; sleep 0.5
    kill "$mock" 2>/dev/null; wait "$mock" 2>/dev/null
    started=$(grep -c "STARTED SESSION" "$T/greetd.log")
    bad=$(grep -cE "session not ready|already being configured|no session" "$T/greetd.log")
    if { [ "$2" = login ] && [ "$started" = 1 ]; } || { [ "$2" = nologin ] && [ "$started" = 0 ]; }; then
        [ "$bad" = 0 ] && r=PASS || r=FAIL
    else
        r=FAIL
    fi
    [ "$r" = FAIL ] && { failed=$((failed + 1)); cp "$T/greetd.log" "$T/failed-$(echo "$1" | tr ' ,' '__').log"; }
    printf '  %-40s %s\n' "$1" "$r"
}

echo "Log-in scenarios (mock greetd, fingerprint login on):"

ROUND=10 start; sleep 4; ipc type hunter2; ipc submit; sleep 9
check "password during a scan" login

ROUND=10 start; sleep 4; ipc type hunter2; ipc submit; sleep 2; finger good; sleep 2
check "finger while a password waits" login

ROUND=3 start; sleep 11; finger good; sleep 2
check "idle rounds restart, then finger" login

ROUND=10 start; sleep 4; finger bad; sleep 4; finger good; sleep 2
check "wrong finger, then right finger" login

ROUND=4 start; sleep 3; ipc type wrong; ipc submit; sleep 6; finger good; sleep 2
check "wrong password, then finger" login

ROUND=4 start; sleep 3; ipc reset; sleep 5; finger good; sleep 2
check "Esc mid-scan, then finger" login

ENROLLED=0 start; sleep 4; ipc type hunter2; ipc submit; sleep 2
check "no fingers enrolled, password" login

ENROLLED=0 start; sleep 4; ipc type nope; ipc submit; sleep 3
check "wrong password only" nologin

[ "$failed" = 0 ] && echo "All passed." || { echo "$failed failed; greetd logs in $T"; exit 1; }
