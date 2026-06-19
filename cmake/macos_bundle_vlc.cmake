# cmake/macos_bundle_vlc.cmake
#
# Invoked as a POST_BUILD cmake -P script to copy LibVLC dylibs and plugins
# into the macOS .app bundle and rewrite their embedded install names so the
# bundle is fully self-contained (no external VLC installation required).
#
# Required variables (passed via -D on the command line):
#   APP_BUNDLE   - absolute path to the .app bundle, e.g. /path/to/openkj.app
#   VLC_SDK_PATH - path to the VLC SDK / MacOS directory that contains
#                  lib/ (with libvlc.dylib) and plugins/
#
# Usage from CMakeLists.txt:
#   add_custom_command(TARGET openkj POST_BUILD
#     COMMAND ${CMAKE_COMMAND}
#       -DAPP_BUNDLE=$<TARGET_BUNDLE_DIR:openkj>
#       -DVLC_SDK_PATH=${LIBVLC_SDK_PATH}
#       -P ${CMAKE_SOURCE_DIR}/cmake/macos_bundle_vlc.cmake
#   )

cmake_minimum_required(VERSION 3.14)

if(NOT APP_BUNDLE)
    message(FATAL_ERROR "macos_bundle_vlc.cmake: APP_BUNDLE must be set")
endif()
if(NOT VLC_SDK_PATH)
    message(FATAL_ERROR "macos_bundle_vlc.cmake: VLC_SDK_PATH must be set")
endif()

set(FRAMEWORKS_DIR "${APP_BUNDLE}/Contents/Frameworks")
set(PLUGINS_DIR    "${APP_BUNDLE}/Contents/MacOS/plugins")
set(VLC_LIB_DIR    "${VLC_SDK_PATH}/lib")
set(VLC_PLUGINS_DIR "${VLC_SDK_PATH}/plugins")

# ---------------------------------------------------------------------------
# 1. Copy the two core VLC dylibs into Contents/Frameworks/
# ---------------------------------------------------------------------------
message(STATUS "[vlc-bundle] Copying VLC dylibs into ${FRAMEWORKS_DIR}")
file(MAKE_DIRECTORY "${FRAMEWORKS_DIR}")

foreach(DYLIB libvlc.dylib libvlccore.dylib)
    set(SRC "${VLC_LIB_DIR}/${DYLIB}")
    if(EXISTS "${SRC}")
        file(COPY "${SRC}" DESTINATION "${FRAMEWORKS_DIR}")
        message(STATUS "[vlc-bundle]   Copied ${DYLIB}")
    else()
        message(WARNING "[vlc-bundle]   Not found: ${SRC} — skipping")
    endif()
endforeach()

# Also copy any versioned symlink targets (e.g. libvlc.5.dylib)
file(GLOB VLC_VERSIONED_DYLIBS "${VLC_LIB_DIR}/libvlc*.dylib")
foreach(DYLIB ${VLC_VERSIONED_DYLIBS})
    get_filename_component(DYLIB_NAME "${DYLIB}" NAME)
    if(NOT DYLIB_NAME STREQUAL "libvlc.dylib" AND NOT DYLIB_NAME STREQUAL "libvlccore.dylib")
        file(COPY "${DYLIB}" DESTINATION "${FRAMEWORKS_DIR}")
        message(STATUS "[vlc-bundle]   Copied versioned ${DYLIB_NAME}")
    endif()
endforeach()

# ---------------------------------------------------------------------------
# 2. Copy the VLC plugins directory into Contents/MacOS/plugins/
# ---------------------------------------------------------------------------
if(EXISTS "${VLC_PLUGINS_DIR}")
    message(STATUS "[vlc-bundle] Copying VLC plugins into ${PLUGINS_DIR}")
    file(MAKE_DIRECTORY "${PLUGINS_DIR}")
    file(COPY "${VLC_PLUGINS_DIR}/" DESTINATION "${PLUGINS_DIR}")
    file(GLOB PLUGIN_COUNT "${PLUGINS_DIR}/*.dylib")
    list(LENGTH PLUGIN_COUNT PLUGIN_COUNT_N)
    message(STATUS "[vlc-bundle]   Copied ${PLUGIN_COUNT_N} plugins")
