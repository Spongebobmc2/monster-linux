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
  if pkexec bash -c 'flatpak uninstall --system --unused -y --noninteractive >/dev/null 2>&1; journalctl --vacuum-time=14d >/dev/null 2>&1; rpm-ostree cleanup -m >/dev/null 2>&1; true'; then
    say "OK Removed unused shared app parts, logs older than 2 weeks and update caches"
  else say "WARN Skipped the system part (password box was cancelled)"; say "FIX space|Try again|Runs the system clean-up again"; fi
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
  if systemctl is-active --quiet firewalld; then
    say "OK Firewall is on"
    z=$(firewall-cmd --get-default-zone 2>/dev/null)
    case "$z" in monster-home|monster-public) say "OK Firewall place: ${z#monster-}";;
      *) say "WARN Firewall isn't set to Home or Public yet"; say "FIX fw-home|Set to Home|Uses the Home setting (best for home)";; esac
  else say "FAIL Firewall is off"; say "FIX fw-home|Turn firewall on|Turns it on with the Home setting"; fi
  up=$(rpm-ostree upgrade --check 2>/dev/null | grep -iE 'AvailableUpdate|Version:' | head -1)
  if [ -n "$up" ]; then say "WARN A system update is waiting"; say "FIX update|Update now|Opens Monster Updater and starts the update"; else say "OK System is up to date"; fi
  sb=$(mokutil --sb-state 2>/dev/null | head -1)
  case "$sb" in *enabled*) say "OK Secure Boot is on";;
    *) say "WARN Secure Boot is off"; say "TIP Secure Boot blocks hidden start-up malware. Press Set up Secure Boot, restart, choose 'Enroll MOK' (password: universalblue), then turn Secure Boot on in the BIOS"
       say "FIX secureboot|Set up Secure Boot|Prepares the key the BIOS needs (opens a terminal)";; esac
  se=$(getenforce 2>/dev/null)
  if [ "$se" = Enforcing ]; then say "OK SELinux protection is on"
  else say "WARN SELinux protection is ${se:-unknown}"; say "FIX selinux|Turn SELinux on|Switches it to Enforcing now and after restarts"; fi
  ports=$(ss -tulnH 2>/dev/null | awk '{print $5}' | grep -vE '^(127\.|\[::1\]|::1|\[::ffff:127)' | grep -vE '%lo' | sed -E 's/.*://' | sort -un | tr '\n' ' ')
  if [ -z "$ports" ]; then say "OK No network doors open to other computers"
  else say "STEP Network doors open: $ports"
       z=$(firewall-cmd --get-default-zone 2>/dev/null)
       [ "$z" = monster-public ] && say "OK The firewall keeps those doors closed (Public)" || { say "WARN Some network doors are open to your network"; say "FIX fw-public|Close them (Public)|Switches the firewall to Public: nothing can connect in"; }; fi
  if command -v clamscan >/dev/null; then
    last=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get("at",0))' "$HOME/.local/share/monster-shield/last.json" 2>/dev/null || echo 0)
    if [ "$(( $(date +%s) - ${last:-0} ))" -lt $((7*86400)) ]; then say "OK Virus check ran this week"
    else say "WARN No virus check in the last 7 days"; say "FIX virus|Check now|Opens Monster Shield for a Quick check"; fi
  fi
  [ -d "$HOME/Quarantine" ] && say "OK Quarantine folder ready" || { say "WARN Quarantine folder not set up"; say "FIX quarantine|Make it|Creates the locked Quarantine folder"; }
  say "PROOF Safety check done" ;;

