FROM scratch AS ctx

COPY build /build
COPY custom /custom
COPY system_files /system_files
# Copy from OCI containers to distinct subdirectories to avoid conflicts
# Note: Renovate can automatically update these :latest tags to SHA-256 digests for reproducibility
COPY --from=ghcr.io/projectbluefin/common:latest@sha256:7c9851709892d392eacbc764a62c8224f527ef3f6d72d194ed1f26068bb251eb /system_files /oci/common
COPY --from=ghcr.io/ublue-os/brew:latest@sha256:e3b6878ed7b5ca963fd3f54ce44e6ab83da7533b28c83b2a11b92a5fedaa4adb /system_files /oci/brew
COPY --from=ghcr.io/ublue-os/bluefin-wallpapers-gnome:latest@sha256:470572484d5b7b8f5ce422f8a7af4fbdbe66f6a7075a5ae425ce0658f3e3738c / /oci/artwork/bluefin

FROM quay.io/fedora-ostree-desktops/cosmic-atomic:44@sha256:77679c6549b84483ddc4ac51dbeedb2dac66b4dd2bc0b997bbc6c8aefbfe3e4a

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
