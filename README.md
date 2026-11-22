# KINMIN Linux

KINMIN Linux 1.0 is a Fedora Workstation 44 derived x86_64 live system built with
Lorax, `livemedia-creator` and Kickstart. The default desktop is GNOME.

This repository currently contains the source assets, Kickstart file and helper
scripts. No ISO has been built yet.

## Repository layout

```text
branding/wallpapers/        KINMIN wallpapers
branding/rpm/               kinmin-branding RPM spec
config/backgrounds/         GNOME wallpaper collection XML
config/dconf/               KINMIN dconf defaults
kickstart/kml.ks            main Kickstart file
licenses/                   third-party license information
output/                     generated RPMs, repository metadata and ISO output
scripts/                    build helpers
```

## Branding delivery model

Wallpapers, the GNOME wallpaper XML and the dconf default are installed by the
`kinmin-branding` RPM. They are no longer copied from a host path in a Kickstart
`%post --nochroot` script.

The package installs:

- `/usr/share/backgrounds/kinmin/`
- `/usr/share/gnome-background-properties/kinmin-wallpapers.xml`
- `/etc/dconf/db/local.d/00-kinmin-background`
- `/usr/share/licenses/kinmin-branding/ASSET-ATTRIBUTION.md`

It intentionally does not replace `/etc/dconf/profile/user`. The Fedora `dconf`
package already enables `system-db:local` in that profile. The RPM scriptlet
runs `dconf update` after installation and removal.

## Prerequisites

Install the following on the build host before building the ISO:

- `rpm-build`
- `rpm`
- `python3`
- `createrepo_c` or `createrepo` is optional; the repository builder has a
  standard-library fallback
- Lorax and `livemedia-creator`
- KVM/QEMU and OVMF firmware
- network access to the Fedora 44 Everything repository from the QEMU guest

## Build the branding RPM and repository

```bash
./scripts/build-branding-rpm.sh
```

This creates:

```text
output/rpmbuild/            rpmbuild work tree
output/repo/                RPMs and DNF repository metadata
```

Version and release can be overridden:

```bash
KML_BRANDING_VERSION=1.0 KML_BRANDING_RELEASE=1 ./scripts/build-branding-rpm.sh
```

## Embed the repository into the boot ISO

The QEMU guest cannot reliably reach a repository served from the build host
through user-mode networking. The generated repository is therefore added
directly to the boot ISO at `/repo`.

```bash
./scripts/add-branding-repo-to-iso.sh
```

This creates:

```text
output/Fedora-Everything-netinst-x86_64-44-1.7-kml.iso
```

`kickstart/kml.ks` reads the embedded repository from:

```text
file:///run/install/repo/repo/
```

No HTTP repository server is required for the custom RPM.

## Build the live ISO

After the branded boot ISO has been created, run `livemedia-creator` from the
project root. Use QEMU virtualization; do not pass `--no-virt`.

Example template:

```bash
sudo livemedia-creator \
    --make-iso \
    --iso output/Fedora-Everything-netinst-x86_64-44-1.7-kml.iso \
    --ks kickstart/kml.ks \
    --resultdir output/lmc-result \
    --logfile output/livemedia-creator.log \
    --releasever 44 \
    --volid KML-1-0 \
    --project "KINMIN Linux" \
    --timeout 240
```

Download `Fedora-Everything-netinst-x86_64-44-1.7.iso` into `output/`, then run
`scripts/add-branding-repo-to-iso.sh` before `livemedia-creator`. The
`--resultdir` path must not exist before the build; `livemedia-creator` creates
it. The command must run as root.

The first successful live ISO is:

```text
output/lmc-result/images/boot.iso
```

The current release ISO is:

```text
output/KINMIN-Linux-1.0-x86_64.iso
```

It is based on the original successful ISO with its unmodified squashfs and
SELinux xattrs. Only the GRUB configuration was updated to select the first menu
entry and pass `systemd.unit=graphical.target` on the kernel command line.
This avoids repacking the root filesystem, which would drop SELinux labels on
this host.

Future full builds get the graphical default from `kickstart/kml.ks` via
`systemctl set-default graphical.target`.

## Validation

The following checks are safe and can be run without booting an installer:

```bash
ksvalidator --version F44 kickstart/kml.ks
rpmspec -P branding/rpm/kinmin-branding.spec >/dev/null
xmllint --noout config/backgrounds/kinmin-wallpapers.xml
bash -n scripts/build-branding-rpm.sh
bash -n scripts/serve-branding-repo.sh
bash -n scripts/add-branding-repo-to-iso.sh
```

`ksvalidator` only validates Kickstart syntax. It does not prove that the
network works, packages resolve, Anaconda completes or the final ISO boots.

## Known constraints

- `scripts/branding.sh` edits `/usr/lib/os-release` and `/etc` directly. Do not
  run it on the build host. It is not used by the Kickstart build path.
- The installer repository is unsigned. Anaconda's DNF payload currently has
  package GPG checking disabled by default, but signing should be added before
  public releases.
- The Fedora repositories used by the installer still require network access
  from the QEMU guest. The KINMIN branding repository itself is embedded in
  the boot ISO and does not require TCP port 8000.
- The Kickstart uses a 12 GiB root partition. Smaller values caused the RPM
  transaction to fail with "needs NMB more space on the / filesystem".
- The Fedora 44 Anaconda configuration distinguishes `physical_root` and
  `system_root`. Any future `%post` scripts must be validated against real
  installer logs before relying on those paths.
