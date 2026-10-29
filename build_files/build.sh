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

# Use a COPR Example:
#
# dnf5 -y copr enable ublue-os/staging
# dnf5 -y install package
# Disable COPRs so they don't end up enabled on the final image:
# dnf5 -y copr disable ublue-os/staging

#### Example for enabling a System Unit File

systemctl enable podman.socket


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

# Login screen background
if [ -d /usr/share/sddm/themes/breeze ]; then
cat > /usr/share/sddm/themes/breeze/theme.conf.user <<'EOF'
[General]
background=/usr/share/wallpapers/MonsterGloop/contents/images/3840x2160.png
type=image
EOF
fi

gtk-update-icon-cache -f /usr/share/icons/hicolor || true

#### Monster Linux taskbar buttons (Network Fix + Lockdown)
chmod 755 /usr/bin/monster-lockdown /usr/bin/monster-netfix

#### Monster Themes Studio (System Settings > Appearance & Style)
chmod 755 /usr/share/plasma/plasmoids/org.monsterlinux.themesstudio/contents/code/apply.sh
# System Settings entry: put it where KDE keeps its own external entries, plus the usual folders
for f in $(grep -rls SystemSettingsExternalApp /usr/share/kservices6 /usr/share/systemsettings /usr/share/applications 2>/dev/null | head -n 3); do
  cp /usr/share/monster-linux/monster-themes-studio-settings.desktop "$(dirname "$f")/"
done
for d in /usr/share/kservices6 /usr/share/systemsettings/externalmodules; do
  mkdir -p "$d" && cp /usr/share/monster-linux/monster-themes-studio-settings.desktop "$d/"
done
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
# If this part has a problem, the build still finishes and the PC keeps the Bazzite splash.
if command -v plymouth-set-default-theme >/dev/null && [ -f /usr/share/plymouth/themes/monster-gloop/monster-gloop.plymouth ]; then
  if plymouth-set-default-theme monster-gloop; then
    KVER=$(ls /usr/lib/modules | sort -V | tail -n1)
    dracut --no-hostonly --kver "$KVER" --reproducible --add ostree -f "/usr/lib/modules/$KVER/initramfs.img" \
      || echo "WARNING: initramfs rebuild failed; boot splash unchanged"
  fi
else
  echo "WARNING: Plymouth splash not set (tool or theme missing)"
fi

#### Login screen (Bazzite uses Plasma Login Manager, which reads /etc/plasmalogin.conf)
kwriteconfig6 --file /etc/plasmalogin.conf --group Greeter --group Wallpaper --group org.kde.image --group General \
  --key Image "file:///usr/share/wallpapers/MonsterGloop/contents/images/3840x2160.png" \
  || echo "WARNING: login screen wallpaper not set"

#### NordVPN built in (repo file comes from system_files/etc/yum.repos.d/nordvpn.repo)
if [ -f /etc/yum.repos.d/nordvpn.repo ]; then
  dnf5 install -y nordvpn nordvpn-gui || echo "WARNING: NordVPN not installed in the image"
  systemctl enable nordvpnd.service || true
fi
