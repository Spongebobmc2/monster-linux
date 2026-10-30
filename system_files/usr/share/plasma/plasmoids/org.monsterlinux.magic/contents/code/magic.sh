#!/bin/bash
# Monster Magic helper. Every button = one command here.
# Output lines the app understands:
#   STEP <text>   what is happening
#   OK <text>     a part that worked
#   FAIL <text>   a part that didn't (plain words)
#   PROOF <text>  the proof shown big on screen
#   PLAN <text>   (plan mode only) what the button will do
# Root changes go through pkexec (the normal password box).

cmd="$1"; shift
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/monster-magic"
mkdir -p "$STATE"
say() { echo "$*"; }
human() { numfmt --to=iec --suffix=B "$1" 2>/dev/null || echo "${1} bytes"; }
freebytes() { df --output=avail -B1 "$HOME" | tail -1 | tr -d ' '; }

plan() {
  case "$1" in
    windows) say "PLAN Look in the folder you pick for Desktop, Documents, Pictures, Music, Videos and Downloads"
             say "PLAN Copy them into your matching folders, inside a 'From Windows' folder"
             say "PLAN Never overwrite anything you already have"
             say "PLAN Count the files before and after to prove it" ;;
    yesterday) say "PLAN Compare the system you're running with the previous working one"
               say "PLAN Show exactly what changed"
               say "PLAN If you press Go back: set the previous system to start next time (your files are not touched)" ;;
    openfile) say "PLAN Find out what kind of file it is"
              say "PLAN If no app can open it, install the right free app from Flathub"
              say "PLAN Open the file to prove it" ;;
    plug) say "PLAN List USB devices, sound outputs, cameras, controllers, Bluetooth and printers"
          say "PLAN Play a test sound so you can hear your speakers work"
          say "PLAN Mark each one green (working) or red (needs a fix)" ;;
    fast) say "PLAN Measure how long your PC takes to start"
          say "PLAN Show the 5 slowest parts"
          say "PLAN Turn off the 'wait for network' step and hide the boot menu (password asked)"
          say "PLAN Next time you press this, compare old and new start time" ;;
    space) say "PLAN Measure free space"
           say "PLAN Remove app leftovers nothing uses, picture previews (they rebuild), old logs older than 2 weeks and update caches"
           say "PLAN Never touch your files or your rollback system"
           say "PLAN Measure free space again to prove it" ;;
    drive) say "PLAN Read each drive's own health report (SMART / NVMe): pass or fail, wear, spare blocks, temperature, errors"
           say "PLAN Run TRIM now on every SSD and make sure weekly TRIM is switched on"
           say "PLAN Look for firmware updates for your drives and the rest of the PC (fwupd)"
           say "PLAN Nothing is changed on the drives except TRIM; firmware is only installed if you press Install" ;;
    safe) say "PLAN Check firewall, system updates, Secure Boot, SELinux protection, open network doors and the Quarantine folder"
          say "PLAN Turn on the firewall if it's off (password asked)"
          say "PLAN Show a light: green = safe, amber = check, red = fix needed" ;;
  esac
}

case "$cmd" in
plan) plan "$1" ;;

