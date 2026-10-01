RPM packaging
=============

Copyright 2026 Qore Technologies, s.r.o.

qore-vss-module.spec targets Fedora, Enterprise Linux and openSUSE with the
Qore 3.0 SDK and qore-rpm-macros. Both VssLoader and VssDataProvider are compiled
with qcc; RPM post-processing preserves their dependency trailers and produces
separate debug packages. Source fallbacks and provider catalogs are included.
The SDK must include the pure Qore module and bundled index documentation fixes
(a5611da13 and d534c4b1c).

From the qore-packaging repository, prepare and build a pinned source bundle::

    python3 tools/packaging.py prepare --repo ../module-vss --ref COMMIT \
      --name qore-vss-module --version 1.0.0 \
      --spec qore-vss-module.spec --output work/vss-source
    python3 tools/build-local.py --source work/vss-source \
      --image TARGET_SDK_IMAGE --output results/vss-build --jobs 2

Builds run offline and execute all seven Qore test files with debugging enabled,
plus complete translation catalog checks. YAML and JSON support must be present.
After installing the resulting runtime RPM in a clean container, run
rpm/tests-installed/runtime from the source checkout; it copies the tests into
a temporary directory and explicitly loads the installed AOT modules.

The documentation package includes HTML references, tests and sample data.
The module uses MIT; the bundled COVESA test catalog uses MPL-2.0 and its license
is included in the documentation package. --without docs and --without tests
are available for diagnosis; repository qualification uses both defaults.
