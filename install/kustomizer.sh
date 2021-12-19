#!/usr/bin/env bash

#  Copyright 2021 Stefan Prodan
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.

set -e

DEFAULT_BIN_DIR="/usr/local/bin"
BIN_DIR=${1:-"${DEFAULT_BIN_DIR}"}
GITHUB_REPO="stefanprodan/kustomizer"
COSIGN_PUB_KEY="https://stefanprodan.keybase.pub/cosign/kustomizer.pub"

# Helper functions for logs
info() {
    echo '[INFO] ' "$@"
}

warn() {
    echo '[WARN] ' "$@" >&2
}

fatal() {
    echo '[ERROR] ' "$@" >&2
    exit 1
}

# Set os, fatal if operating system not supported
setup_verify_os() {
    if [[ -z "${OS}" ]]; then
        OS=$(uname)
    fi
    case ${OS} in
        Darwin)
            OS=darwin
            ;;
        Linux)
            OS=linux
            ;;
        *)
            fatal "Unsupported operating system ${OS}"
    esac
}

# Set arch, fatal if architecture not supported
setup_verify_arch() {
    if [[ -z "${ARCH}" ]]; then
        ARCH=$(uname -m)
    fi
    case ${ARCH} in
        arm64|aarch64|armv8l)
            ARCH=arm64
            ;;
        amd64)
            ARCH=amd64
            ;;
        x86_64)
            ARCH=amd64
            ;;
        *)
            fatal "Unsupported architecture ${ARCH}"
    esac
}

# Verify existence of downloader executable
verify_downloader() {
    # Return failure if it doesn't exist or is no executable
    [[ -x "$(which "$1")" ]] || return 1

    # Set verified executable as our downloader program and return success
    DOWNLOADER=$1
    return 0
}

# Create temporary directory and cleanup when done
setup_tmp() {
    TMP_DIR=$(mktemp -d -t kustomizer-install.XXXXXXXXXX)
    TMP_METADATA="${TMP_DIR}/kustomizer.json"
    TMP_HASH="${TMP_DIR}/kustomizer.hash"
    TMP_BIN="${TMP_DIR}/kustomizer.tar.gz"
    cleanup() {
        local code=$?
        set +e
        trap - EXIT
        rm -rf "${TMP_DIR}"
        exit ${code}
    }
    trap cleanup INT EXIT
}

# Find version from Github metadata
get_release_version() {
    METADATA_URL="https://api.github.com/repos/${GITHUB_REPO}/releases/latest"

    info "Downloading metadata ${METADATA_URL}"
    download "${TMP_METADATA}" "${METADATA_URL}"

    VERSION_KUSTOMIZER=$(grep '"tag_name":' "${TMP_METADATA}" | sed -E 's/.*"([^"]+)".*/\1/' | cut -c 2-)
    if [[ -n "${VERSION_KUSTOMIZER}" ]]; then
        info "Using ${VERSION_KUSTOMIZER} as release"
    else
        fatal "Unable to determine release version"
    fi
}

# Download from file from URL
download() {
    [[ $# -eq 2 ]] || fatal 'download needs exactly 2 arguments'

    case $DOWNLOADER in
        curl)
            curl -o "$1" -sfL "$2"
            ;;
        wget)
            wget -qO "$1" "$2"
            ;;
        *)
            fatal "Incorrect executable '${DOWNLOADER}'"
            ;;
    esac

    # Abort if download command failed
    [[ $? -eq 0 ]] || fatal 'Download failed'
}

# Download hash from Github URL
download_hash() {
    HASH_URL="https://github.com/${GITHUB_REPO}/releases/download/v${VERSION_KUSTOMIZER}/kustomizer_${VERSION_KUSTOMIZER}_checksums.txt"
    set -e

    info "Downloading hash ${HASH_URL}"
    download "${TMP_HASH}" "${HASH_URL}"
    HASH_EXPECTED=$(grep " kustomizer_${VERSION_KUSTOMIZER}_${OS}_${ARCH}.tar.gz$" "${TMP_HASH}")
    HASH_EXPECTED=${HASH_EXPECTED%%[[:blank:]]*}
}

# Download binary from Github URL
download_binary() {
    BIN_URL="https://github.com/${GITHUB_REPO}/releases/download/v${VERSION_KUSTOMIZER}/kustomizer_${VERSION_KUSTOMIZER}_${OS}_${ARCH}.tar.gz"
    info "Downloading binary ${BIN_URL}"
    download "${TMP_BIN}" "${BIN_URL}"
    info "Downloading signature ${BIN_URL}.sig"
    download "${TMP_BIN}.sig" "${BIN_URL}.sig"
}

compute_sha256sum() {
  cmd=$(which sha256sum shasum | head -n 1)
  case $(basename "$cmd") in
    sha256sum)
      sha256sum "$1" | cut -f 1 -d ' '
      ;;
    shasum)
      shasum -a 256 "$1" | cut -f 1 -d ' '
      ;;
    *)
      fatal "Can not find sha256sum or shasum to compute checksum"
      ;;
  esac
}

# Verify downloaded binary hash
verify_binary() {
    info "Verifying binary download"
    HASH_BIN=$(compute_sha256sum "${TMP_BIN}")
    HASH_BIN=${HASH_BIN%%[[:blank:]]*}
    if [[ "${HASH_EXPECTED}" != "${HASH_BIN}" ]]; then
        fatal "Download sha256 does not match ${HASH_EXPECTED}, got ${HASH_BIN}"
    fi
}

# Verify the signature
verify_signature() {
  if [[ -x "$(which "cosign")" ]]
  then
    info "Verifying signature with cosign"
    if cosign verify-blob --key "${COSIGN_PUB_KEY}" --signature "${TMP_BIN}.sig" "${TMP_BIN}" > /dev/null 2>&1; then
       info "Verified OK"
    else
       fatal "Failed to verify signature"
    fi
  else
    info "Verifying signature skipped, cosign not found in PATH"
  fi
}

# Setup permissions and move binary
setup_binary() {
    chmod 755 "${TMP_BIN}"
    info "Installing kustomizer to ${BIN_DIR}/kustomizer"
    tar -xzof "${TMP_BIN}" -C "${TMP_DIR}"

    local CMD_MOVE="mv -f \"${TMP_DIR}/kustomizer\" \"${BIN_DIR}\""
    if [[ -w "${BIN_DIR}" ]]; then
        eval "${CMD_MOVE}"
    else
        eval "sudo ${CMD_MOVE}"
    fi
}

# Run the install process
{
    setup_verify_os
    setup_verify_arch
    verify_downloader curl || verify_downloader wget || fatal 'Can not find curl or wget for downloading files'
    setup_tmp
    get_release_version
    download_hash
    download_binary
    verify_binary
    verify_signature
    setup_binary
}
