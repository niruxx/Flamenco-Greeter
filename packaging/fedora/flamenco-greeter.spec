Name:           flamenco-greeter
Version:        0.4.0
Release:        1%{?dist}
Summary:        greetd login screen for Flamenco Shell
License:        Unknown
URL:            https://github.com/niruxx/Flamenco-Greeter
Source0:        %{name}-%{version}.tar.gz
BuildArch:      noarch
BuildRequires:  make
Requires:       greetd
Requires:       python3 >= 3.11
Requires:       qt6-qtdeclarative
Requires:       quickshell
Requires(post): systemd
Requires(post): systemd-sysusers
Suggests:       flamenco-shell
Suggests:       (niri or hyprland or sway)
Suggests:       fprintd-pam
Suggests:       qt6-qtmultimedia
Suggests:       upower

%description
Flamenco Greeter is a Quickshell login screen for greetd. It reuses the
installed Flamenco Shell theme, widgets, and assets. Install Flamenco Shell
system-wide under /usr for the greeter to find its QML components.

%prep
%setup -q -c

%install
make install DESTDIR="%{buildroot}" PREFIX=%{_prefix}
sed -i '1c#!%{_bindir}/python3' "%{buildroot}%{_bindir}/%{name}"

%post
%{_bindir}/systemd-sysusers %{name}.conf &&
    %{_bindir}/systemd-tmpfiles --create %{name}.conf

%files
%{_bindir}/%{name}
%{_datadir}/%{name}/
%{_prefix}/lib/sysusers.d/%{name}.conf
%{_prefix}/lib/tmpfiles.d/%{name}.conf
%{_prefix}/lib/systemd/user/%{name}-sync.path
%{_prefix}/lib/systemd/user/%{name}-sync.service
