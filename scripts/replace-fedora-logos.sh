#!/usr/bin/env bash
# Replace Fedora distribution logos with KINMIN branding across the system.
# Runs from the kinmin-branding RPM %post scriptlet.
set -u

KML_LOGO_DIR=/usr/share/kinmin/logos
KML_LOGO="$KML_LOGO_DIR/kinmin-logo.png"
KML_ICON="$KML_LOGO_DIR/kinmin-icon.png"

logo_count=0
replace_file() {
    local target="$1"
    local source="$2"
    if [[ -e "$target" || -d "$(dirname "$target")" ]]; then
        install -Dpm 0644 "$source" "$target" >/dev/null 2>&1 && logo_count=$((logo_count + 1))
    fi
}

# /usr/share/pixmaps - classic Fedora logos
replace_file /usr/share/pixmaps/fedora-logo.png           "$KML_ICON"
replace_file /usr/share/pixmaps/fedora-logo-small.png     "$KML_ICON"
replace_file /usr/share/pixmaps/fedora-logo.svg           "$KML_ICON"

# hicolor icon theme - app/distribution icons
for size_dir in /usr/share/icons/hicolor/*/apps; do
    [[ -d "$size_dir" ]] || continue
    for name in fedora-logo fedora-logo-small fedora fedora-app; do
        [[ -f "$size_dir/${name}.png" ]] && replace_file "$size_dir/${name}.png" "$KML_ICON"
    done
done
[[ -d /usr/share/icons/hicolor/scalable/apps ]] && \
    replace_file /usr/share/icons/hicolor/scalable/apps/fedora-logo.svg "$KML_ICON"

# Plymouth boot splash (spinner theme uses watermark.png)
for theme in spinner fade-in text; do
    theme_dir="/usr/share/plymouth/themes/${theme}"
    [[ -d "$theme_dir" ]] || continue
    replace_file "$theme_dir/watermark.png"      "$KML_ICON"
    replace_file "$theme_dir/bgrt-fallback.png"  "$KML_ICON"
done

# Anaconda installer pixmaps
replace_file /usr/share/anaconda/pixmaps/anaconda_header.png "$KML_LOGO"
replace_file /usr/share/anaconda/pixmaps/sidebar-logo.png    "$KML_ICON"

# GNOME Shell / GDM login screen
replace_file /usr/share/gnome-shell/theme/fedora-logo.png   "$KML_ICON"

# /etc/os-release logo pointer
if [[ -f /usr/lib/os-release ]]; then
    if grep -q '^LOGO=' /usr/lib/os-release; then
        sed -i "s|^LOGO=.*|LOGO=$KML_ICON|" /usr/lib/os-release
    else
        echo "LOGO=$KML_ICON" >> /usr/lib/os-release
    fi
fi

# fastfetch: install system-wide config
install -Dpm 0644 /usr/share/kinmin/fastfetch/config.jsonc \
    /etc/fastfetch/config.jsonc >/dev/null 2>&1 || :

echo "KINMIN: replaced $logo_count Fedora logo file(s)."
exit 0
