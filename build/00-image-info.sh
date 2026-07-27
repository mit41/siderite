#!/usr/bin/bash

set -euo pipefail

###############################################################################
# Image Info Generation
###############################################################################
# Generates /usr/share/ublue-os/image-info.json and customizes /usr/lib/os-release.
# This script is bluefin-pattern: each consumer provides its own branding.
#
# Required env vars (set as ARGs in Containerfile):
#   IMAGE_NAME          - Image name (e.g. finpilot, my-custom-os)
#   IMAGE_VENDOR        - Image vendor/owner (e.g. github username or org)
#   UBLUE_IMAGE_TAG     - Image tag/stream (e.g. stable, testing, latest)
#   BASE_IMAGE_NAME     - Base image name (e.g. silverblue)
#   FEDORA_MAJOR_VERSION - Fedora version (e.g. 42)
#   VERSION             - Full version string (e.g. stable-42.20250531)
#   SHA_HEAD_SHORT      - Short git SHA (optional, for dev builds)
###############################################################################

# Branding — customize these for your image
IMAGE_PRETTY_NAME="${IMAGE_PRETTY_NAME:-Siderite}"
IMAGE_LIKE="${IMAGE_LIKE:-fedora}"
HOME_URL="${HOME_URL:-https://github.com/${IMAGE_VENDOR}/${IMAGE_NAME}}"
DOCUMENTATION_URL="${DOCUMENTATION_URL:-https://github.com/${IMAGE_VENDOR}/${IMAGE_NAME}/blob/main/README.md}"
SUPPORT_URL="${SUPPORT_URL:-https://github.com/${IMAGE_VENDOR}/${IMAGE_NAME}/issues}"
BUG_REPORT_URL="${BUG_REPORT_URL:-https://github.com/${IMAGE_VENDOR}/${IMAGE_NAME}/issues/new}"

# Paths
IMAGE_INFO="/usr/share/ublue-os/image-info.json"
OS_RELEASE="/usr/lib/os-release"

# Derive image flavor from name
if [[ "${IMAGE_NAME}" =~ nvidia ]]; then
    IMAGE_FLAVOR="nvidia"
else
    IMAGE_FLAVOR="main"
fi

# Image ref (used by bootc for upgrade source)
IMAGE_REF="ostree-image-signed:docker://ghcr.io/${IMAGE_VENDOR}/${IMAGE_NAME}"

###############################################################################
# Write image-info.json
###############################################################################
mkdir -p /usr/share/ublue-os
cat >"${IMAGE_INFO}" <<EOF
{
  "image-name": "${IMAGE_NAME}",
  "image-flavor": "${IMAGE_FLAVOR}",
  "image-vendor": "${IMAGE_VENDOR}",
  "image-ref": "${IMAGE_REF}",
  "image-tag": "${UBLUE_IMAGE_TAG}",
  "base-image-name": "${BASE_IMAGE_NAME}",
  "fedora-version": "${FEDORA_MAJOR_VERSION}"
}
EOF

echo "Wrote ${IMAGE_INFO}"
echo "  image-name: ${IMAGE_NAME}"
echo "  image-flavor: ${IMAGE_FLAVOR}"
echo "  image-vendor: ${IMAGE_VENDOR}"

###############################################################################
# Customize /usr/lib/os-release
###############################################################################
if [[ -f "${OS_RELEASE}" ]]; then
    # Read existing values
    if [[ -n "${VERSION:-}" ]]; then
        OS_VERSION="${VERSION}"
    else
        OS_VERSION="${UBLUE_IMAGE_TAG}"
    fi

    CUSTOM_VERSION="${OS_VERSION} (${IMAGE_PRETTY_NAME})"

    TMP_FILE=$(mktemp)
    # Update existing keys or add new ones
    awk -v flavor="${IMAGE_FLAVOR}" \
        -v pretty_name="${IMAGE_PRETTY_NAME}" \
        -v name="${IMAGE_NAME}" \
        -v image_id="${IMAGE_NAME}" \
        -v image_version="${OS_VERSION}" \
        -v id_like="${IMAGE_LIKE}" \
        -v home_url="${HOME_URL}" \
        -v doc_url="${DOCUMENTATION_URL}" \
        -v support_url="${SUPPORT_URL}" \
        -v bug_url="${BUG_REPORT_URL}" \
        -v custom_version="${CUSTOM_VERSION}" '
    {
        # Update existing keys
        if ($0 ~ /^VARIANT_ID=/) { print "VARIANT_ID=\"" flavor "\""; next }
        if ($0 ~ /^PRETTY_NAME=/) { print "PRETTY_NAME=\"" pretty_name "\""; next }
        if ($0 ~ /^NAME=/) { print "NAME=\"" name "\""; next }
        if ($0 ~ /^VERSION=/) { print "VERSION=\"" custom_version "\""; next }
        if ($0 ~ /^ID_LIKE=/) { print "ID_LIKE=\"" id_like "\""; next }
        if ($0 ~ /^HOME_URL=/) { print "HOME_URL=\"" home_url "\""; next }
        if ($0 ~ /^DOCUMENTATION_URL=/) { print "DOCUMENTATION_URL=\"" doc_url "\""; next }
        if ($0 ~ /^SUPPORT_URL=/) { print "SUPPORT_URL=\"" support_url "\""; next }
        if ($0 ~ /^BUG_REPORT_URL=/) { print "BUG_REPORT_URL=\"" bug_url "\""; next }

        # Print all other lines as-is
        print $0
    }
    ' "${OS_RELEASE}" > "${TMP_FILE}"

    # Add new keys if they don't exist
    if ! grep -q "^IMAGE_ID=" "${TMP_FILE}"; then
        echo "IMAGE_ID=\"${IMAGE_NAME}\"" >> "${TMP_FILE}"
    fi
    if ! grep -q "^IMAGE_VERSION=" "${TMP_FILE}"; then
        echo "IMAGE_VERSION=\"${OS_VERSION}\"" >> "${TMP_FILE}"
    fi

    mv "${TMP_FILE}" "${OS_RELEASE}"

    echo "Customized ${OS_RELEASE}"
    echo "  VERSION: ${CUSTOM_VERSION}"
fi
