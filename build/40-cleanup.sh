#!/usr/bin/bash

echo "::group:: ===$(basename "$0")==="

set -eoux pipefail
# Setup Systemd
# systemctl --global enable bazaar.service
systemctl --global enable podman-auto-update.timer
systemctl enable brew-setup.service
systemctl enable input-remapper.service
systemctl enable tailscaled.service

# TODO: Install the ublue os flatpak preinstall package
# systemctl enable flatpak-preinstall.service

# Updater
systemctl enable uupd.timer

#disable the old rpm-ostreed-automatic.timer
systemctl disable rpm-ostreed-automatic.timer

# Hide Desktop Files. Hidden removes mime associations
for file in fish htop nvtop; do
    if [[ -f "/usr/share/applications/$file.desktop" ]]; then
        sed -i 's@\[Desktop Entry\]@\[Desktop Entry\]\nHidden=true@g' /usr/share/applications/"$file".desktop
    fi
done

#Add the Flathub Flatpak remote and remove the Fedora Flatpak remote
flatpak remote-add --system --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
systemctl disable flatpak-add-fedora-repos.service

# Disable third-party repos
for repo in negativo17-fedora-multimedia tailscale fedora-cisco-openh264; do
    if [[ -f "/etc/yum.repos.d/${repo}.repo" ]]; then
        sed -i 's@enabled=1@enabled=0@g' "/etc/yum.repos.d/${repo}.repo"
    fi
done
