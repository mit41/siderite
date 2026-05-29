FROM scratch AS ctx

COPY build /build
COPY custom /custom
COPY system_files /system_files
# Copy from OCI containers to distinct subdirectories to avoid conflicts
# Note: Renovate can automatically update these :latest tags to SHA-256 digests for reproducibility
COPY --from=ghcr.io/projectbluefin/common:latest@sha256:fbcef9b1636bc67c2cb58327527f01c9798280229ad5a91c2f8dac0a5d3b6f3c /system_files /oci/common
COPY --from=ghcr.io/ublue-os/brew:latest@sha256:837fd51428e23fbe68b9d35651b0b4158b18c68045f54f00d2410b5c8ad4d363 /system_files /oci/brew
COPY --from=ghcr.io/ublue-os/bluefin-wallpapers-gnome:latest@sha256:e4d74fa741ce9ff03a6a60440a58c31cef6c0fc145182357d243580ba239f810 / /oci/artwork/bluefin
COPY --from=ghcr.io/ublue-os/aurora-wallpapers:latest@sha256:270b3b10cd6fd54e322407275e24b86655c2472738186b1a825786ce26d4ce50 / /oci/artwork/aurora

FROM ghcr.io/ublue-os/base-main:latest@sha256:e9e2d963c35141e090978f1c8f794868cb2d7026a873c65d6f285817a7e48969

### /opt
## Some bootable images, like Fedora, have /opt symlinked to /var/opt, in order to
## make it mutable/writable for users. However, some packages write files to this directory,
## thus its contents might be wiped out when bootc deploys an image, making it troublesome for
## some packages. Eg, google-chrome, docker-desktop.
##
## Uncomment the following line if one desires to make /opt immutable and be able to be used
## by the package manager.

# RUN rm /opt && mkdir /opt

### MODIFICATIONS
## Make modifications desired in your image and install packages by modifying the build scripts.
## The following RUN directive mounts the ctx stage which includes:
##   - Local build scripts from /build
##   - Local custom files from /custom
##   - Files from @projectbluefin/common at /oci/common
##   - Files from @projectbluefin/branding at /oci/branding
##   - Files from @ublue-os/artwork at /oci/artwork
##   - Files from @ublue-os/brew at /oci/brew
## Scripts are run in numerical order (10-build.sh, 20-example.sh, etc.)

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build/10-build.sh

### LINTING
## Verify final image and contents are correct.
RUN bootc container lint
