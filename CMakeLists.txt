cmake_minimum_required(VERSION 3.5)

project(qore-vss-module)

set(VERSION_MAJOR 1)
set(VERSION_MINOR 0)
set(VERSION_PATCH 0)
set(PROJECT_VERSION "${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH}")

find_package(Qore 2.0 REQUIRED)

set(QMOD
    qlib/VssLoader
    qlib/VssDataProvider
    qlib/VssDataProcessors
)

# create docs targets needed by qore_external_user_module
add_custom_target(docs)
add_custom_target(docs-module)

qore_user_modules("${QMOD}")

qore_external_user_module("qlib/VssLoader" "")
qore_external_user_module("qlib/VssDataProvider" "VssLoader")
qore_external_user_module("qlib/VssDataProcessors" "VssLoader")

qore_dist("${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH}")

qore_config_info()

if (DOXYGEN_FOUND)
    set(QORE_DOX_TMPL_SRC
        docs/mainpage.dox.tmpl
    )
    qore_wrap_dox(QORE_DOX_SRC ${QORE_DOX_TMPL_SRC})
    add_custom_target(QORE_MOD_DOX_FILES DEPENDS ${QORE_DOX_SRC})
    add_dependencies(docs-module QORE_MOD_DOX_FILES)
endif()
