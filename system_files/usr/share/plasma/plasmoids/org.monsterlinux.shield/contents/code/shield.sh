#!/usr/bin/bash
# Monster Shield helper: firewall (firewalld) and virus check (ClamAV).
# Prints one JSON line for "status" and "scan-status"; other actions print OK/FAIL lines.
S="${XDG_DATA_HOME:-$HOME/.local/share}/monster-shield"; mkdir -p "$S"
LOG="$S/scan.log"; Q="$S/quarantine"; PIDF="$S/scan.pid"
scanning() { [ -f "$PIDF" ] && kill -0 "$(cat "$PIDF")" 2>/dev/null; }
ok() { echo "OK $*"; }; fail() { echo "FAIL $*"; }

case "$1" in
status)
  fw=off; systemctl is-active -q firewalld && fw=on
  zone=$(firewall-cmd --get-default-zone 2>/dev/null)
  clam=no; command -v clamscan >/dev/null && clam=yes
  db=0; for f in /var/lib/clamav/daily.cld /var/lib/clamav/daily.cvd; do [ -f "$f" ] && db=$(stat -c %Y "$f"); done
  daily=no; systemctl --user is-enabled -q monster-shield-scan.timer 2>/dev/null && daily=yes
  last=$(cat "$S/last.json" 2>/dev/null || echo null)
  lastscan=$(python3 -c 'import json,sys
t=0
for f in sys.argv[1:]:
  try: t=max(t,int(json.load(open(f)).get("at",0)))
  except Exception: pass
print(t)' "$S/last.json" "$S/daily.json" "$S/last-run.json")
  qn=$(find "$Q" -type f 2>/dev/null | wc -l)
  printf '{"fw":"%s","zone":"%s","clam":"%s","db":%s,"daily":"%s","last":%s,"quarantined":%s,"lastscan":%s}\n' "$fw" "$zone" "$clam" "$db" "$daily" "$last" "$qn" "${lastscan:-0}" ;;

fw-on)
  pkexec /usr/libexec/monster-root fw-on ;;
fw-off)
  pkexec systemctl disable --now firewalld >/dev/null 2>&1 && ok "Firewall is off" || fail "Firewall not changed" ;;
fw-zone)
  case "$2" in home|public) pkexec /usr/libexec/monster-root fw-zone "$2" ;; *) fail "Unknown place" ;; esac ;;

update-db)
  command -v freshclam >/dev/null || { fail "Virus check is not installed"; exit 0; }
  pkexec /usr/libexec/monster-root freshclam ;;

scan)
  command -v clamscan >/dev/null || { echo "MISSING"; exit 0; }
  scanning && { echo "RUNNING"; exit 0; }
  case "$2" in
    quick) T=("$HOME/Downloads" "$HOME/Desktop" "$HOME/Documents" "$HOME/Quarantine" /tmp) ;;
    full)  T=("$HOME") ;;
    *)     T=("$2") ;;
  esac
  E=(--exclude-dir='/\.cache/' --exclude-dir='/\.local/share/Steam/' --exclude-dir='/\.steam/' --exclude-dir='/\.var/app/[^/]+/cache/' --exclude-dir='/\.local/share/flatpak/' --exclude-dir='/monster-shield/quarantine')
  : > "$LOG"
  existing=(); for t in "${T[@]}"; do [ -e "$t" ] && existing+=("$t"); done
  echo "$2" > "$S/kind"
  EXC=$(printf '%q ' "${E[@]}")
  cat > "$S/run.sh" <<R
#!/usr/bin/bash
echo "TOTAL \$(find "\$@" -type f 2>/dev/null | wc -l)" >> "$LOG"
clamscan -r --stdout --no-summary $EXC "\$@" >> "$LOG" 2>/dev/null
rc=\$?; echo "DONE \$rc" >> "$LOG"
printf '{"at":%s,"kind":"%s"}\n' "\$(date +%s)" "$2" > "$S/last-run.json"
R
  setsid bash "$S/run.sh" "${existing[@]}" </dev/null >/dev/null 2>&1 &
  echo $! > "$PIDF"
  echo "STARTED" ;;

scan-status)
  run=no; scanning && run=yes
  python3 - "$LOG" "$run" "$S" <<'PY'
import json, sys, os, time
log, run, S = sys.argv[1], sys.argv[2] == "yes", sys.argv[3]
total = scanned = 0; found = []; done = None
try:
    for l in open(log, errors="ignore"):
        l = l.rstrip("\n")
        if l.startswith("TOTAL "): total = int(l[6:] or 0)
        elif l.startswith("DONE "): done = int(l[5:] or 0)
        elif l.endswith(": OK") or l.endswith(": Empty file") or l.endswith(": Symbolic link"): scanned += 1
        elif l.endswith(" FOUND"):
            scanned += 1; p, v = l[:-6].rsplit(": ", 1); found.append({"file": p, "virus": v})
except FileNotFoundError:
    pass
st = {"running": run, "total": total, "scanned": scanned, "found": found, "done": done}
if done is not None and not run:
    kind = open(os.path.join(S, "kind")).read().strip() if os.path.exists(os.path.join(S, "kind")) else ""
    last = {"at": int(time.time()), "kind": kind, "scanned": scanned, "found": len(found)}
    prev = None
    try: prev = json.load(open(os.path.join(S, "last.json")))
    except Exception: pass
    if not prev or prev.get("logtime") != os.path.getmtime(log):
        last["logtime"] = os.path.getmtime(log); json.dump(last, open(os.path.join(S, "last.json"), "w"))
print(json.dumps(st))
PY
  ;;

quarantine)
  # move every file the last scan found into the locked quarantine folder
  mkdir -p "$Q"; chmod 700 "$Q"; n=0
  grep ' FOUND$' "$LOG" 2>/dev/null | sed 's/: [^:]* FOUND$//' | while IFS= read -r f; do
    [ -f "$f" ] || continue
    d="$Q/$(date +%Y%m%d-%H%M%S)-$(basename "$f")"
    mv -f "$f" "$d" 2>/dev/null && chmod 000 "$d" && echo "OK Locked away: $(basename "$f")"
  done
  sed -i 's/ FOUND$/ QUARANTINED/' "$LOG" ;;

daily-on)
  systemctl --user enable --now monster-shield-scan.timer >/dev/null 2>&1 && ok "Downloads checked every day" || fail "Daily check not turned on" ;;
daily-off)
  systemctl --user disable --now monster-shield-scan.timer >/dev/null 2>&1; ok "Daily check is off" ;;
open-quarantine)
  mkdir -p "$Q"; xdg-open "$Q" >/dev/null 2>&1 & ;;
esac
exit 0
