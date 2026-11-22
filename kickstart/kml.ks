
#version=DEVEL

# ==================================================
# KINMIN Linux 1.0
# Based on Fedora 44 Workstation
# Architecture: x86_64
# Maintainer: KINMIN Studio
# ==================================================

lang en_US.UTF-8
keyboard us
timezone Asia/Shanghai --utc
network --bootproto=dhcp --activate

url --url="https://download.fedoraproject.org/pub/fedora/linux/releases/44/Everything/x86_64/os/"
repo --name=kml-branding --baseurl=file:///run/install/repo/repo/ --cost=100 --includepkgs=kinmin-branding

# --------------------------------------------------
# System configuration
# --------------------------------------------------

rootpw --lock
selinux --enforcing
firewall --enabled
services --disabled="sshd" --enabled="NetworkManager,ModemManager,livesys,livesys-late"
shutdown

# --------------------------------------------------
# Bootloader configuration
# --------------------------------------------------

bootloader --location=none

# --------------------------------------------------
# Disk partitioning
# --------------------------------------------------

clearpart --all --initlabel
reqpart
part / --size=12288

# ==================================================
# Post-install configuration
# ==================================================

%post --erroronfail

set -e

# Boot the installed/live system into the GNOME graphical target.
systemctl set-default graphical.target

# Enable tmpfs for /tmp
systemctl enable tmp.mount

# Use tmpfs for /var/tmp
cat >> /etc/fstab <<'FSTAB'
vartmp   /var/tmp    tmpfs   defaults   0  0
FSTAB

# Work around RPM database issues
rm -f /var/lib/rpm/__db*

releasever=$(rpm -q --qf '%{version}\n' --whatprovides system-release)

# uname -i can return "unknown" inside the Anaconda chroot. Use the
# architecture-independent primary key instead.
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-fedora-$releasever-primary

echo "Packages within this LiveCD"

rpm -qa --qf '%{size}\t%{name}-%{version}-%{release}.%{arch}\n' | sort -rn

rm -f /var/lib/rpm/__db*

# Generate man database
/usr/bin/mandb

# Remove core files
rm -f /core*

# Remove random seed
rm -f /var/lib/systemd/random-seed

# Update markers
echo 'File created by kickstart. See systemd-update-done.service(8).' \
    | tee /etc/.updated >/var/.updated

# Remove rescue kernel
rm -f /boot/*-rescue*

# Reset machine-id
rm -f /etc/machine-id
touch /etc/machine-id

# --------------------------------------------------
# KINMIN branding
# --------------------------------------------------

OS_RELEASE=/usr/lib/os-release

# Preserve Fedora ID for compatibility
sed -i \
    -e 's/^NAME=.*/NAME="KINMIN Linux"/' \
    -e 's/^PRETTY_NAME=.*/PRETTY_NAME="KINMIN Linux 1.0"/' \
    -e 's/^VERSION=.*/VERSION="1.0 (Fedora 44)"/' \
    -e 's/^VERSION_ID=.*/VERSION_ID="44"/' \
    "$OS_RELEASE"

# KINMIN release metadata
mkdir -p /etc/kinmin

cat > /etc/kinmin-release <<'RELEASE'
KINMIN Linux
Version: 1.0
Base: Fedora 44
Desktop: GNOME
Architecture: x86_64
Maintainer: KINMIN Studio
RELEASE

%end

# ==================================================
# KINMIN desktop assets
# ==================================================
# Wallpapers, GNOME wallpaper XML and dconf defaults are installed by the
# kinmin-branding RPM from the kml-branding repository.

# ==================================================
# Architecture-specific packages
# ==================================================

%pre

PKGS=/tmp/arch-packages.ks
echo > "$PKGS"

ARCH=$(uname -m)

case "$ARCH" in
    x86_64)
        echo "%packages" >> "$PKGS"
        echo "@^workstation-product-environment" >> "$PKGS"
        echo "shim" >> "$PKGS"
        echo "shim-ia32" >> "$PKGS"
        echo "grub2" >> "$PKGS"
        echo "grub2-efi" >> "$PKGS"
        echo "grub2-efi-ia32" >> "$PKGS"
        echo "grub2-efi-*-cdboot" >> "$PKGS"
        echo "efibootmgr" >> "$PKGS"
        echo "%end" >> "$PKGS"
        ;;
    aarch64)
        echo "%packages" >> "$PKGS"
        echo "efibootmgr" >> "$PKGS"
        echo "grub2-efi-aa64-cdboot" >> "$PKGS"
        echo "shim-aa64" >> "$PKGS"
        echo "%end" >> "$PKGS"
        ;;
    ppc64le)
        echo "%packages" >> "$PKGS"
        echo "powerpc-utils" >> "$PKGS"
        echo "grub2-tools" >> "$PKGS"
        echo "grub2-tools-minimal" >> "$PKGS"
        echo "grub2-tools-extra" >> "$PKGS"
        echo "grub2-ppc64le" >> "$PKGS"
        echo "%end" >> "$PKGS"
        ;;
    s390x)
        echo "%packages" >> "$PKGS"
        echo "s390utils-base" >> "$PKGS"
        echo "%end" >> "$PKGS"
        ;;
esac

%end

%include /tmp/arch-packages.ks

# ==================================================
# Main package selection
# ==================================================

%packages

livesys-scripts

anaconda
anaconda-live
anaconda-install-env-deps
@anaconda-tools

aajohan-comfortaa-fonts

kinmin-branding

dracut-config-generic
dracut-live

kernel
kernel-modules
kernel-modules-extra

glibc-all-langpacks

-@dial-up
-@input-methods
-@standard
-gfs2-utils
-gnome-boxes

%end

