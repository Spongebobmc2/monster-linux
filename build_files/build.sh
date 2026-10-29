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
#### Monster Gloop theme
mkdir -p /etc/xdg
cat > /etc/xdg/plasmarc <<'EOF'
[Theme]
name=breeze-dark
EOF

# Login screen background
if [ -d /usr/share/sddm/themes/breeze ]; then
cat > /usr/share/sddm/themes/breeze/theme.conf.user <<'EOF'
[General]
background=/usr/share/wallpapers/MonsterGloop/contents/images/3840x2160.png
type=image
EOF
fi
