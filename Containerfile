FROM scratch AS ctx

COPY build /build
COPY custom /custom
COPY system_files /system_files
# Copy from OCI containers to distinct subdirectories to avoid conflicts
# Note: Renovate can automatically update these :latest tags to SHA-256 digests for reproducibility
COPY --from=ghcr.io/projectbluefin/common:latest@sha256:71cf1d978f2286f9f0602caf59439b15bc3b88682607bb0d712fb052f31cd8aa /system_files /oci/common
COPY --from=ghcr.io/ublue-os/brew:latest@sha256:bed056871da6edd8c6ee455a274283ae83bf269461dcad758a7729aaad018401 /system_files /oci/brew
COPY --from=ghcr.io/ublue-os/bluefin-wallpapers-gnome:latest@sha256:470572484d5b7b8f5ce422f8a7af4fbdbe66f6a7075a5ae425ce0658f3e3738c / /oci/artwork/bluefin

FROM quay.io/fedora-ostree-desktops/cosmic-atomic:44@sha256:7f640bfb0e37edd59f6250303e2c12534908d4a591571dc44d9c739e91d7fcb4

ARG IMAGE_NAME="siderite"
ARG IMAGE_VENDOR="mit41"
ARG UBLUE_IMAGE_TAG="stable"
ARG BASE_IMAGE_NAME="cosmic-atomic"
ARG FEDORA_MAJOR_VERSION="44"
ARG VERSION=""

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/boot \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build/00-image-info.sh

# Set dnf options before build scripts (persists across subsequent RUN layers)
RUN dnf5 config-manager setopt keepcache=1 install_weak_deps=0

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache/libdnf5 \
    --mount=type=cache,dst=/var/cache/rpm-ostree \
    --mount=type=secret,id=GITHUB_TOKEN \
    --mount=type=tmpfs,dst=/boot \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build/10-build.sh

### CLEANUP
## Use Bluefin's clean-stage.sh to remove build artifacts before linting.
## /run is deliberately not mounted as tmpfs here: clean-stage.sh must remove
## image-layer files such as /run/dnf so bootc lint's nonempty-run-tmp check
## passes. The script tolerates busy Buildah bind mounts while clearing contents.
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    --mount=type=tmpfs,dst=/boot \
    /ctx/build/clean-stage.sh

### /opt
## Makes /opt writeable by default. Needs to be here to make the main image
## build strict (no /opt there). This is for downstream images/stuff like k0s.
## If you need /opt as an immutable real directory for build-time packages
## (e.g. google-chrome, docker-desktop), replace the next line with:
##   RUN rm /opt && mkdir /opt
RUN rm -rf /opt && ln -s /var/opt /opt

### INIT
## Required for bootc images
CMD ["/sbin/init"]

### LINTING
## Verify final image and contents are correct.
RUN bootc container lint
