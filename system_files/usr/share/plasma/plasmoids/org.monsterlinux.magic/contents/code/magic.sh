#!/bin/bash
# Monster Magic helper. Every button = one command here; every fix = "fix <id>".
# Lines the app understands:
#   STEP <text>               detail of what was checked (shown under "Details")
#   OK <text>                 green: fine
#   WARN <text>               amber: works, but worth fixing
#   FAIL <text>               red: needs fixing
#   FIX <id>|<button>|<what>  a one-click fix for the WARN/FAIL line just above it
#   TIP <text>                recommended step the user does themselves (no automatic fix)
#   PROOF <text>              the summary shown big at the top
#   PLAN <text>               (plan mode) what the button will do
# Root changes go through pkexec (the normal password box).

cmd="$1"; shift
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/monster-magic"; mkdir -p "$STATE"
say() { echo "$*"; }
human() { numfmt --to=iec --suffix=B "$1" 2>/dev/null || echo "${1} bytes"; }
freebytes() { df --output=avail -B1 "$HOME" | tail -1 | tr -d ' '; }
Q=$(command -v qdbus6 || command -v qdbus-qt6 || command -v qdbus || true)
term() {  # run something interactive in a terminal window
  if command -v konsole >/dev/null; then konsole --hold -e bash -lc "$1" >/dev/null 2>&1 & disown
  else xdg-terminal-exec bash -lc "$1; read -rp 'Press Enter to close'" >/dev/null 2>&1 & disown; fi
}

plan() {
  case "$1" in
    windows) say "PLAN Look in the folder you pick for Desktop, Documents, Pictures, Music, Videos and Downloads"
             say "PLAN Copy them into your matching folders, inside a 'From Windows' folder (nothing is overwritten)"
             say "PLAN Count the files before and after to prove it" ;;
    game) say "PLAN Check the graphics driver, Vulkan, Steam, Proton-GE, GameMode, power mode and free space"
          say "PLAN Give a one-click fix for anything amber or red" ;;
    yesterday) say "PLAN Compare the system you're running with the previous working one and show what changed"
               say "PLAN Offer one button to start the previous system next time (your files are not touched)" ;;
    looking) say "PLAN You click the window that's misbehaving"
             say "PLAN Check whether it's frozen, how much memory it uses and where its settings live"
             say "PLAN Offer fixes: restart it, repair it, or reset its settings (a backup is kept)" ;;
    openfile) say "PLAN Find out what kind of file it is; if no app can open it, install the right free app; open it" ;;
    plug) say "PLAN Check sound, microphone, Bluetooth, USB, cameras, controllers and printers, and play a test sound"
          say "PLAN Give a one-click fix for anything that isn't working" ;;
    fast) say "PLAN Measure how long your PC takes to start and find what slows it down"
          say "PLAN Offer fixes; after a restart, press again to see the new time" ;;
    space) say "PLAN Measure free space, then remove only things that come back by themselves"
           say "PLAN Point out big folders and the Trash, and measure again to prove it" ;;
    safe) say "PLAN Check firewall, home/public setting, updates, Secure Boot, SELinux, open network doors, virus check and Quarantine"
          say "PLAN Give a one-click fix for anything amber or red" ;;
    drive) say "PLAN Read each drive's health report, run TRIM, make sure weekly TRIM is on, look for firmware updates" ;;
  esac
}

case "$cmd" in
plan) plan "$1" ;;
last-get) cat "$STATE/last.json" 2>/dev/null || echo '{}' ;;
last-set) python3 - "$STATE/last.json" "$1" "$2" <<'PY'
import json, sys
p, k, v = sys.argv[1:4]
try: d = json.load(open(p))
except Exception: d = {}
d[k] = v; json.dump(d, open(p, "w"))  # v = "tone|short label"
PY
  ;;

