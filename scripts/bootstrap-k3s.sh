#!/usr/bin/env bash
set -euo pipefail

K3S_VERSION="v1.37.2+k3s1"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run this script as root."
  exit 1
fi

if command -v k3s >/dev/null 2>&1; then
  INSTALLED_VERSION="$(k3s --version | awk 'NR==1 {print $3}')"
  if [[ "${INSTALLED_VERSION}" != "${K3S_VERSION}" ]]; then
    echo "Expected ${K3S_VERSION}; found ${INSTALLED_VERSION}."
    exit 1
  fi
else
  INSTALLER="$(mktemp)"
  trap 'rm -f "${INSTALLER}"' EXIT

  curl --fail --silent --show-error --location \
    https://get.k3s.io -o "${INSTALLER}"

  INSTALL_K3S_VERSION="${K3S_VERSION}" sh "${INSTALLER}" server \
    --disable traefik \
    --disable servicelb \
    --secrets-encryption \
    --write-kubeconfig-mode 600
fi

systemctl is-active --quiet k3s
k3s kubectl wait --for=condition=Ready nodes --all --timeout=180s
k3s kubectl get nodes
