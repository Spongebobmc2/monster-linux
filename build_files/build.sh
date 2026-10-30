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
chmod 755 /usr/bin/monster-portal /usr/share/plasma/plasmoids/org.monsterlinux.updater/contents/code/updater.sh
for f in /usr/share/applications/io.github.ublue_os.yafti_gtk.desktop /etc/skel/.config/autostart/bazzite-portal.desktop /etc/xdg/autostart/bazzite-portal.desktop; do
  [ -f "$f" ] || continue
  sed -i -E 's@^Exec=(/usr/bin/)?yafti_gtk\.py@Exec=/usr/bin/monster-portal@; s@^Icon=.*@Icon=org.monsterlinux.portal@; s@^Name=.*@Name=Monster Portal@; /^Name\[/d' "$f"
done
[ -f /usr/libexec/ublue-nvidia-flatpak-runtime-notify ] && sed -i 's@/usr/bin/yafti_gtk.py@/usr/bin/monster-portal@g' /usr/libexec/ublue-nvidia-flatpak-runtime-notify
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