# ---------------------------------------------------------------------------- 1
windows)
  src="$1"
  [ -d "$src" ] || { say "FAIL That folder can't be opened"; say "TIP Press the button again and pick the Windows user folder (Windows drive → Users → your name)"; exit 0; }
  found=0; before=$(find "$HOME" -xdev -type f 2>/dev/null | wc -l)
  for pair in "Desktop:Desktop" "Documents:Documents" "My Documents:Documents" "Pictures:Pictures" "Music:Music" "Videos:Videos" "Downloads:Downloads"; do
    from="${pair%%:*}"; to="${pair##*:}"
    for d in "$src/$from" "$src"/*/"$from"; do
      [ -d "$d" ] || continue
      n=$(find "$d" -type f 2>/dev/null | wc -l); [ "$n" -gt 0 ] || continue
      dest="$HOME/$to/From Windows"; mkdir -p "$dest"
      cp -rn --preserve=timestamps "$d"/. "$dest"/ 2>/dev/null
      say "OK $from: $n files → $to/From Windows"; found=$((found+n))
    done
  done
  after=$(find "$HOME" -xdev -type f 2>/dev/null | wc -l)
  if [ "$found" -eq 0 ]; then say "FAIL No Desktop, Documents, Pictures, Music, Videos or Downloads folders in that folder"
    say "TIP Pick the Windows user folder: Windows drive → Users → your name"
  elif [ "$after" -eq "$before" ]; then say "PROOF All $found files were already here: nothing missing"
  else say "PROOF $((after-before)) new files copied (your home had $before files, now $after)"; fi ;;

# ---------------------------------------------------------------------------- 2
game)
  if command -v nvidia-smi >/dev/null && nvidia-smi -L >/dev/null 2>&1; then
    say "OK Graphics driver: $(nvidia-smi --query-gpu=name,driver_version --format=csv,noheader 2>/dev/null | head -1)"
  elif lspci 2>/dev/null | grep -qiE 'vga.*nvidia|3d.*nvidia'; then
    say "FAIL NVIDIA card found, but its driver isn't running"
    say "TIP Restart once. If it stays red, make sure you use the NVIDIA version of Monster Linux"
  else say "OK Graphics: $(lspci 2>/dev/null | grep -iE 'vga|3d' | head -1 | sed 's/.*: //')"; fi
  if command -v vulkaninfo >/dev/null; then
    vulkaninfo --summary >/dev/null 2>&1 && say "OK Vulkan works (games and Proton need it)" || { say "FAIL Vulkan isn't working"; say "TIP Restart the PC; if it stays red, the graphics driver needs a reinstall (press Update in Monster Updater)"; }
  fi
  if command -v steam >/dev/null || flatpak info com.valvesoftware.Steam >/dev/null 2>&1; then say "OK Steam is installed"
  else say "WARN Steam isn't installed"; say "FIX steam|Install Steam|Installs Steam from Flathub"; fi
  ge=$(ls -d "$HOME"/.steam/steam/compatibilitytools.d/GE-Proton* "$HOME"/.local/share/Steam/compatibilitytools.d/GE-Proton* "$HOME"/.var/app/com.valvesoftware.Steam/data/Steam/compatibilitytools.d/GE-Proton* 2>/dev/null | sort -V | tail -1)
  if [ -n "$ge" ]; then say "OK Proton-GE: $(basename "$ge")"
  else say "WARN Proton-GE isn't installed (it fixes many games that won't start)"
       say "FIX protonplus|Get Proton-GE|Installs ProtonPlus and opens it so you can add Proton-GE in one click"; fi
  if command -v gamemoded >/dev/null; then say "OK GameMode is available"; else say "STEP GameMode not found (optional)"; fi
  if command -v powerprofilesctl >/dev/null; then
    pp=$(powerprofilesctl get 2>/dev/null)
    if [ "$pp" = performance ]; then say "OK Power mode: Performance"
    else say "WARN Power mode is ${pp:-unknown}: games run best on Performance"; say "FIX perf|Use Performance|Switches the power mode to Performance"; fi
  fi
  lib="$HOME/.local/share/Steam"; [ -d "$lib" ] || lib="$HOME"
  fb=$(df --output=avail -B1 "$lib" | tail -1 | tr -d ' ')
  if [ "$fb" -lt $((50*1024*1024*1024)) ]; then say "WARN Only $(human "$fb") free for games"; say "FIX space|Free up space|Runs Free Up Space Safely"
  else say "OK $(human "$fb") free for games"; fi
  say "TIP Game still won't start? In Steam: right-click it → Properties → Compatibility → tick 'Force…' and pick GE-Proton"
  say "PROOF Game check done" ;;

# ---------------------------------------------------------------------------- 3
yesterday)
  st=$(rpm-ostree status --json 2>/dev/null)
  [ -n "$st" ] || { say "FAIL Couldn't read the system history"; exit 0; }
  n=$(echo "$st" | grep -c '"checksum"')
  diff=$(rpm-ostree db diff 2>/dev/null | grep -E '^(Upgraded|Downgraded|Removed|Added):|^  ' | head -40)
  if [ -z "$diff" ]; then say "OK No system changes between this start-up and the previous one"
  else say "WARN The system changed since the previous start-up"; echo "$diff" | sed 's/^/STEP /'
       say "FIX yesterday-go|Go back|Starts the previous working system next time (your files are not touched)"; fi
  say "PROOF ${n} system versions saved" ;;

# ---------------------------------------------------------------------------- 4
looking)
  [ -n "$Q" ] || { say "FAIL Can't ask the desktop which window you clicked"; exit 0; }
  info=$($Q org.kde.KWin /KWin org.kde.KWin.queryWindowInfo 2>/dev/null)
  [ -n "$info" ] || { say "FAIL No window was picked"; say "TIP Press the button again, then click the window that's misbehaving"; exit 0; }
  get() { echo "$info" | sed -n "s/^$1: //p" | head -1; }
  cls=$(get resourceClass); cap=$(get caption); desk=$(get desktopFile); pid=$(get pid)
  [ -n "$desk" ] || desk="$cls"
  printf 'CLS=%q\nDESK=%q\nPID=%q\nCAP=%q\n' "$cls" "$desk" "$pid" "$cap" > "$STATE/looking.env"
  say "OK You picked: ${cap:-$cls} (${desk})"
  if [ -n "$pid" ] && [ -d "/proc/$pid" ]; then
    s=$(awk '/^State:/{print $2}' /proc/$pid/status 2>/dev/null)
    mem=$(awk '/VmRSS/{print $2}' /proc/$pid/status 2>/dev/null)
    [ -n "$mem" ] && { m=$((mem/1024)); [ $m -gt 4000 ] && { say "WARN It's using a lot of memory: ${m} MB"; say "FIX restart-app|Restart it|Closes it and opens it again"; } || say "OK Memory: ${m} MB"; }
    if [ "$s" = D ] || [ "$s" = T ]; then say "FAIL It looks frozen"; say "FIX restart-app|Restart it|Closes it and opens it again"; else say "OK It's responding"; fi
  fi
  if flatpak info "$desk" >/dev/null 2>&1 || flatpak info "${desk%.desktop}" >/dev/null 2>&1; then
    say "WARN It's a Flatpak app: if it acts up, a repair often helps"; say "FIX repair-app|Repair it|Checks the app's files and updates it"
  fi
  say "WARN Still acting up? Its settings may be broken"; say "FIX reset-app|Reset its settings|Moves its settings to a backup folder and restarts it fresh"
  say "PROOF Pick a fix below" ;;

# ---------------------------------------------------------------------------- 5
openfile)
  f="$1"; [ -f "$f" ] || { say "FAIL That file can't be found"; exit 0; }
  mime=$(xdg-mime query filetype "$f" 2>/dev/null); ext="${f##*.}"; ext="${ext,,}"
  say "STEP File type: ${mime:-unknown} (.$ext)"
  app=$(xdg-mime query default "$mime" 2>/dev/null)
  if [ -z "$app" ]; then
    case "$ext" in
      doc|docx|xls|xlsx|ppt|pptx|odt|ods|odp|rtf|csv) id=org.libreoffice.LibreOffice ;;
      psd|xcf|tif|tiff|heic|raw|cr2|nef) id=org.gimp.GIMP ;;
      mp4|mkv|avi|mov|wmv|flv|webm|mp3|wav|flac|m4a|wma|ogg) id=org.videolan.VLC ;;
      exe|msi|bat) id=com.usebottles.bottles ;;
      pdf) id=org.kde.okular ;;
      epub|mobi) id=com.github.johnfactotum.Foliate ;;
      zip|rar|7z|tar|gz|xz|iso) id=org.kde.ark ;;
      svg|ai|eps) id=org.inkscape.Inkscape ;;
      *) id="" ;;
    esac
    [ -n "$id" ] || { say "FAIL No app known for .$ext files yet"; say "TIP Search for '.$ext' in Bazaar, the app store"; exit 0; }
    if flatpak install -y --noninteractive flathub "$id" >/dev/null 2>&1; then say "OK Installed $id"
    else say "FAIL Couldn't install $id"; say "FIX network|Fix the internet|Runs the network repair"; exit 0; fi
    if [ "$id" = com.usebottles.bottles ]; then
      flatpak run com.usebottles.bottles >/dev/null 2>&1 & disown
      say "PROOF Bottles is open: make a Bottle, then press Run Executable and pick this file"; exit 0
    fi
    flatpak run --file-forwarding "$id" @@ "$f" @@ >/dev/null 2>&1 & disown
  else say "OK Opens with $app"; xdg-open "$f" >/dev/null 2>&1 & disown; fi
  say "PROOF Your file is opening now" ;;

# ---------------------------------------------------------------------------- 6
plug)
  if [ -n "$(pactl list short sinks 2>/dev/null)" ]; then
    say "OK Sound out: $(pactl get-default-sink 2>/dev/null)"
    snd=/usr/share/sounds/freedesktop/stereo/complete.oga; [ -f "$snd" ] || snd=$(ls /usr/share/sounds/*/stereo/*.oga 2>/dev/null | head -1)
    [ -n "$snd" ] && (pw-play "$snd" || paplay "$snd") >/dev/null 2>&1 && say "OK Test sound played (did you hear the chime?)"
    if pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null | grep -q yes; then say "WARN Sound is muted"; say "FIX unmute|Unmute|Turns the sound back on at 50%"; fi
  else say "FAIL No sound output found"; say "FIX sound|Restart sound|Restarts the sound system"; fi
  mic=$(pactl get-default-source 2>/dev/null); [ -n "$mic" ] && say "OK Microphone: $mic" || say "STEP No microphone found"
  if command -v bluetoothctl >/dev/null && [ -n "$(bluetoothctl list 2>/dev/null)" ]; then
    if bluetoothctl show 2>/dev/null | grep -q "Powered: yes"; then
      bt=$(bluetoothctl devices Connected 2>/dev/null | cut -d' ' -f3-)
      [ -n "$bt" ] && echo "$bt" | sed 's/^/OK Bluetooth: /' || say "OK Bluetooth is on (nothing connected)"
    else say "WARN Bluetooth is off"; say "FIX bluetooth|Turn Bluetooth on|Unblocks and powers on Bluetooth (restarts it if it's stuck)"; fi
  fi
  usb=$(lsusb 2>/dev/null | grep -viE 'root hub|hub$' | sed -E 's/^Bus [0-9]+ Device [0-9]+: ID [0-9a-f:]+ //' | head -10)
  [ -n "$usb" ] && echo "$usb" | sed 's/^/STEP USB: /'
  cams=$(ls /dev/video* 2>/dev/null | wc -l); [ "$cams" -gt 0 ] && say "OK Camera found" || say "STEP No camera plugged in"
  pads=$(ls /dev/input/js* 2>/dev/null | wc -l); [ "$pads" -gt 0 ] && say "OK Game controller found ($pads)" || say "STEP No game controller plugged in"
  pr=$(lpstat -p 2>/dev/null | awk '{print $2}')
  if [ -n "$pr" ]; then echo "$pr" | sed 's/^/OK Printer: /'
  else say "STEP No printer set up"; say "TIP Have a printer? Turn it on, then press Add a printer"; say "FIX printers|Add a printer|Opens the printer page"; fi
  say "PROOF Device check done" ;;

# ---------------------------------------------------------------------------- 7
fast)
  t=$(systemd-analyze 2>/dev/null | head -1)
  total=$(echo "$t" | grep -oE '= [0-9.]+(min [0-9.]+s|s)' | head -1 | tr -d '= ')
  [ -n "$total" ] || { say "FAIL Couldn't measure start-up time"; exit 0; }
  secs=$(echo "$total" | awk '{ if ($0 ~ /min/) { split($0,a,"min"); print a[1]*60 + a[2]+0 } else print $0+0 }')
  say "STEP $t"
  systemd-analyze blame 2>/dev/null | head -5 | sed -E 's/^ +//; s/^/STEP slow: /'
  prev=$(cat "$STATE/boot-before" 2>/dev/null); echo "$total" > "$STATE/boot-before"
  [ -n "$prev" ] && [ "$prev" != "$total" ] && say "OK Last time: $prev → now: $total"
  if systemctl is-enabled -q NetworkManager-wait-online.service 2>/dev/null; then
    say "WARN Start-up waits for the network"; say "FIX fast|Don't wait for the network|Turns off the wait and hides the boot menu (password asked)"
  else say "OK Start-up doesn't wait for the network"; fi
  fw=$(echo "$t" | grep -oE '[0-9.]+s \(firmware\)' | grep -oE '^[0-9.]+')
  if [ -n "$fw" ] && [ "${fw%.*}" -ge 15 ] 2>/dev/null; then
    say "WARN The PC's own start-up (BIOS) takes ${fw}s before Linux begins"
    say "TIP In the BIOS (press Del while starting), turn on Fast Boot"
  fi
  if [ "${secs%.*}" -ge 45 ] 2>/dev/null; then say "PROOF Start-up takes $total"; else say "PROOF Start-up takes $total: that's quick"; fi ;;

# ---------------------------------------------------------------------------- 8
space)
  b=$(freebytes)
  say "STEP Free space before: $(human "$b")"
  flatpak uninstall --user --unused -y --noninteractive >/dev/null 2>&1 && say "OK Removed unused app parts (yours)"
  rm -rf "$HOME/.cache/thumbnails" 2>/dev/null && say "OK Cleared picture previews (they rebuild by themselves)"
  r=$(pkexec /usr/libexec/monster-root clean 2>/dev/null)
  [ -n "$r" ] && echo "$r" || { say "WARN Skipped the system part|The clean-up helper didn't answer"; say "FIX space|Try again|Runs the system clean-up again"; }
  a=$(freebytes); d=$((a-b)); [ "$d" -lt 0 ] && d=0
  tr=$(du -sb "$HOME/.local/share/Trash" 2>/dev/null | cut -f1); tr=${tr:-0}
  [ "$tr" -gt $((500*1024*1024)) ] && { say "WARN The Trash holds $(human "$tr")"; say "FIX empty-trash|Empty the Trash|Deletes what's in the Trash for good"; }
  dl=$(du -sb "$HOME/Downloads" 2>/dev/null | cut -f1); dl=${dl:-0}
  [ "$dl" -gt $((5*1024*1024*1024)) ] && { say "WARN Downloads holds $(human "$dl")"; say "TIP Look through Downloads and delete what you don't need"; say "FIX open-downloads|Open Downloads|Opens the folder, biggest files first"; }
  tot=$(df --output=size -B1 "$HOME" | tail -1 | tr -d ' ')
  [ "$a" -lt $((tot/10)) ] && { say "WARN Less than 10% of the drive is free"; say "TIP Move videos and old games to another drive, or uninstall games you finished"; }
  say "PROOF Freed $(human "$d") · free space now $(human "$a")" ;;

# ---------------------------------------------------------------------------- 9
safe)
  SHIELD=/usr/share/plasma/plasmoids/org.monsterlinux.shield/contents/code/shield.sh
  if systemctl is-active --quiet firewalld; then
    say "OK Firewall is on|Blocks other computers from connecting to yours"
    z=$(firewall-cmd --get-default-zone 2>/dev/null)
    case "$z" in monster-home) say "OK Firewall place: Home|Your phone, printer and other PCs can find this PC; nothing else can";;
                 monster-public) say "OK Firewall place: Public|Nothing on the network can connect to this PC";;
      *) say "WARN Firewall isn't set to Home or Public yet|Without a place it uses Bazzite's looser default"; say "FIX fw-home|Set to Home|Uses the Home setting (best for home). No password needed";; esac
  else say "FAIL Firewall is off|Other computers on your network could try to connect to yours"; say "FIX fw-home|Turn firewall on|Turns it on with the Home setting. No password needed"; fi
  up=$(rpm-ostree upgrade --check 2>/dev/null | grep -iE 'AvailableUpdate|Version:' | head -1)
  if [ -n "$up" ]; then say "WARN A system update is waiting|Updates close security holes"; say "FIX update|Update now|Opens Monster Updater and starts the update"
  else say "OK System is up to date|You have the newest Monster Linux"; fi
  sb=$(mokutil --sb-state 2>/dev/null | head -1)
  case "$sb" in *enabled*) say "OK Secure Boot is on|Stops hidden malware that loads before Linux starts";;
    *) say "WARN Secure Boot is off|Secure Boot stops hidden malware that loads before Linux starts"
       say "TIP Press Set up Secure Boot, restart, choose 'Enroll MOK' (password: universalblue), then turn Secure Boot on in the BIOS"
       say "FIX secureboot|Set up Secure Boot|Prepares the key the BIOS needs (opens a terminal; asks for your password)";; esac
  se=$(getenforce 2>/dev/null)
  if [ "$se" = Enforcing ]; then say "OK SELinux protection is on|Keeps each program inside its own fence"
  else say "WARN SELinux protection is ${se:-unknown}|SELinux keeps each program inside its own fence"; say "FIX selinux|Turn SELinux on|Switches it to Enforcing (asks for your password: it's a big change)"; fi
  ports=$(ss -tulnH 2>/dev/null | awk '{print $5}' | grep -vE '^(127\.|\[::1\]|::1|\[::ffff:127)' | grep -vE '%lo' | sed -E 's/.*://' | sort -un | tr '\n' ' ')
  z=$(firewall-cmd --get-default-zone 2>/dev/null)
  if [ -z "$ports" ]; then say "OK No network doors open|No program is waiting for connections from other computers"
  elif [ "$z" = monster-public ]; then say "OK The firewall keeps network doors closed|Programs listen on: $ports, but Public blocks them"
  else say "STEP Network doors open: $ports"; say "WARN Some programs accept connections from your network|Open doors: $ports"
       say "FIX fw-public|Close them (Public)|Switches the firewall to Public: nothing can connect in. No password needed"; fi
  if command -v clamscan >/dev/null; then
    last=$(python3 -c 'import json,sys
t=0
for f in sys.argv[1:]:
  try: t=max(t,int(json.load(open(f)).get("at",0)))
  except Exception: pass
print(t)' "$HOME/.local/share/monster-shield/last.json" "$HOME/.local/share/monster-shield/daily.json" "$HOME/.local/share/monster-shield/last-run.json")
    if [ "$(( $(date +%s) - ${last:-0} ))" -lt $((7*86400)) ]; then say "OK Virus check ran $(( ($(date +%s) - last) / 86400 )) day(s) ago|Monster Shield's scans and the daily Downloads check both count"
    else say "WARN No virus check in the last 7 days|A quick check looks at Downloads, Desktop and Documents"; say "FIX virus|Check now|Runs a Quick virus check right here (1-5 minutes). No password needed"; fi
  fi
  [ -d "$HOME/Quarantine" ] && say "OK Quarantine folder ready|Where suspicious files are locked away" || { say "WARN Quarantine folder not set up|Suspicious downloads get locked away there"; say "FIX quarantine|Make it|Creates the locked Quarantine folder"; }
  say "PROOF Safety check done" ;;

# ---------------------------------------------------------------------------- 11
drive)
  command -v smartctl >/dev/null || say "WARN The drive health tool (smartctl) is missing"
  out=$(pkexec /usr/libexec/monster-root drive-check 2>/dev/null)
  if [ -z "$out" ]; then say "WARN Couldn't read the drives|The drive check helper didn't answer"; say "FIX drive|Try again|Runs the drive check again"
  else
    model=""; used=""; temp=""
    flush() {
      [ -n "$model" ] || return
      [ -n "$used" ] && { n=${used%\%}; if [ "$n" -ge 80 ] 2>/dev/null; then say "FAIL $model: ${used} of its life used|SSDs wear out slowly; at 80% plan a replacement"; say "TIP Back up and plan to replace this drive"
        elif [ "$n" -ge 50 ] 2>/dev/null; then say "WARN $model: ${used} of its life used|Still fine, but keep backups up to date"; else say "OK $model: ${used:-0%} of its life used|An SSD lasts until about 100%"; fi; }
      [ -n "$temp" ] && { if [ "$temp" -ge 70 ] 2>/dev/null; then say "WARN $model runs hot (${temp} °C)|Over 70 °C an SSD slows itself down"; say "TIP Add a heatsink or more case airflow"
        else say "OK $model temperature: ${temp} °C|Under 70 °C is healthy"; fi; }
      model=""; used=""; temp=""
    }
    while IFS= read -r l; do
      case "$l" in
        "DRIVE "*) flush; model=${l#DRIVE } ;;
        "HEALTH "*) h=${l#HEALTH }; case "$h" in PASSED|OK) say "OK $model: health $h|The drive's own self-test says it's healthy";; *) say "FAIL $model: health $h|The drive itself reports a problem"; say "TIP Back up your files now";; esac ;;
        "ATTR Percentage Used"*) used=$(echo "$l" | awk -F: '{gsub(/ /,"",$2);print $2}') ;;
        "ATTR Temperature:"*) temp=$(echo "$l" | awk -F: '{gsub(/[^0-9]/,"",$2);print $2}') ;;
        *Reallocated_Sector_Ct*) r=$(echo "$l" | awk '{print $NF}'); [ "$r" -gt 0 ] 2>/dev/null && { say "FAIL $model: $r bad sectors|Bad sectors mean the disk is wearing out"; say "TIP Back up your files now"; } ;;
        "TRIMTIMER on") say "OK Weekly TRIM is on|Keeps SSDs fast by clearing deleted space" ;;
        "TRIM "*) say "STEP ${l#TRIM }" ;;
      esac
    done <<< "$out"
    flush
  fi
  if command -v fwupdmgr >/dev/null; then
    fwupdmgr refresh >/dev/null 2>&1
    list=$(fwupdmgr get-updates --json 2>/dev/null | python3 -c 'import sys,json
try: d=json.load(sys.stdin)
except Exception: sys.exit(0)
for dev in d.get("Devices",[]):
  for r in dev.get("Releases",[])[:1]:
    print("%s|%s → %s · %s" % (dev.get("Name","?"), dev.get("Version","?"), r.get("Version","?"), (r.get("Summary") or "").strip()))' 2>/dev/null)
    if [ -n "$list" ]; then
      n=$(echo "$list" | wc -l)
      say "WARN $n firmware update(s) available: $(echo "$list" | cut -d'|' -f1 | paste -sd, | sed 's/,/, /g')|Firmware is the built-in software of your BIOS, drives and devices"
      say "FIX drive-firmware|Install firmware|Opens a window that installs them; asks for your password, then restart"
      echo "$list" | while IFS='|' read -r name rest; do say "STEP Firmware for $name: $rest"; say "OK Update ready for $name|$rest"; done
    else say "OK Firmware is up to date|The built-in software of your BIOS, drives and devices"; fi
  fi
  say "PROOF Drive check done" ;;

# =========================================================================== FIXES
fix)
  id="$1"
  case "$id" in
    yesterday-go) pkexec rpm-ostree rollback >/dev/null 2>&1 && say "OK The previous system will start next time: restart to finish" || say "FAIL Going back was cancelled or didn't work" ;;
    steam) flatpak install -y --noninteractive flathub com.valvesoftware.Steam >/dev/null 2>&1 && say "OK Steam installed" || say "FAIL Couldn't install Steam (check the internet)" ;;
    protonplus) flatpak info com.vysp3r.ProtonPlus >/dev/null 2>&1 || flatpak install -y --noninteractive flathub com.vysp3r.ProtonPlus >/dev/null 2>&1
                if flatpak info com.vysp3r.ProtonPlus >/dev/null 2>&1; then flatpak run com.vysp3r.ProtonPlus >/dev/null 2>&1 & disown; say "OK ProtonPlus is open: pick Steam → GE-Proton → Install, then restart Steam"
                else say "FAIL Couldn't install ProtonPlus (check the internet)"; fi ;;
    perf) powerprofilesctl set performance 2>/dev/null && say "OK Power mode: Performance" || say "FAIL Couldn't change the power mode" ;;
    space) exec bash "$0" space ;;
    restart-app|reset-app|repair-app)
      . "$STATE/looking.env" 2>/dev/null || { say "FAIL Press Fix What I'm Looking At first"; exit 0; }
      app="${DESK%.desktop}"
      if [ "$id" = repair-app ]; then
        flatpak repair --user >/dev/null 2>&1; flatpak update -y --noninteractive "$app" >/dev/null 2>&1 && say "OK $app repaired and up to date" || say "OK $app repaired"
      fi
      if [ "$id" = reset-app ]; then
        bk="$HOME/Monster Backups/$(date +%Y%m%d-%H%M)-$app"; mkdir -p "$bk"; moved=0
        low=$(echo "$CLS" | tr 'A-Z' 'a-z'); short="${app##*.}"; short=$(echo "$short" | tr 'A-Z' 'a-z')
        for p in "$HOME/.config/${low}rc" "$HOME/.config/${short}rc" "$HOME/.config/$low" "$HOME/.config/$short" "$HOME/.local/share/$low" "$HOME/.var/app/$app/config"; do
          [ -e "$p" ] && mv "$p" "$bk/" && moved=$((moved+1))
        done
        [ "$moved" -gt 0 ] && say "OK Settings moved to Monster Backups (put them back by moving them home)" || { rmdir "$bk" 2>/dev/null; say "WARN No saved settings found for this app"; }
      fi
      [ -n "$PID" ] && kill "$PID" 2>/dev/null && sleep 2; [ -n "$PID" ] && kill -9 "$PID" 2>/dev/null
      (gtk-launch "$DESK" || gtk-launch "$app" || flatpak run "$app") >/dev/null 2>&1 & disown
      say "OK Restarted ${CAP:-$app}" ;;
    network) [ -x /usr/bin/monster-netfix ] && pkexec /usr/bin/monster-netfix >/dev/null 2>&1; nm-online -q -t 15 && say "OK Internet is back" || say "FAIL Still no internet: check the cable or Wi-Fi" ;;
    unmute) pactl set-sink-mute @DEFAULT_SINK@ 0 && pactl set-sink-volume @DEFAULT_SINK@ 50% && say "OK Sound on at 50%" || say "FAIL Couldn't unmute" ;;
    sound) systemctl --user restart pipewire pipewire-pulse wireplumber 2>/dev/null; sleep 2
           [ -n "$(pactl list short sinks 2>/dev/null)" ] && say "OK Sound is back: $(pactl get-default-sink)" || { say "FAIL Still no sound output"; say "TIP Check the cable or pick the output in the sound icon on the taskbar"; } ;;
    bluetooth) rfkill unblock bluetooth 2>/dev/null
               if ! bluetoothctl power on 2>/dev/null | grep -q succeeded; then pkexec /usr/libexec/monster-root bt-restart >/dev/null 2>&1; sleep 2; bluetoothctl power on >/dev/null 2>&1; fi
               bluetoothctl show 2>/dev/null | grep -q "Powered: yes" && say "OK Bluetooth is on" || say "FAIL Bluetooth is still off: restart the PC" ;;
    printers) (systemsettings kcm_printer_manager || system-config-printer) >/dev/null 2>&1 & disown; say "OK Printer page opened: press Add Printer" ;;
    fast) pkexec /usr/libexec/monster-root boot-fast; say "TIP Restart, then press Start Fast again to see the new time" ;;
    empty-trash) rm -rf "$HOME/.local/share/Trash/files/"* "$HOME/.local/share/Trash/info/"* 2>/dev/null; say "OK Trash emptied" ;;
    open-downloads) dolphin --new-window "$HOME/Downloads" >/dev/null 2>&1 & disown; say "OK Downloads opened (sort by size: View → Sort By → Size)" ;;
    fw-home|fw-public)
      S=/usr/share/plasma/plasmoids/org.monsterlinux.shield/contents/code/shield.sh
      if [ -x "$S" ]; then bash "$S" fw-zone "${id#fw-}" | sed 's/^OK /OK /'
      else pkexec systemctl enable --now firewalld >/dev/null 2>&1 && say "OK Firewall is on" || say "FAIL Firewall not changed"; fi ;;
    update) (plasmawindowed org.monsterlinux.updater) >/dev/null 2>&1 & disown; say "OK Monster Updater opened: press Update now" ;;
    secureboot) term "ujust enroll-secure-boot-key"; say "OK Follow the steps in the terminal, then restart and choose 'Enroll MOK'" ;;
    selinux) pkexec bash -c 'setenforce 1; sed -i "s/^SELINUX=.*/SELINUX=enforcing/" /etc/selinux/config' >/dev/null 2>&1 && say "OK SELinux protection is on" || say "FAIL Cancelled: nothing was changed" ;;
    virus)
      SH=/usr/share/plasma/plasmoids/org.monsterlinux.shield/contents/code/shield.sh
      command -v clamscan >/dev/null || { say "FAIL The virus check isn't installed"; exit 0; }
      db=$(ls /var/lib/clamav/daily.c?d 2>/dev/null | head -1)
      if [ -z "$db" ] || [ $(( $(date +%s) - $(stat -c %Y "$db") )) -gt $((8*86400)) ]; then bash "$SH" update-db >/dev/null 2>&1; fi
      bash "$SH" scan quick >/dev/null 2>&1
      for i in $(seq 1 900); do st=$(bash "$SH" scan-status 2>/dev/null); echo "$st" | grep -q '"done": null' || break; sleep 2; done
      n=$(echo "$st" | python3 -c 'import json,sys
try: d=json.load(sys.stdin); print(len(d.get("found",[])), d.get("scanned",0))
except Exception: print("? 0")')
      set -- $n
      if [ "$1" = 0 ]; then say "OK Quick virus check done: no viruses in $2 files"
      else say "FAIL Found $1 bad file(s)"; say "TIP Open Monster Shield and press Lock them away"; fi ;;
    quarantine) mkdir -p "$HOME/Quarantine" && chmod 700 "$HOME/Quarantine" && say "OK Quarantine folder made (only you can open it)" ;;
    drive) exec bash "$0" drive ;;
    drive-firmware) term "echo 'Installing firmware updates. Your password will be asked.'; echo; fwupdmgr update; echo; echo 'If it says a restart is needed, restart your PC to finish.'"
                    say "OK Firmware installer opened in a window|Follow it there; restart afterwards if it says so" ;;
    *) say "FAIL Unknown fix" ;;
  esac ;;

*) say "FAIL Unknown button" ;;
esac
exit 0
