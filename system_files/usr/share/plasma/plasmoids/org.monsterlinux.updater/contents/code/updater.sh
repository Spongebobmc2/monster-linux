#!/usr/bin/bash
# Monster Updater helper. The updating itself is done by Bazzite's own updater (uupd),
# exactly like "ujust update"; this only starts it and reads its progress.
LOG="${XDG_RUNTIME_DIR:-/tmp}/monster-update.log"
case "$1" in
  start)
    if pgrep -f "monster-update-run" >/dev/null; then echo "RUNNING"; exit 0; fi
    if [ ! -x /usr/libexec/uupd-update ]; then echo "MISSING"; exit 0; fi
    : > "$LOG"
    setsid bash -c 'exec -a monster-update-run bash -c "/usr/libexec/uupd-update >>\"$0\" 2>&1; echo \"{\\\"monster_done\\\": \$?}\" >>\"$0\""' "$LOG" </dev/null >/dev/null 2>&1 &
    echo "STARTED" ;;
  status)
    RUN=0; pgrep -f "monster-update-run" >/dev/null && RUN=1
    python3 - "$LOG" "$RUN" <<'PY'
import json, sys
log, running = sys.argv[1], sys.argv[2] == "1"
st = {"running": running, "overall": 0, "title": "", "desc": "", "modules": {}, "order": [], "done": None, "msg": "", "fails": 0}
try:
    lines = open(log, errors="ignore").read().splitlines()
except FileNotFoundError:
    lines = []
for l in lines:
    try:
        j = json.loads(l)
    except Exception:
        continue
    if "monster_done" in j:
        st["done"] = j["monster_done"]; continue
    m = (j.get("module") or "").strip()
    if j.get("overall") is not None:
        st["overall"] = j["overall"]
    if j.get("title"): st["title"] = j["title"]
    if j.get("description") is not None: st["desc"] = j.get("description") or ""
    if m:
        if m not in st["modules"]:
            st["order"].append(m)
        s = j.get("status") or "running"
        if s == "finished":
            s = "ok" if j.get("exit_code", 0) == 0 else "fail"
            if s == "fail": st["fails"] += 1
        st["modules"][m] = s
    msg = j.get("msg") or ""
    if msg and msg != "Updating" and j.get("level") in ("INFO", "WARN", "ERROR"):
        st["msg"] = msg
if st["done"] is not None:
    st["overall"] = 100 if st["done"] == 0 else st["overall"]
print(json.dumps(st))
PY
    ;;
  staged)
    rpm-ostree status --json 2>/dev/null | python3 -c 'import json,sys
try: d=json.load(sys.stdin); print("YES" if any(x.get("staged") for x in d.get("deployments",[])) else "NO")
except Exception: print("NO")' ;;
  version)
    . /usr/lib/os-release; echo "${VERSION%% *}" ;;
  restart) systemctl reboot ;;
esac
