%global debug_package %{nil}

Name:           kinmin-branding
Version:        1.0
Release:        1%{?dist}
Summary:        KINMIN Linux branding assets and GNOME desktop defaults

License:        Unsplash AND LicenseRef-KINMIN-AI-Generated
URL:            https://github.com/kinmin/kml

Source0:        kinmin-default.png
Source1:        marek-piwnicki-NrFhurv1N3I-unsplash.jpg
Source2:        petra-reid-W5FKbMSL8D0-unsplash.jpg
Source3:        queensland-australia--4DWT-txLSQ-unsplash.jpg
Source4:        kinmin-wallpapers.xml
Source5:        00-kinmin-background
Source6:        ASSET-ATTRIBUTION.md

BuildArch:      noarch
Requires:       dconf

%description
Installs KINMIN Linux wallpapers, the GNOME wallpaper collection and the
GNOME background dconf defaults used by KINMIN Linux 1.0.

This package intentionally does not replace /etc/dconf/profile/user. The
Fedora dconf package already enables the local system database there.

%prep
# No source extraction is required; all sources are installed directly.

%build
# Nothing to build.

%install
install -dpm 0755 %{buildroot}%{_datadir}/backgrounds/kinmin
install -Dpm 0644 %{SOURCE0} %{buildroot}%{_datadir}/backgrounds/kinmin/kinmin-default.png
install -Dpm 0644 %{SOURCE1} %{buildroot}%{_datadir}/backgrounds/kinmin/marek-piwnicki-NrFhurv1N3I-unsplash.jpg
install -Dpm 0644 %{SOURCE2} %{buildroot}%{_datadir}/backgrounds/kinmin/petra-reid-W5FKbMSL8D0-unsplash.jpg
install -Dpm 0644 %{SOURCE3} %{buildroot}%{_datadir}/backgrounds/kinmin/queensland-australia--4DWT-txLSQ-unsplash.jpg

install -Dpm 0644 %{SOURCE4} %{buildroot}%{_datadir}/gnome-background-properties/kinmin-wallpapers.xml
install -Dpm 0644 %{SOURCE5} %{buildroot}%{_sysconfdir}/dconf/db/local.d/00-kinmin-background

install -Dpm 0644 %{SOURCE6} %{buildroot}%{_datadir}/licenses/%{name}/ASSET-ATTRIBUTION.md

%post
if [ -x /usr/bin/dconf ]; then
    /usr/bin/dconf update >/dev/null 2>&1 || :
fi
exit 0

%postun
if [ -x /usr/bin/dconf ]; then
    /usr/bin/dconf update >/dev/null 2>&1 || :
fi
exit 0

%files
%license %{_datadir}/licenses/%{name}/ASSET-ATTRIBUTION.md
%dir %{_datadir}/backgrounds/kinmin
%{_datadir}/backgrounds/kinmin/kinmin-default.png
%{_datadir}/backgrounds/kinmin/marek-piwnicki-NrFhurv1N3I-unsplash.jpg
%{_datadir}/backgrounds/kinmin/petra-reid-W5FKbMSL8D0-unsplash.jpg
%{_datadir}/backgrounds/kinmin/queensland-australia--4DWT-txLSQ-unsplash.jpg
%{_datadir}/gnome-background-properties/kinmin-wallpapers.xml
%config(noreplace) %{_sysconfdir}/dconf/db/local.d/00-kinmin-background

%changelog
* Sat Nov 21 2026 KINMIN Studio <studio@kinmin.example> - 1.0-1
- Initial KINMIN Linux 1.0 branding package.