else()
    message(WARNING "[vlc-bundle] VLC plugins dir not found: ${VLC_PLUGINS_DIR}")
endif()

# ---------------------------------------------------------------------------
# 3. Rewrite @rpath install names in all copied dylibs and plugins
#    so they resolve inside the bundle using @loader_path.
# ---------------------------------------------------------------------------
message(STATUS "[vlc-bundle] Rewriting install names...")

# Collect all dylibs to fix: frameworks + plugins
file(GLOB_RECURSE ALL_DYLIBS
    "${FRAMEWORKS_DIR}/*.dylib"
    "${PLUGINS_DIR}/*.dylib"
)

# The two dylibs we own — rewrite their own id first
set(VLC_FRAMEWORK_LOADER_PATH "@loader_path/../Frameworks")
set(VLC_PLUGINS_LOADER_PATH   "@loader_path/../../Frameworks")

foreach(DYLIB_PATH ${ALL_DYLIBS})
    get_filename_component(DYLIB_NAME "${DYLIB_PATH}" NAME)

    # Determine the correct @loader_path base depending on location
    if("${DYLIB_PATH}" MATCHES "Contents/Frameworks")
        set(LOADER_REF "@loader_path")
    else()
        # Plugin dylibs reference frameworks two levels up
        set(LOADER_REF "@loader_path/../../Frameworks")
    endif()

    # Rewrite the dylib's own id
    execute_process(
        COMMAND install_name_tool -id "@rpath/${DYLIB_NAME}" "${DYLIB_PATH}"
        RESULT_VARIABLE RES
    )

    # Rewrite references to libvlc and libvlccore
    foreach(VLC_LIB libvlc.dylib libvlccore.dylib)
        # Try common rpath / absolute patterns that VLC uses
        foreach(OLD_REF
            "@rpath/${VLC_LIB}"
            "@executable_path/../MacOS/lib/${VLC_LIB}"
            "@executable_path/lib/${VLC_LIB}"
        )
            execute_process(
                COMMAND install_name_tool
                    -change "${OLD_REF}"
                    "${LOADER_REF}/${VLC_LIB}"
                    "${DYLIB_PATH}"
                RESULT_VARIABLE RES
                ERROR_QUIET
            )
        endforeach()
    endforeach()
endforeach()

# ---------------------------------------------------------------------------
# 4. Rewrite the main executable's references to libvlc / libvlccore
# ---------------------------------------------------------------------------
file(GLOB MAIN_EXEC "${APP_BUNDLE}/Contents/MacOS/openkj")
if(NOT MAIN_EXEC)
    # fallback: glob any non-dylib binary
    file(GLOB MAIN_EXEC "${APP_BUNDLE}/Contents/MacOS/*")
endif()

foreach(EXEC ${MAIN_EXEC})
    if(NOT "${EXEC}" MATCHES "\\.dylib$" AND NOT IS_DIRECTORY "${EXEC}")
        message(STATUS "[vlc-bundle] Fixing rpath in executable: ${EXEC}")
        # Add rpath pointing to Frameworks
        execute_process(
            COMMAND install_name_tool -add_rpath "@executable_path/../Frameworks" "${EXEC}"
            RESULT_VARIABLE RES ERROR_QUIET
        )
        foreach(VLC_LIB libvlc.dylib libvlccore.dylib)
            foreach(OLD_REF
                "@rpath/${VLC_LIB}"
                "/Applications/VLC.app/Contents/MacOS/lib/${VLC_LIB}"
            )
                execute_process(
                    COMMAND install_name_tool
                        -change "${OLD_REF}"
                        "@rpath/${VLC_LIB}"
                        "${EXEC}"
                    ERROR_QUIET
                )
            endforeach()
        endforeach()
    endif()
endforeach()

message(STATUS "[vlc-bundle] Done. Bundle is self-contained.")
