#!/usr/bin/env bash
set -euo pipefail

OS_RELEASE=/usr/lib/os-release

# KINMIN Linux identity
sed -i \
  -e 's/^NAME=.*/NAME="KINMIN Linux"/' \
  -e 's/^ID=.*/ID=kinmin/' \
  -e 's/^PRETTY_NAME=.*/PRETTY_NAME="KINMIN Linux 1.0"/' \
  -e 's/^VERSION=.*/VERSION="1.0"/' \
  -e 's/^VERSION_ID=.*/VERSION_ID="1.0"/' \
  "$OS_RELEASE"

if grep -q '^ID_LIKE=' "$OS_RELEASE"; then
    sed -i 's/^ID_LIKE=.*/ID_LIKE=fedora/' "$OS_RELEASE"
else
    echo 'ID_LIKE=fedora' >> "$OS_RELEASE"
fi

# KINMIN metadata
mkdir -p /etc/kinmin

cat > /etc/kinmin-release <<'RELEASE'
KINMIN Linux
Version: 1.0
Base: Fedora 44
Architecture: x86_64
Maintainer: KINMIN Studio
RELEASE

echo "KINMIN branding installed."