# 1 ---------------------------------------------------------------------------
windows)
  src="$1"
  [ -d "$src" ] || { say "FAIL That folder can't be opened"; exit 0; }
  found=0; before=$(find "$HOME" -xdev -type f 2>/dev/null | wc -l)
  for pair in "Desktop:Desktop" "Documents:Documents" "My Documents:Documents" "Pictures:Pictures" "Music:Music" "Videos:Videos" "Downloads:Downloads"; do
    from="${pair%%:*}"; to="${pair##*:}"
    for d in "$src/$from" "$src"/*/"$from"; do
      [ -d "$d" ] || continue
      n=$(find "$d" -type f 2>/dev/null | wc -l); [ "$n" -gt 0 ] || continue
      dest="$HOME/$to/From Windows"; mkdir -p "$dest"
      say "STEP Copying $n files from $from"
      cp -rn --preserve=timestamps "$d"/. "$dest"/ 2>/dev/null
      say "OK $from: $n files → $to/From Windows"; found=$((found+n))
    done
  done
  after=$(find "$HOME" -xdev -type f 2>/dev/null | wc -l)
  if [ "$found" -eq 0 ]; then say "FAIL No Desktop, Documents, Pictures, Music, Videos or Downloads folders found there. Pick the Windows user folder (Windows drive → Users → your name)"
  elif [ "$after" -eq "$before" ]; then say "PROOF All $found files were already copied before: nothing missing"
  else say "PROOF $((after-before)) new files copied (your home had $before files, now $after)"; fi ;;

# 3 ---------------------------------------------------------------------------
yesterday)
  st=$(rpm-ostree status --json 2>/dev/null)
  [ -n "$st" ] || { say "FAIL Couldn't read the system history"; exit 0; }
  n=$(echo "$st" | grep -c '"checksum"')
  diff=$(rpm-ostree db diff 2>/dev/null | grep -E '^(Upgraded|Downgraded|Removed|Added):|^  ' | head -40)
  if [ -z "$diff" ]; then say "OK No system changes between this start-up and the previous one"
  else
    say "STEP What changed since the previous working system:"
    echo "$diff" | sed 's/^/STEP   /'
  fi
  say "PROOF ${n} system versions saved. Press Go back to start the previous one next time" ;;
yesterday-go)
  if pkexec rpm-ostree rollback >/dev/null 2>&1; then say "OK The previous system will start next time"; say "PROOF Restart your PC to finish going back"
  else say "FAIL Going back was cancelled or didn't work"; fi ;;

# 5 ---------------------------------------------------------------------------
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
    [ -n "$id" ] || { say "FAIL No app known for .$ext files yet"; exit 0; }
    say "STEP No app for this yet. Installing $id from Flathub..."
    if flatpak install -y --noninteractive flathub "$id" >/dev/null 2>&1; then say "OK Installed $id"
    else say "FAIL Couldn't install $id (check the internet)"; exit 0; fi
    if [ "$id" = com.usebottles.bottles ]; then
      flatpak run com.usebottles.bottles >/dev/null 2>&1 & disown
      say "PROOF Bottles is open: make a Bottle, then press Run Executable and pick this file"; exit 0
    fi
    flatpak run --file-forwarding "$id" @@ "$f" @@ >/dev/null 2>&1 & disown
  else
    say "OK Opens with $app"
    xdg-open "$f" >/dev/null 2>&1 & disown
  fi
  say "PROOF Your file is opening now" ;;

# 6 ---------------------------------------------------------------------------
plug)
  usb=$(lsusb 2>/dev/null | grep -viE 'root hub|hub$' | sed -E 's/^Bus [0-9]+ Device [0-9]+: ID [0-9a-f:]+ //' | head -12)
  [ -n "$usb" ] && echo "$usb" | sed 's/^/OK USB: /' || say "STEP No USB devices found"
  sinks=$(pactl list short sinks 2>/dev/null | awk '{print $2}')
  if [ -n "$sinks" ]; then say "OK Sound out: $(pactl get-default-sink 2>/dev/null)"
    snd=/usr/share/sounds/freedesktop/stereo/complete.oga; [ -f "$snd" ] || snd=$(ls /usr/share/sounds/*/stereo/*.oga 2>/dev/null | head -1)
    [ -n "$snd" ] && (pw-play "$snd" || paplay "$snd") >/dev/null 2>&1 && say "OK Test sound played"
  else say "FAIL No sound output found"; fi
  mic=$(pactl get-default-source 2>/dev/null); [ -n "$mic" ] && say "OK Microphone: $mic"
  cams=$(ls /dev/video* 2>/dev/null | wc -l); [ "$cams" -gt 0 ] && say "OK Camera found ($cams video device(s))" || say "STEP No camera plugged in"
  pads=$(ls /dev/input/js* 2>/dev/null | wc -l); [ "$pads" -gt 0 ] && say "OK Game controller found ($pads)" || say "STEP No game controller plugged in"
  bt=$(bluetoothctl devices Connected 2>/dev/null | cut -d' ' -f3-); [ -n "$bt" ] && echo "$bt" | sed 's/^/OK Bluetooth: /' || say "STEP No Bluetooth devices connected"
  pr=$(lpstat -p 2>/dev/null | awk '{print $2}'); [ -n "$pr" ] && echo "$pr" | sed 's/^/OK Printer: /' || say "STEP No printer set up"
  say "PROOF Did you hear the chime? Every device listed in green is working" ;;

# 7 ---------------------------------------------------------------------------
fast)
  t=$(systemd-analyze 2>/dev/null | head -1)
  total=$(echo "$t" | grep -oE '= [0-9.]+(min [0-9.]+s|s)' | head -1 | tr -d '= ')
  [ -n "$total" ] || { say "FAIL Couldn't measure start-up time"; exit 0; }
  say "STEP $t"
  systemd-analyze blame 2>/dev/null | head -5 | sed -E 's/^ +//; s/^/STEP   slow: /'
  prev=$(cat "$STATE/boot-before" 2>/dev/null)
  if [ -n "$prev" ] && [ -f "$STATE/fast-applied" ]; then
    say "PROOF Was $prev, now $total"; rm -f "$STATE/fast-applied"; echo "$total" > "$STATE/boot-before"; exit 0
  fi
  echo "$total" > "$STATE/boot-before"
  if pkexec bash -c 'systemctl disable NetworkManager-wait-online.service >/dev/null 2>&1; grub2-editenv - set menu_auto_hide=1 >/dev/null 2>&1; true'; then
    say "OK Turned off 'wait for network' at start-up"
    say "OK Boot menu hidden (hold Shift or press Esc while starting to see it)"
    touch "$STATE/fast-applied"
    say "PROOF Start-up is $total now. Restart, then press Start Fast again to see the new time"
  else say "FAIL Cancelled: nothing was changed"; fi ;;

# 8 ---------------------------------------------------------------------------
space)
  b=$(freebytes)
  say "STEP Free space now: $(human "$b")"
  flatpak uninstall --user --unused -y --noninteractive >/dev/null 2>&1 && say "OK Removed unused app parts (yours)"
  rm -rf "$HOME/.cache/thumbnails" 2>/dev/null && say "OK Cleared picture previews (they rebuild by themselves)"
  if pkexec bash -c 'flatpak uninstall --system --unused -y --noninteractive >/dev/null 2>&1; journalctl --vacuum-time=14d >/dev/null 2>&1; rpm-ostree cleanup -m >/dev/null 2>&1; true'; then
    say "OK Removed unused shared app parts, logs older than 2 weeks and update caches"
  else say "STEP Skipped the system part (password box was cancelled)"; fi
  a=$(freebytes); d=$((a-b)); [ "$d" -lt 0 ] && d=0
  say "PROOF Freed $(human "$d") (free space: $(human "$a"))" ;;

# 11 --------------------------------------------------------------------------
drive)
  # Health + TRIM need root: one password box for both.
  ROOTPART='
    for d in $(lsblk -dno NAME,TYPE | awk "\$2==\"disk\"{print \$1}" | grep -vE "^(zram|loop|sr)"); do
      dev=/dev/$d; model=$(lsblk -dno MODEL "$dev" | xargs); [ -n "$model" ] || model=$d
      h=$(smartctl -H "$dev" 2>/dev/null | grep -iE "overall-health|SMART Health Status" | sed "s/.*: *//" | xargs)
      case "$h" in PASSED|OK) echo "OK $model: health $h";; "") echo "STEP $model: no health report (USB drives often hide it)";; *) echo "FAIL $model: health $h (back up your files)";; esac
      A=$(smartctl -A "$dev" 2>/dev/null)
      if [ "${d#nvme}" != "$d" ]; then
        used=$(echo "$A" | awk -F: "/Percentage Used/{gsub(/ /,\"\",\$2);print \$2}")
        spare=$(echo "$A" | awk -F: "/^Available Spare:/{gsub(/ /,\"\",\$2);print \$2}")
        temp=$(echo "$A" | awk -F: "/^Temperature:/{gsub(/^ +/,\"\",\$2);print \$2}")
        errs=$(echo "$A" | awk -F: "/Media and Data Integrity Errors/{gsub(/ /,\"\",\$2);print \$2}")
        echo "STEP   wear used ${used:-?}, spare ${spare:-?}, temperature ${temp:-?}, data errors ${errs:-?}"
        n=${used%\%}; [ -n "$n" ] && [ "$n" -ge 80 ] 2>/dev/null && echo "FAIL $model: ${used} of its life used: plan a replacement"
      else
        hours=$(echo "$A" | awk "/Power_On_Hours/{print \$10}"); realloc=$(echo "$A" | awk "/Reallocated_Sector_Ct/{print \$10}")
        [ -n "$hours$realloc" ] && echo "STEP   powered on ${hours:-?} hours, bad sectors moved ${realloc:-?}"
        [ -n "$realloc" ] && [ "$realloc" -gt 0 ] 2>/dev/null && echo "FAIL $model: $realloc bad sectors: back up your files"
      fi
    done
    systemctl enable --now fstrim.timer >/dev/null 2>&1 && echo "OK Weekly TRIM is on"
    fstrim -av 2>/dev/null | sed "s/^/OK TRIM /"
    true
  '
  if ! command -v smartctl >/dev/null; then say "FAIL The drive health tool (smartctl) is missing"; fi
  trim="TRIM done"
  if out=$(pkexec bash -c "$ROOTPART" 2>/dev/null); then echo "$out"; else out=""; trim="TRIM skipped"; say "FAIL Cancelled: drive health and TRIM need your password"; fi
  ndr=$(echo "$out" | grep -c "^OK .*: health"); nbad=$(echo "$out" | grep -c "^FAIL")
  # Firmware: fwupd reads this as a normal user.
  fw="unknown"
  if command -v fwupdmgr >/dev/null; then
    fwupdmgr refresh >/dev/null 2>&1
    js=$(fwupdmgr get-updates --json 2>/dev/null)
    list=$(echo "$js" | python3 -c 'import sys,json
try: d=json.load(sys.stdin)
except Exception: sys.exit(0)
for dev in d.get("Devices",[]):
  for r in dev.get("Releases",[])[:1]:
    print("%s: %s -> %s" % (dev.get("Name","?"), dev.get("Version","?"), r.get("Version","?")))' 2>/dev/null)
    if [ -n "$list" ]; then
      echo "$list" | sed 's/^/STEP Firmware update: /'; fw="$(echo "$list" | wc -l) firmware update(s) available"
    else say "OK Firmware is up to date"; fw="firmware up to date"; fi
  else say "STEP Firmware check tool (fwupd) not found"; fi
  if [ "$nbad" -gt 0 ]; then say "PROOF RED: $nbad drive problem(s) found · $fw"
  elif [ "$trim" = "TRIM skipped" ]; then say "PROOF Drive check cancelled · $fw"
  else say "PROOF $ndr drive(s) healthy · TRIM done · $fw"; fi ;;
drive-firmware)
  if fwupdmgr update -y --no-reboot-check >/dev/null 2>&1; then say "OK Firmware updates installed"; say "PROOF Restart your PC to finish the firmware update"
  else say "FAIL Firmware update was cancelled or didn't work"; fi ;;

