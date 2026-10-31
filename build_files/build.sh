#!/bin/bash

set -ouex pipefail

# Copy the contents of system_files/ of the git repo to /
cp -avf "/ctx/system_files"/. /

### Install packages

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images
# List of rpmfusion packages can be found here:
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/43/x86_64/repoview/index.html&protocol=https&redirect=1

# this installs a package from fedora repos
dnf5 install -y tmux
# Drive Check (Monster Magic) reads drive health with smartctl; fwupd is already in Bazzite.
dnf5 install -y smartmontools || echo "WARNING: smartmontools not installed"

# Use a COPR Example:
#
# dnf5 -y copr enable ublue-os/staging
# dnf5 -y install package
# Disable COPRs so they don't end up enabled on the final image:
# dnf5 -y copr disable ublue-os/staging

# (Template example "systemctl enable podman.socket" removed: Bazzite already turns Podman on for every user.)


   #### Monster Linux: trust images signed with our key
   jq '.transports.docker["ghcr.io/spongebobmc2"] = [{"type":"sigstoreSigned","keyPath":"/etc/pki/containers/spongebobmc2.pub","signedIdentity":{"type":"matchRepository"}}]' /etc/containers/policy.json > /tmp/policy.json
   mv /tmp/policy.json /etc/containers/policy.json


#### Monster Gloop: complete system theme
# system_files/ (copied to / earlier in this script) installs the theme files.
# These lines make Monster Gloop the default for every user.

kwriteconfig6 --file /etc/xdg/kdeglobals --group General --key ColorScheme MonsterGloop
kwriteconfig6 --file /etc/xdg/kdeglobals --group General --key AccentColor "168,224,58"
kwriteconfig6 --file /etc/xdg/kdeglobals --group KDE --key LookAndFeelPackage org.monsterlinux.gloop
kwriteconfig6 --file /etc/xdg/plasmarc --group Theme --key name default
kwriteconfig6 --file /etc/xdg/ksplashrc --group KSplash --key Engine KSplashQML
kwriteconfig6 --file /etc/xdg/ksplashrc --group KSplash --key Theme org.monsterlinux.gloop
kwriteconfig6 --file /etc/xdg/konsolerc --group "Desktop Entry" --key DefaultProfile MonsterGloop.profile
kwriteconfig6 --file /etc/xdg/kscreenlockerrc --group Greeter --group Wallpaper --group org.kde.image --group General --key Image "file:///usr/share/wallpapers/MonsterGloop/"


#### Monster Linux taskbar buttons (Network Fix + Lockdown)
chmod 755 /usr/bin/monster-lockdown /usr/bin/monster-netfix

#### Monster Themes Studio (System Settings > Appearance & Style)
chmod 755 /usr/share/plasma/plasmoids/org.monsterlinux.themesstudio/contents/code/apply.sh
# System Settings entry: one copy, in the folder Plasma 6 System Settings actually reads
# (plasma/systemsettings/externalmodules, per systemsettings' kcmmetadatahelpers.h).
mkdir -p /usr/share/plasma/systemsettings/externalmodules
cp /usr/share/monster-linux/monster-themes-studio-settings.desktop /usr/share/plasma/systemsettings/externalmodules/
# Hide KDE's own appearance pages (users can bring them back in the Studio under More).
# Written as plain text: kwriteconfig6 failed here in the build (exit code 2).
cat >> /etc/xdg/kdeglobals <<'EOF'

[KDE Control Module Restrictions]
kcm_wallpaper=false
kcm_colors=false
kcm_lookandfeel=false
kcm_desktoptheme=false
kcm_kwindecoration=false
kcm_icons=false
kcm_cursortheme=false
kcm_splashscreen=false
kcm_sddm=false
kcm_style=false
kcm_fonts=false
kcm_fontinst=false
kcm_animations=false
EOF
gtk-update-icon-cache -f /usr/share/icons/hicolor || true