# ---------------------------------------------------------------------------- 11
drive)
  ROOTPART='
    for d in $(lsblk -dno NAME,TYPE | awk "\$2==\"disk\"{print \$1}" | grep -vE "^(zram|loop|sr)"); do
      dev=/dev/$d; model=$(lsblk -dno MODEL "$dev" | xargs); [ -n "$model" ] || model=$d
      h=$(smartctl -H "$dev" 2>/dev/null | grep -iE "overall-health|SMART Health Status" | sed "s/.*: *//" | xargs)
      case "$h" in PASSED|OK) echo "OK $model: health $h";; "") echo "STEP $model: no health report (USB drives often hide it)";; *) echo "FAIL $model: health $h"; echo "TIP Back up your files now and plan to replace this drive";; esac
      A=$(smartctl -A "$dev" 2>/dev/null)
      if [ "${d#nvme}" != "$d" ]; then
        used=$(echo "$A" | awk -F: "/Percentage Used/{gsub(/ /,\"\",\$2);print \$2}"); n=${used%\%}
        temp=$(echo "$A" | awk -F: "/^Temperature:/{gsub(/[^0-9]/,\"\",\$2);print \$2}")
        echo "STEP $model: wear used ${used:-?}, temperature ${temp:-?} C"
        if [ -n "$n" ] && [ "$n" -ge 80 ] 2>/dev/null; then echo "FAIL $model: ${used} of its life used"; echo "TIP Back up and plan a replacement"
        elif [ -n "$n" ] && [ "$n" -ge 50 ] 2>/dev/null; then echo "WARN $model: ${used} of its life used"; echo "TIP Keep backups up to date"; fi
        [ -n "$temp" ] && [ "$temp" -ge 70 ] 2>/dev/null && { echo "WARN $model runs hot (${temp} C)"; echo "TIP Add a heatsink or more case airflow"; }
      else
        realloc=$(echo "$A" | awk "/Reallocated_Sector_Ct/{print \$10}")
        [ -n "$realloc" ] && [ "$realloc" -gt 0 ] 2>/dev/null && { echo "FAIL $model: $realloc bad sectors"; echo "TIP Back up your files now"; }
      fi
    done
    systemctl enable --now fstrim.timer >/dev/null 2>&1 && echo "OK Weekly TRIM is on"
    fstrim -av 2>/dev/null | sed "s/^/STEP TRIM /"
    true'
  command -v smartctl >/dev/null || say "WARN The drive health tool (smartctl) is missing"
  if out=$(pkexec bash -c "$ROOTPART" 2>/dev/null); then echo "$out"
  else say "WARN Drive health and TRIM were skipped (password box cancelled)"; say "FIX drive|Try again|Runs the drive check again"; fi
  if command -v fwupdmgr >/dev/null; then
    fwupdmgr refresh >/dev/null 2>&1
    list=$(fwupdmgr get-updates --json 2>/dev/null | python3 -c 'import sys,json
try: d=json.load(sys.stdin)
except Exception: sys.exit(0)
for dev in d.get("Devices",[]):
  for r in dev.get("Releases",[])[:1]: print("%s: %s → %s" % (dev.get("Name","?"), dev.get("Version","?"), r.get("Version","?")))' 2>/dev/null)
    if [ -n "$list" ]; then say "WARN $(echo "$list" | wc -l) firmware update(s) available"; echo "$list" | sed 's/^/STEP /'
      say "FIX drive-firmware|Install firmware|Installs the firmware updates (restart afterwards)"
    else say "OK Firmware is up to date"; fi
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
               if ! bluetoothctl power on 2>/dev/null | grep -q succeeded; then pkexec systemctl restart bluetooth >/dev/null 2>&1; sleep 2; bluetoothctl power on >/dev/null 2>&1; fi
               bluetoothctl show 2>/dev/null | grep -q "Powered: yes" && say "OK Bluetooth is on" || say "FAIL Bluetooth is still off: restart the PC" ;;
    printers) (systemsettings kcm_printer_manager || system-config-printer) >/dev/null 2>&1 & disown; say "OK Printer page opened: press Add Printer" ;;
    fast) pkexec bash -c 'systemctl disable NetworkManager-wait-online.service >/dev/null 2>&1; grub2-editenv - set menu_auto_hide=1 >/dev/null 2>&1; true' \
            && say "OK Start-up no longer waits for the network; boot menu hidden (hold Shift to see it). Restart and press Start Fast again" || say "FAIL Cancelled: nothing was changed" ;;
    empty-trash) rm -rf "$HOME/.local/share/Trash/files/"* "$HOME/.local/share/Trash/info/"* 2>/dev/null; say "OK Trash emptied" ;;
    open-downloads) dolphin --new-window "$HOME/Downloads" >/dev/null 2>&1 & disown; say "OK Downloads opened (sort by size: View → Sort By → Size)" ;;
    fw-home|fw-public)
      S=/usr/share/plasma/plasmoids/org.monsterlinux.shield/contents/code/shield.sh
      if [ -x "$S" ]; then bash "$S" fw-zone "${id#fw-}" | sed 's/^OK /OK /'
      else pkexec systemctl enable --now firewalld >/dev/null 2>&1 && say "OK Firewall is on" || say "FAIL Firewall not changed"; fi ;;
    update) (plasmawindowed org.monsterlinux.updater) >/dev/null 2>&1 & disown; say "OK Monster Updater opened: press Update now" ;;
    secureboot) term "ujust enroll-secure-boot-key"; say "OK Follow the steps in the terminal, then restart and choose 'Enroll MOK'" ;;
    selinux) pkexec bash -c 'setenforce 1; sed -i "s/^SELINUX=.*/SELINUX=enforcing/" /etc/selinux/config' >/dev/null 2>&1 && say "OK SELinux protection is on" || say "FAIL Cancelled: nothing was changed" ;;
    virus) (plasmawindowed org.monsterlinux.shield) >/dev/null 2>&1 & disown; say "OK Monster Shield opened: press Quick check" ;;
    quarantine) mkdir -p "$HOME/Quarantine" && chmod 700 "$HOME/Quarantine" && say "OK Quarantine folder made (only you can open it)" ;;
    drive) exec bash "$0" drive ;;
    drive-firmware) fwupdmgr update -y --no-reboot-check >/dev/null 2>&1 && say "OK Firmware installed: restart your PC to finish" || say "FAIL Firmware update was cancelled or didn't work" ;;
    *) say "FAIL Unknown fix" ;;
  esac ;;

*) say "FAIL Unknown button" ;;
esac
exit 0
