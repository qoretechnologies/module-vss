# Copyright (C) 2026 Qore Technologies, s.r.o.
# SPDX-License-Identifier: MIT
# Use the pinned source epoch for RPM headers and installed file timestamps.
%global source_date_epoch_from_changelog 1
%global use_source_date_epoch_as_buildtime 1
%if v"%{rpmversion}" >= v"4.20"
%global build_mtime_policy clamp_to_source_date_epoch
%else
%global clamp_mtime_to_source_date_epoch 1
%endif
%bcond_without tests
%bcond_without docs
Name: qore-vss-module
Version: 1.0.0
Release: 1%{?dist}
Summary: Vehicle signal loading, validation and providers for Qore
License: MIT
URL: https://github.com/qoretechnologies/module-vss
Source0: %{name}-%{version}.tar.xz
%global _find_debuginfo_dwz_opts %{nil}
BuildRequires: cmake >= 3.21
BuildRequires: make
BuildRequires: gcc-c++
BuildRequires: qore-devel >= 3.0.0~
BuildRequires: qore-rpm-macros >= 3.0.0~
%if %{with tests}
BuildRequires: qore-misc-tools >= 3.0.0~
BuildRequires: python3
%endif
%if %{with docs}
BuildRequires: doxygen
%if 0%{?suse_version}
BuildRequires: util-linux
%else
BuildRequires: util-linux-core
%endif
%endif
%{?qore_enable_aot_post}

%description
Load Vehicle Signal Specification catalogs, validate telemetry, convert units
and integrate vehicle data with Qore data providers and processing pipelines.
Includes the VssLoader and VssDataProvider compiled modules, original sources,
provider resources and translations.

%if %{with docs}
%package doc
Summary: Vehicle signal module documentation and examples
License: MIT AND MPL-2.0
BuildArch: noarch
%description doc
API references, example tests and sample vehicle signal data for Qore's
VssLoader and VssDataProvider modules. The sample COVESA signal catalog is
licensed under MPL-2.0; the Qore module and documentation use the MIT license.
%endif

%prep
%autosetup
%build
%{?set_build_flags}
. %{_rpmconfigdir}/qore/module-env.sh
qore_set_source_prefix_maps "%{qore_debug_source_dir}"
cmake -S . -B build -G 'Unix Makefiles' \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_FLAGS_RELEASE=-DNDEBUG \
  -DCMAKE_INSTALL_PREFIX=%{_prefix} \
  -DCMAKE_SKIP_RPATH=ON -DCMAKE_IGNORE_PREFIX_PATH=/usr/local \
  -DQore_DIR=%{_libdir}/cmake/Qore -DQORE_EXECUTABLE=/usr/bin/qore \
  -DQORE_QPP_EXECUTABLE=/usr/bin/qpp -DQORE_QCC_EXECUTABLE=/usr/bin/qcc \
  -DQORE_BUILD_AOT_MODULES=ON -DQORE_AOT_LINK_SOURCE_MODULES=OFF \
  -DQORE_QM_METADATA_ENV:STRING="QORE_MODULE_DIR=$QORE_MODULE_DIR:$PWD/qlib;QORE_MODULE_DIR_ONLY=1;QORE_INCLUDE_DIR=;LD_LIBRARY_PATH=" \
  -DCMAKE_DISABLE_FIND_PACKAGE_Doxygen=%{!?with_docs:ON}%{?with_docs:OFF}
cmake --build build -- %{?_smp_mflags}
%if %{with docs}
cmake --build build --target docs -- %{?_smp_mflags}
%endif
%install
DESTDIR=%{buildroot} cmake --install build
%qore_install_aot_sources qlib
find %{buildroot}%{_libdir}/qore-modules -type f -name '*.qmod' -exec chmod 755 {} +
%if %{with docs}
install -d %{buildroot}%{_docdir}/%{name}-doc
cp -a build/docs test %{buildroot}%{_docdir}/%{name}-doc/
install -d %{buildroot}%{_licensedir}/%{name}-doc
install -m644 COPYING.MIT COPYING.MPL-2.0 %{buildroot}%{_licensedir}/%{name}-doc/
hardlink -t -O %{buildroot}%{_docdir}/%{name}-doc %{buildroot}%{_licensedir}/%{name}-doc
%endif
%check
%if %{with tests}
. %{_rpmconfigdir}/qore/module-env.sh
/usr/bin/qore -b --enable-debug -l yaml -l json -e 'exit(0);'
for test in test/*.qtest; do
  timeout 180 /usr/bin/qore -b --enable-debug \
    -l "$PWD/build/qlib-qmod/VssLoader/VssLoader.qmod" \
    -l "$PWD/build/qlib-qmod/VssDataProvider/VssDataProvider.qmod" "$test" -v
done
qore-data-provider-i18n --no-color --check-source-tree --require-standard-locales \
  --require-complete-locales --output "$PWD/qlib"
%if %{with docs}
python3 -B -W error test/test_docs.py build/docs
%endif
%endif
%files
%license COPYING.MIT
%doc README RELEASE-NOTES
%{_libdir}/qore-modules/VssLoader/
%{_libdir}/qore-modules/VssDataProvider/
%{_datadir}/qore-modules/VssLoader/
%{_datadir}/qore-modules/VssDataProvider/
%{_datadir}/qore/i18n/
%if %{with docs}
%files doc
%license %{_licensedir}/%{name}-doc/
%doc %{_docdir}/%{name}-doc/
%endif
%changelog
* Thu Oct 01 2026 David Nichols <david@qore.org> - 1.0.0-1
- Package compiled modules, sources, catalogs, documentation and offline tests.