#### Monster Linux name (boot menu entries and About This System)
# Only the display names change. ID stays "bazzite" so Bazzite's own tools and updates keep working.
sed -i -e 's/^NAME=.*/NAME="Monster Linux"/' \
       -e 's/^PRETTY_NAME=.*/PRETTY_NAME="Monster Linux (built on Bazzite)"/' /usr/lib/os-release

# Rename Bazzite's own apps (Portal, updater, docs...) to Monster in the app menu and search.
# Only the names shown to people change; the apps themselves stay the same.
RENAMED=""
for f in $(grep -lis "^\(Name\|GenericName\|Comment\|Keywords\)\(\[[^]]*\]\)\?=.*bazzite" /usr/share/applications/*.desktop /etc/xdg/autostart/*.desktop /etc/skel/.config/autostart/*.desktop 2>/dev/null); do
  sed -i -E '/^(Name|GenericName|Comment|Keywords|X-GNOME-FullName)(\[[^]]*\])?=/ s/Bazzite/Monster Linux/g; /^(Name|GenericName|Comment|Keywords)(\[[^]]*\])?=/ s/bazzite/monster/g' "$f"
  RENAMED="$RENAMED $(basename "$f"): $(grep -m1 '^Name=' "$f" | cut -d= -f2) ·"
done
[ -f /usr/share/yafti/yafti.yml ] && sed -i -E 's/^title: Bazzite Portal/title: Monster Portal/; /^  - title:/ s/Bazzite/Monster Linux/g' /usr/share/yafti/yafti.yml
sed -i 's/Monster Linux Portal/Monster Portal/g' $(grep -lis "Monster Linux Portal" /usr/share/applications/*.desktop /etc/xdg/autostart/*.desktop /etc/skel/.config/autostart/*.desktop 2>/dev/null) 2>/dev/null || true
echo "::notice title=Renamed apps::${RENAMED:-none found}"
echo "::notice title=Update apps in menu::$(grep -lis "^Name=.*updat" /usr/share/applications/*.desktop 2>/dev/null | while read f; do printf "%s=%s · " "$(basename "$f")" "$(grep -m1 "^Name=" "$f" | cut -d= -f2)"; done)"

#### Monster Gloop boot splash (Gloop blinks while the PC starts)
# Bazzite doesn't ship Plymouth's "script" plugin, which the Gloop splash needs.
# Without it Plymouth silently falls back to the Bazzite spinner.
# If any part fails, the build still finishes and the PC keeps the Bazzite splash.
dnf5 install -y plymouth-plugin-script || echo "WARNING: plymouth script plugin not installed"
mkdir -p /etc/plymouth
printf '[Daemon]\nTheme=monster-gloop\n' > /etc/plymouth/plymouthd.conf
if [ -f /usr/lib64/plymouth/script.so ] && [ -f /usr/share/plymouth/themes/monster-gloop/monster-gloop.plymouth ]; then
  # Same dracut call Bazzite uses (build_files/build-initramfs), so the start-up files match theirs plus the splash.
  QK="$(dnf5 repoquery --installed --queryformat='%{evr}.%{arch}' kernel 2>/dev/null | tail -n1)"
  [ -n "$QK" ] && [ -d "/usr/lib/modules/$QK" ] || QK="$(ls /usr/lib/modules | sort -V | tail -n1)"
  if /usr/bin/dracut --no-hostonly --kver "$QK" --reproducible --zstd -v --add ostree --add fido2 -f "/usr/lib/modules/$QK/initramfs.img"; then
    chmod 0600 "/usr/lib/modules/$QK/initramfs.img"
    echo "::notice title=Boot splash::Gloop splash built into the initramfs for $QK"
  else
    echo "WARNING: initramfs rebuild failed; boot splash unchanged"
  fi
else
  echo "WARNING: Plymouth splash not set (script plugin or theme missing)"
fi

#### Login screen (Bazzite uses Plasma Login Manager, which reads /etc/plasmalogin.conf)
kwriteconfig6 --file /etc/plasmalogin.conf --group Greeter --group Wallpaper --group org.kde.image --group General \
  --key Image "file:///usr/share/wallpapers/MonsterGloop/contents/images/3840x2160.png" \
  || echo "WARNING: login screen wallpaper not set"

#### NordVPN built in (repo file comes from system_files/etc/yum.repos.d/nordvpn.repo)
# The repo file asks for NordVPN's signing key, so fetch it first or the install fails.
if [ -f /etc/yum.repos.d/nordvpn.repo ]; then
  # nordvpn-gui installs into /opt. On Fedora Atomic /opt is a link to /var/opt,
  # which an image can't write to, so the install fails ("cpio: mkdir failed").
  # Make /opt a real, read-only folder inside the image (the template's own suggested fix).
  if [ -L /opt ]; then rm /opt && mkdir -p /opt; fi
  mkdir -p /etc/pki/rpm-gpg
  curl -fsSL --retry 3 https://repo.nordvpn.com/gpg/nordvpn_public.asc -o /etc/pki/rpm-gpg/nordvpn_public.asc \
    || echo "::warning title=NordVPN key::Couldn't download NordVPN's signing key"
  NORD_RC=0; NORD_OUT=$(dnf5 install -y nordvpn nordvpn-gui 2>&1) || NORD_RC=$?   # "|| " keeps set -e from stopping the build
  echo "$NORD_OUT"
  [ "$NORD_RC" -eq 0 ] || echo "::warning title=NordVPN error::$(echo "$NORD_OUT" | grep -vE '^\s*$' | tail -n 6 | tr '\n' ' ' | cut -c1-900)"
  if [ "$NORD_RC" -eq 0 ]; then
    chmod 755 /usr/libexec/monster-nordvpn-group
    systemctl enable nordvpnd.service monster-nordvpn-group.service || true
    echo "::notice title=NordVPN::Installed $(rpm -q nordvpn nordvpn-gui | tr '\n' ' ')"
  else
    echo "::warning title=NordVPN::NordVPN not installed in the image"
  fi
fi

#### Monster Portal + Monster Updater ("Slime Pop" look)
# Portal: same Bazzite Portal app, opened through monster-portal so it gets the Monster look and name.
chmod 755 /usr/libexec/monster-user-fixes /usr/bin/monster-portal /usr/share/plasma/plasmoids/org.monsterlinux.updater/contents/code/updater.sh
for f in /usr/share/applications/io.github.ublue_os.yafti_gtk.desktop /etc/skel/.config/autostart/bazzite-portal.desktop /etc/xdg/autostart/bazzite-portal.desktop; do
  [ -f "$f" ] || continue
  sed -i -E 's@^Exec=(/usr/bin/)?yafti_gtk\.py@Exec=/usr/bin/monster-portal@; s@^Icon=.*@Icon=org.monsterlinux.portal@; s@^Name=.*@Name=Monster Portal@; /^Name\[/d' "$f"
done
[ -f /usr/libexec/ublue-nvidia-flatpak-runtime-notify ] && sed -i 's@/usr/bin/yafti_gtk.py@/usr/bin/monster-portal@g' /usr/libexec/ublue-nvidia-flatpak-runtime-notify
# Anything that still starts Bazzite's Portal (KRunner search, NVIDIA notices, ujust...) gets Monster Portal:
# the real Portal code moves to /usr/libexec and /usr/bin/yafti_gtk.py becomes a small hand-off.
if [ -f /usr/bin/yafti_gtk.py ] && ! grep -q monster-portal /usr/bin/yafti_gtk.py; then
  mv /usr/bin/yafti_gtk.py /usr/libexec/yafti_gtk_bazzite.py
  printf '#!/usr/bin/bash\n# Monster Linux: the Portal is Monster Portal\nexec /usr/bin/monster-portal "$@"\n' > /usr/bin/yafti_gtk.py
  chmod 755 /usr/bin/yafti_gtk.py
fi
echo "::notice title=Monster Portal::$(grep -h '^Exec=' /usr/share/applications/io.github.ublue_os.yafti_gtk.desktop 2>/dev/null || echo 'Portal entry not found')"
# Updater: Monster Updater runs Bazzite's own updater (uupd). Any other "update" entry in the menu is hidden
# so there is only one updater to find.
HID=""
for f in /usr/share/applications/*.desktop; do
  case "$(basename "$f")" in org.monsterlinux.updater.desktop|org.kde.discover*) continue;; esac
  if [ "$(basename "$f")" = io.github.rfrench3.bazzite-updater.desktop ] || grep -qiE '^Exec=.*(ujust (update|upgrade)|uupd|topgrade|system-update|bazzite-updater)' "$f" || grep -qiE '^Name=(System Update|Update System|Bazzite Update|Update Bazzite)$' "$f"; then
    grep -q '^NoDisplay=' "$f" && sed -i 's/^NoDisplay=.*/NoDisplay=true/' "$f" || sed -i 's/^\[Desktop Entry\]/[Desktop Entry]\nNoDisplay=true/' "$f"
    HID="$HID $(basename "$f")"
  fi
done
echo "::notice title=Monster Updater::Hid other updater entries:${HID:- none found}"
fc-cache -f /usr/share/fonts/monster >/dev/null 2>&1 || true

#### Login screen buttons as little monsters (icon set used only by the login screen)
chmod 755 /usr/libexec/monster-root /usr/libexec/monster-login-icons /usr/libexec/monster-power-icons
gtk-update-icon-cache -f /usr/share/icons/Monster-Login >/dev/null 2>&1 || true
gtk-update-icon-cache -f /usr/share/icons/hicolor >/dev/null 2>&1 || true
systemctl enable monster-login-icons.service
echo "::notice title=Login buttons::$(ls /usr/share/icons/Monster-Login/scalable/actions | tr '\n' ' ') · login user home: $(getent passwd plasmalogin | cut -d: -f6)"

#### Monster Shield: firewall places (Home / Public) and ClamAV virus check
# New installs start on Home
[ -f /etc/firewalld/firewalld.conf ] && sed -i 's/^DefaultZone=.*/DefaultZone=monster-home/' /etc/firewalld/firewalld.conf
chmod 755 /usr/share/plasma/plasmoids/org.monsterlinux.shield/contents/code/shield.sh /usr/libexec/monster-shield-daily
dnf5 install -y clamav clamav-update || echo "::warning title=Monster Shield::ClamAV not installed"
if command -v freshclam >/dev/null; then
  sed -i 's/^Example/#Example/' /etc/freshclam.conf 2>/dev/null || true
  systemctl enable clamav-freshclam.service || true      # keeps the virus list fresh
  echo "::notice title=Monster Shield::$(rpm -q clamav clamav-update | tr '\n' ' ') · zones: $(ls /usr/lib/firewalld/zones | grep monster | tr '\n' ' ')"
fi

#### Terminal system card (top right of Konsole / Dolphin's F4 terminal). Reads each PC's own details.
# It takes the place of Bazzite's welcome banner (same on/off switch: ujust toggle-user-motd).
chmod 755 /usr/bin/monster-hello /usr/bin/monster-help
# terminal buttons are links (monster-help://...): open them with one click, show them underlined
P=/usr/share/konsole/MonsterGloop.profile
if [ -f "$P" ]; then
  kwriteconfig6 --file "$P" --group "Interaction Options" --key OpenLinksByDirectClickEnabled true
  kwriteconfig6 --file "$P" --group "Interaction Options" --key UnderlineLinksEnabled true
  kwriteconfig6 --file "$P" --group "Interaction Options" --key AllowEscapedLinks true
  kwriteconfig6 --file "$P" --group "Interaction Options" --key EscapedLinksSchema "http://;https://;file://;monster-help://"
fi
if [ -f /usr/libexec/ublue-motd ]; then
  mv /usr/libexec/ublue-motd /usr/libexec/ublue-motd.bazzite
  install -m 755 /usr/libexec/ublue-motd.monster /usr/libexec/ublue-motd
  echo "::notice title=Terminal card::Bazzite welcome banner replaced by the Monster card · callers: $(grep -rl ublue-motd /etc/profile.d /usr/share/fish/functions /etc/bashrc 2>/dev/null | tr '\n' ' ')"
else
  echo "::warning title=Terminal card::ublue-motd not found; card not hooked in"
fi
rm -f /usr/libexec/ublue-motd.monster

#### No window snapping: dragging a window to an edge or the top doesn't resize it or stick it there
for k in ElectricBorderTiling ElectricBorderMaximize; do kwriteconfig6 --file /etc/xdg/kwinrc --group Windows --key $k false; done
for k in BorderSnapZone WindowSnapZone CenterSnapZone; do kwriteconfig6 --file /etc/xdg/kwinrc --group Windows --key $k 0; done
#### Brave: the standard web browser
if [ -L /opt ]; then rm /opt && mkdir -p /opt; fi   # Brave installs into /opt (see the NordVPN note)
curl -fsSL --retry 3 https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo -o /etc/yum.repos.d/brave-browser.repo \
  && rpm --import https://brave-browser-rpm-release.s3.brave.com/brave-core.asc \
  || echo "::warning title=Brave::Couldn't add Brave's download source"
BR_RC=0; BR_OUT=$(dnf5 install -y brave-browser 2>&1) || BR_RC=$?
echo "$BR_OUT"
if [ "$BR_RC" -eq 0 ] && [ -f /usr/share/applications/brave-browser.desktop ]; then
  chmod 755 /usr/libexec/monster-default-browser
  # new users and anything that reads the system defaults
  mkdir -p /etc/xdg
  cat > /etc/xdg/mimeapps.list <<'M'
[Default Applications]
text/html=brave-browser.desktop
application/xhtml+xml=brave-browser.desktop
x-scheme-handler/http=brave-browser.desktop
x-scheme-handler/https=brave-browser.desktop
x-scheme-handler/about=brave-browser.desktop
x-scheme-handler/unknown=brave-browser.desktop
M
  cp /etc/xdg/mimeapps.list /usr/share/applications/mimeapps.list
  kwriteconfig6 --file /etc/xdg/kdeglobals --group General --key BrowserApplication brave-browser.desktop
  sed -i 's/^enabled=1/enabled=0/' /etc/yum.repos.d/brave-browser.repo   # updates come with Monster Linux images
  echo "::notice title=Brave::Installed $(rpm -q brave-browser) and set as the default browser"
else
  echo "::warning title=Brave::$(echo "$BR_OUT" | grep -vE '^\s*$' | tail -n 5 | tr '\n' ' ' | cut -c1-800)"
fi

#### Last step: terminal guide links (monster-help://) open the Monster guides.
# (kept at the end so the browser defaults above can't overwrite it)
for f in /etc/xdg/mimeapps.list /usr/share/applications/mimeapps.list; do
  [ -f "$f" ] || printf '[Default Applications]\n' > "$f"
  grep -q '^\[Default Applications\]' "$f" || printf '[Default Applications]\n' >> "$f"
  grep -q 'x-scheme-handler/monster-help' "$f" || sed -i '/^\[Default Applications\]/a x-scheme-handler/monster-help=monster-help-links.desktop' "$f"
done
update-desktop-database /usr/share/applications >/dev/null 2>&1 || true
echo "::notice title=Terminal buttons::$(grep -h monster-help /etc/xdg/mimeapps.list) · Konsole links: $(grep -c EscapedLinks /usr/share/konsole/MonsterGloop.profile 2>/dev/null)"

#### Safety net: Qt refuses half-pixel font sizes and then the whole Monster app won't open.
if grep -rnE "pixelSize: *[0-9]+\.[0-9]" /usr/share/plasma/plasmoids/org.monsterlinux.* ; then
  echo "::error title=Monster apps::A font.pixelSize has a decimal value (see above). Qt won't load that window."; exit 1
fi
