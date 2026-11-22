#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

RPM_VERSION="${KML_BRANDING_VERSION:-1.0}"
RPM_RELEASE="${KML_BRANDING_RELEASE:-1}"
OUTPUT_DIR="${KML_OUTPUT_DIR:-$PROJECT_ROOT/output}"
RPMBUILD_DIR="$OUTPUT_DIR/rpmbuild"
REPO_DIR="${KML_REPO_DIR:-$OUTPUT_DIR/repo}"
SPEC_TEMPLATE="$PROJECT_ROOT/branding/rpm/kinmin-branding.spec"

WALLPAPER_DIR="$PROJECT_ROOT/branding/wallpapers"
LOGO_DIR="$PROJECT_ROOT/branding/logos"
ICON_DIR="$PROJECT_ROOT/branding/icons"

required_files=(
    "$WALLPAPER_DIR/kinmin-default.png"
    "$WALLPAPER_DIR/marek-piwnicki-NrFhurv1N3I-unsplash.jpg"
    "$WALLPAPER_DIR/petra-reid-W5FKbMSL8D0-unsplash.jpg"
    "$WALLPAPER_DIR/queensland-australia--4DWT-txLSQ-unsplash.jpg"
    "$LOGO_DIR/kinmin-logo.png"
    "$ICON_DIR/kinmin-icon.png"
    "$PROJECT_ROOT/config/fastfetch/config.jsonc"
    "$PROJECT_ROOT/config/backgrounds/kinmin-wallpapers.xml"
    "$PROJECT_ROOT/config/dconf/00-kinmin-background"
    "$PROJECT_ROOT/ASSET-ATTRIBUTION.md"
    "$PROJECT_ROOT/scripts/replace-fedora-logos.sh"
    "$SPEC_TEMPLATE"
)

for file in "${required_files[@]}"; do
    if [[ ! -f "$file" ]]; then
        echo "ERROR: missing required file: $file" >&2
        exit 1
    fi
done

for tool in rpmbuild rpm python3; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "ERROR: required tool is missing: $tool" >&2
        exit 1
    fi
done

mkdir -p "$RPMBUILD_DIR"/{BUILD,BUILDROOT,RPMS/noarch,SOURCES,SPECS,SRPMS}
mkdir -p "$REPO_DIR"

rm -rf "$RPMBUILD_DIR"/BUILD/kinmin-branding-* "$RPMBUILD_DIR"/BUILDROOT/kinmin-branding-*
rm -f "$RPMBUILD_DIR"/RPMS/noarch/kinmin-branding-*.rpm
rm -f "$RPMBUILD_DIR"/SRPMS/kinmin-branding-*.rpm
rm -f "$REPO_DIR"/kinmin-branding-*.rpm

install -m 0644 "$WALLPAPER_DIR/kinmin-default.png" \
    "$RPMBUILD_DIR/SOURCES/kinmin-default.png"
install -m 0644 "$WALLPAPER_DIR/marek-piwnicki-NrFhurv1N3I-unsplash.jpg" \
    "$RPMBUILD_DIR/SOURCES/marek-piwnicki-NrFhurv1N3I-unsplash.jpg"
install -m 0644 "$WALLPAPER_DIR/petra-reid-W5FKbMSL8D0-unsplash.jpg" \
    "$RPMBUILD_DIR/SOURCES/petra-reid-W5FKbMSL8D0-unsplash.jpg"
install -m 0644 "$WALLPAPER_DIR/queensland-australia--4DWT-txLSQ-unsplash.jpg" \
    "$RPMBUILD_DIR/SOURCES/queensland-australia--4DWT-txLSQ-unsplash.jpg"
install -m 0644 "$PROJECT_ROOT/config/backgrounds/kinmin-wallpapers.xml" \
    "$RPMBUILD_DIR/SOURCES/kinmin-wallpapers.xml"
install -m 0644 "$PROJECT_ROOT/config/dconf/00-kinmin-background" \
    "$RPMBUILD_DIR/SOURCES/00-kinmin-background"
install -m 0644 "$PROJECT_ROOT/ASSET-ATTRIBUTION.md" \
    "$RPMBUILD_DIR/SOURCES/ASSET-ATTRIBUTION.md"
install -m 0644 "$LOGO_DIR/kinmin-logo.png" \
    "$RPMBUILD_DIR/SOURCES/kinmin-logo.png"
install -m 0644 "$ICON_DIR/kinmin-icon.png" \
    "$RPMBUILD_DIR/SOURCES/kinmin-icon.png"
install -m 0644 "$PROJECT_ROOT/config/fastfetch/config.jsonc" \
    "$RPMBUILD_DIR/SOURCES/config.jsonc"
install -m 0755 "$PROJECT_ROOT/scripts/replace-fedora-logos.sh" \
    "$RPMBUILD_DIR/SOURCES/replace-fedora-logos.sh"

sed \
    -e "s/^Version:.*/Version:        ${RPM_VERSION}/" \
    -e "s/^Release:.*/Release:        ${RPM_RELEASE}%{?dist}/" \
    "$SPEC_TEMPLATE" > "$RPMBUILD_DIR/SPECS/kinmin-branding.spec"

rpmbuild \
    --define "_topdir $RPMBUILD_DIR" \
    -ba "$RPMBUILD_DIR/SPECS/kinmin-branding.spec"

cp "$RPMBUILD_DIR"/RPMS/noarch/kinmin-branding-*.rpm "$REPO_DIR/"

if command -v createrepo_c >/dev/null 2>&1; then
    createrepo_c --update "$REPO_DIR"
elif command -v createrepo >/dev/null 2>&1; then
    createrepo --update "$REPO_DIR"
else
    python3 "$PROJECT_ROOT/scripts/create-rpm-repo.py" "$REPO_DIR"
fi

echo
echo "KINMIN branding RPM repository is ready:"
echo "  $REPO_DIR"
echo
echo "Expected Kickstart repository URL when using scripts/serve-branding-repo.sh:"
echo "  http://10.0.2.2:8000/"