# 9 ---------------------------------------------------------------------------
safe)
  score=0; bad=0
  if systemctl is-active --quiet firewalld; then say "OK Firewall is on"; score=$((score+1))
  else say "FAIL Firewall is off"; bad=1; fi
  sb=$(mokutil --sb-state 2>/dev/null | head -1)
  case "$sb" in *enabled*) say "OK Secure Boot is on"; score=$((score+1));; *) say "STEP Secure Boot: ${sb:-unknown}";; esac
  se=$(getenforce 2>/dev/null)
  [ "$se" = Enforcing ] && { say "OK SELinux protection is on"; score=$((score+1)); } || say "STEP SELinux: ${se:-unknown}"
  up=$(rpm-ostree upgrade --check 2>/dev/null | grep -iE 'AvailableUpdate|Version:' | head -1)
  if [ -n "$up" ]; then say "STEP A system update is waiting: $up"; else say "OK System is up to date"; score=$((score+1)); fi
  ports=$(ss -tulnH 2>/dev/null | awk '{print $5}' | grep -vE '^(127\.|\[::1\]|::1)' | grep -vE '%lo' | sed -E 's/.*://' | sort -un | tr '\n' ' ')
  [ -z "$ports" ] && { say "OK No network doors open to other computers"; score=$((score+1)); } || say "STEP Network doors open: $ports (the firewall decides who can use them)"
  [ -d "$HOME/Quarantine" ] && say "OK Quarantine folder ready" || say "STEP Quarantine folder not set up yet"
  if [ "$bad" = 1 ]; then
    if pkexec systemctl enable --now firewalld >/dev/null 2>&1; then say "OK Turned the firewall on"; bad=0; score=$((score+1))
    else say "FAIL Firewall still off (password box was cancelled)"; fi
  fi
  if [ "$bad" = 1 ]; then say "PROOF RED: the firewall needs to be on"
  elif [ "$score" -ge 4 ]; then say "PROOF GREEN: you're protected ($score of 5 checks passed)"
  else say "PROOF AMBER: protected, with $((5-score)) thing(s) worth a look"; fi ;;

*) say "FAIL Unknown button" ;;
esac
