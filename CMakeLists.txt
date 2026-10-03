cmake_minimum_required(VERSION 3.5...3.31)

project(qore-vss-module)

set(VERSION_MAJOR 1)
set(VERSION_MINOR 0)
set(VERSION_PATCH 0)
set(PROJECT_VERSION "${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH}")

# Resolve API links to bundled Qore modules from the installed SDK.
set(QORE_DOXYGEN_MODULES DataProvider reflection json yaml)
find_package(Qore 2.0 REQUIRED)

set(QMOD
    qlib/VssLoader
    qlib/VssDataProvider
)

# create docs targets needed by qore_external_user_module
add_custom_target(docs)
add_custom_target(docs-module)

qore_user_modules("${QMOD}")

set(QORE_DOXYGEN_IMAGES "${CMAKE_SOURCE_DIR}/qlib/VssDataProvider/vss-logo.svg")
qore_external_user_module("qlib/VssLoader" "")
qore_external_user_module("qlib/VssDataProvider" "VssLoader")

# Reconcile the installed i18n catalog root against the fragments these modules
# currently own.  Installing catalogs is otherwise additive: a fragment installed by
# an earlier generation of these sources survives every later install, is still
# discovered, and makes catalog composition fail as soon as the current generation
# describes the same app differently.
#
# This must come after every call above that installs catalogs, both because those
# calls record the fragment set and because install() rules run in declaration order,
# which is what publishes the manifest after the fragments it describes.  Removals are
# scoped to this project, so fragments Qore and other products install into the same
# shared catalog root are untouched.  Guarded because the helper arrived in Qore 2.3.
if (COMMAND qore_finalize_catalog_install)
    qore_finalize_catalog_install()
endif()

qore_dist("${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH}")

qore_config_info()

if (DOXYGEN_FOUND)
    set(QORE_DOX_TMPL_SRC
        docs/mainpage.dox.tmpl
        docs/guide-vssexamples.dox.tmpl
        docs/guide-vssreleasenotes.dox.tmpl
    )
    qore_wrap_dox(QORE_DOX_SRC ${QORE_DOX_TMPL_SRC})
    add_custom_target(QORE_MOD_DOX_FILES DEPENDS ${QORE_DOX_SRC})
    add_dependencies(docs-module QORE_MOD_DOX_FILES)
    # Use the same SDK template and assets as the companion-module API pages.
    # The local wrapper adds the overview title and license without replacing
    # the shared stylesheet, header, favicon, or cross-reference indexes.
    set(module_name vss)
    set(CURRENT_MODULE_NAME vss)
    set(_dox_output "${CMAKE_BINARY_DIR}/docs/vss")
    set(_dox_input "")
    foreach(_source IN LISTS QORE_DOX_SRC)
        string(APPEND _dox_input " \"${_source}\"")
    endforeach()
    set(TAGFILES "")
    qore_configure_module_doxygen("${QORE_USERMODULE_DOXYGEN_TEMPLATE}"
        "${CMAKE_BINARY_DIR}/doxygen/Doxyfile.vss")
    configure_file("${CMAKE_SOURCE_DIR}/docs/Doxyfile.in" "${CMAKE_BINARY_DIR}/Doxyfile" @ONLY)
    add_custom_target(docs-overview
        COMMAND "${DOXYGEN_EXECUTABLE}" "${CMAKE_BINARY_DIR}/Doxyfile"
        WORKING_DIRECTORY "${CMAKE_BINARY_DIR}"
        DEPENDS QORE_MOD_DOX_FILES
        VERBATIM)
    add_dependencies(docs-module docs-overview)
    qore_binary_module_two_phase_docs(vss "VssLoader;VssDataProvider")
endif()
