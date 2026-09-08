#!/usr/bin/bash

## The script was taken from the bluefin repo and modified for our needs

echo "::group:: ===$(basename "$0")==="

set -eoux pipefail

KERNEL="$(rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"

# Remove Existing Kernel
for pkg in kernel kernel-core kernel-modules kernel-modules-core kernel-modules-extra; do
    rpm --erase $pkg --nodeps
done

# Fetch Common AKMODS & Kernel RPMS
skopeo copy --retry-times 3 docker://ghcr.io/ublue-os/akmods:main-"$(rpm -E %fedora)"-"${KERNEL}" dir:/tmp/akmods
AKMODS_TARGZ=$(jq -r '.layers[].digest' </tmp/akmods/manifest.json | cut -d : -f 2)
tar -xvzf /tmp/akmods/"$AKMODS_TARGZ" -C /tmp/
mv /tmp/rpms/* /tmp/akmods/
# NOTE: kernel-rpms should auto-extract into correct location

# Install Kernel
dnf5 -y install \
    /tmp/kernel-rpms/kernel-[0-9]*.rpm \
    /tmp/kernel-rpms/kernel-core-*.rpm \
    /tmp/kernel-rpms/kernel-modules-*.rpm

# TODO: Figure out why akmods cache is pulling in akmods/kernel-devel
dnf5 -y install \
    /tmp/kernel-rpms/kernel-devel-*.rpm

dnf5 versionlock add kernel kernel-devel kernel-devel-matched kernel-core kernel-modules kernel-modules-core kernel-modules-extra

dnf5 copr enable -y ublue-os/akmods

# RPMFUSION Dependent AKMODS
RPMFUSION_FREE_REPO=/etc/yum.repos.d/rpmfusion-free-build.repo
RPMFUSION_NONFREE_REPO=/etc/yum.repos.d/rpmfusion-nonfree-build.repo

cat > "${RPMFUSION_FREE_REPO}" <<'REPOEOF'
[rpmfusion-free]
name=RPM Fusion for Fedora $releasever - Free
baseurl=https://download1.rpmfusion.org/free/fedora/releases/$releasever/Everything/$basearch/os/
enabled=1
metadata_expire=3d
gpgcheck=0
skip_if_unavailable=1

[rpmfusion-free-updates]
name=RPM Fusion for Fedora $releasever - Free - Updates
baseurl=https://download1.rpmfusion.org/free/fedora/updates/$releasever/$basearch/
enabled=1
metadata_expire=3d
gpgcheck=0
skip_if_unavailable=1
REPOEOF

cat > "${RPMFUSION_NONFREE_REPO}" <<'REPOEOF'
[rpmfusion-nonfree]
name=RPM Fusion for Fedora $releasever - Nonfree
baseurl=https://download1.rpmfusion.org/nonfree/fedora/releases/$releasever/Everything/$basearch/os/
enabled=1
metadata_expire=3d
gpgcheck=0
skip_if_unavailable=1

[rpmfusion-nonfree-updates]
name=RPM Fusion for Fedora $releasever - Nonfree - Updates
baseurl=https://download1.rpmfusion.org/nonfree/fedora/updates/$releasever/$basearch/
enabled=1
metadata_expire=3d
gpgcheck=0
skip_if_unavailable=1
REPOEOF

dnf5 -y install \
    v4l2loopback /tmp/akmods/kmods/*v4l2loopback*.rpm

rm -f "${RPMFUSION_FREE_REPO}" "${RPMFUSION_NONFREE_REPO}"

dnf5 copr disable -y ublue-os/akmods
