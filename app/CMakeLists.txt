# Tinc Mesh VPN: Android client and user interface
# Copyright (C) 2017-2022 Euxane P. TRAN-GIRARD
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

# Builds the tinc daemon and control program bundled with the app.
#
# The upstream project builds with autotools; the tinc revision tracked here
# (see ../.gitmodules) is built by Meson instead, and adds a WebSocket
# metadata transport backed by wslay. Rather than pull another build system
# into the Android build, the sources are compiled directly: the source lists
# below mirror what `meson setup -Dcrypto=nolegacy -Dwebsocket=enabled ...`
# compiles, and src/main/c/tinc-config/config.h carries the feature detection
# Meson would have produced.
#
# tinc and tincd are executables, but Android only packages shared objects
# into the application's native library directory -- the one place the app can
# execute them from. They are therefore copied to libtinc.so/libtincd.so, as
# the previous autotools-based build did.

cmake_minimum_required(VERSION 3.22)

project(tincapp-native C)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)

set(TINC_DIR "${CMAKE_CURRENT_SOURCE_DIR}/src/main/c/tinc")
set(TINC_CONFIG_DIR "${CMAKE_CURRENT_SOURCE_DIR}/src/main/c/tinc-config")

if(NOT EXISTS "${TINC_DIR}/src/meta_ws.c")
  message(FATAL_ERROR
    "The tinc submodule is missing or out of date.\n"
    "Run: git submodule update --init --recursive")
endif()

# The Android Gradle plugin points this at the per-ABI obj directory that gets
# packaged into the APK; the fallback keeps a standalone CMake run usable.
if(NOT CMAKE_LIBRARY_OUTPUT_DIRECTORY)
  set(CMAKE_LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib")
endif()

include("${CMAKE_CURRENT_SOURCE_DIR}/cmake/wslay.cmake")

# version.c includes version_git.h, which Meson fills in from `git describe`.
set(TINC_VERSION_STRING "1.1-ws.3" CACHE STRING "Build version reported by tinc")
file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/version_git.h"
  "#define GIT_DESCRIPTION \"${TINC_VERSION_STRING}\"\n")

# --- tinc sources ------------------------------------------------------------
# Mirrors src/meson.build. `-Dcrypto=nolegacy` replaces the OpenSSL backend
# with the bundled Ed25519 and ChaCha20-Poly1305 implementations, so neither
# cipher.c/digest.c (legacy RSA/AES) nor any external crypto library is needed.

set(TINC_SRC "${TINC_DIR}/src")

set(TINC_COMMON_SOURCES
  "${TINC_SRC}/conf.c"
  "${TINC_SRC}/console.c"
  "${TINC_SRC}/dropin.c"
  "${TINC_SRC}/fs.c"
  "${TINC_SRC}/keys.c"
  "${TINC_SRC}/list.c"
  "${TINC_SRC}/logger.c"
  "${TINC_SRC}/names.c"
  "${TINC_SRC}/netutl.c"
  "${TINC_SRC}/pidfile.c"
  "${TINC_SRC}/random.c"
  "${TINC_SRC}/sandbox.c"
  "${TINC_SRC}/script.c"
  "${TINC_SRC}/splay_tree.c"
  "${TINC_SRC}/sptps.c"
  "${TINC_SRC}/subnet_parse.c"
  "${TINC_SRC}/utils.c"
  "${TINC_SRC}/version.c"
  "${TINC_SRC}/xoshiro.c"
  # crypto backend: nolegacy
  "${TINC_SRC}/nolegacy/crypto.c"
  "${TINC_SRC}/nolegacy/prf.c"
  # bundled ChaCha20-Poly1305 AEAD
  "${TINC_SRC}/chacha-poly1305/chacha-poly1305.c"
  "${TINC_SRC}/chacha-poly1305/chacha.c"
  "${TINC_SRC}/chacha-poly1305/poly1305.c"
  # bundled Ed25519
  "${TINC_SRC}/ed25519/ecdh.c"
  "${TINC_SRC}/ed25519/ecdsa.c"
  "${TINC_SRC}/ed25519/ecdsagen.c"
  "${TINC_SRC}/ed25519/fe.c"
  "${TINC_SRC}/ed25519/ge.c"
  "${TINC_SRC}/ed25519/key_exchange.c"
  "${TINC_SRC}/ed25519/keypair.c"
  "${TINC_SRC}/ed25519/sc.c"
  "${TINC_SRC}/ed25519/sha512.c"
  "${TINC_SRC}/ed25519/sign.c"
  "${TINC_SRC}/ed25519/verify.c")

set(TINC_CLI_SOURCES
  "${TINC_SRC}/fsck.c"
  "${TINC_SRC}/ifconfig.c"
  "${TINC_SRC}/info.c"
  "${TINC_SRC}/invitation.c"
  "${TINC_SRC}/top.c"
  "${TINC_SRC}/tincctl.c")

set(TINCD_SOURCES
  "${TINC_SRC}/address_cache.c"
  "${TINC_SRC}/autoconnect.c"
  "${TINC_SRC}/buffer.c"
  "${TINC_SRC}/conf_net.c"
  "${TINC_SRC}/connection.c"
  "${TINC_SRC}/control.c"
  "${TINC_SRC}/dummy_device.c"
  "${TINC_SRC}/edge.c"
  "${TINC_SRC}/event.c"
  "${TINC_SRC}/fd_device.c"
  "${TINC_SRC}/graph.c"
  "${TINC_SRC}/meta.c"
  "${TINC_SRC}/meta_ws.c"
  "${TINC_SRC}/multicast_device.c"
  "${TINC_SRC}/net.c"
  "${TINC_SRC}/net_packet.c"
  "${TINC_SRC}/net_setup.c"
  "${TINC_SRC}/net_socket.c"
  "${TINC_SRC}/node.c"
  "${TINC_SRC}/process.c"
  "${TINC_SRC}/protocol.c"
  "${TINC_SRC}/protocol_auth.c"
  "${TINC_SRC}/protocol_edge.c"
  "${TINC_SRC}/protocol_key.c"
  "${TINC_SRC}/protocol_misc.c"
  "${TINC_SRC}/protocol_subnet.c"
  "${TINC_SRC}/proxy.c"
  "${TINC_SRC}/raw_socket_device.c"
  "${TINC_SRC}/route.c"
  "${TINC_SRC}/signal.c"
  "${TINC_SRC}/subnet.c"
  # platform-specific
  "${TINC_SRC}/linux/device.c"
  "${TINC_SRC}/linux/event.c"
  "${TINC_SRC}/tincd.c")

# --- build -------------------------------------------------------------------

# config.h (committed) and version_git.h (generated above) live outside the
# tinc sources, so they are searched before the submodule's own directories.
set(TINC_INCLUDE_DIRS
  "${TINC_CONFIG_DIR}"
  "${CMAKE_CURRENT_BINARY_DIR}"
  "${WSLAY_INCLUDES}")

set(TINC_COMPILE_DEFINITIONS
  _GNU_SOURCE
  _FILE_OFFSET_BITS=64
  # wslay headers expect these to come from its generate-a-config.h step,
  # which is skipped; Android is always little-endian, so WORDS_BIGENDIAN
  # stays undefined.
  HAVE_ARPA_INET_H
  HAVE_NETINET_IN_H
  WSLAY_VERSION="${WSLAY_VERSION}")

add_library(tinc_common STATIC ${TINC_COMMON_SOURCES})
target_include_directories(tinc_common PUBLIC ${TINC_INCLUDE_DIRS})
target_compile_definitions(tinc_common PUBLIC ${TINC_COMPILE_DEFINITIONS})

# Android 15 and later require every program in an APK to work with 16 KiB
# pages. lld only aligns load segments to the page size reported by the NDK
# toolchain, which is 4 KiB up to NDK r27, so ask for it explicitly.
set(TINC_LINK_OPTIONS -Wl,-z,max-page-size=16384)

add_executable(tinc_bin ${TINC_CLI_SOURCES})
target_link_libraries(tinc_bin PRIVATE tinc_common)
target_link_options(tinc_bin PRIVATE ${TINC_LINK_OPTIONS})

add_executable(tincd_bin ${TINCD_SOURCES} ${WSLAY_SOURCES})
target_link_libraries(tincd_bin PRIVATE tinc_common m)
target_link_options(tincd_bin PRIVATE ${TINC_LINK_OPTIONS})

# Empty library carried over from the previous build (src/main/c/main.c is a
# placeholder). Nothing links against it; it is kept so the Android Gradle
# plugin's external native build still has a library target of its own.
add_library(main SHARED src/main/c/main.c)

add_custom_command(TARGET tinc_bin POST_BUILD
  COMMAND "${CMAKE_COMMAND}" -E copy_if_different
    "$<TARGET_FILE:tinc_bin>"
    "${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/libtinc.so"
  COMMENT "Installing libtinc.so")

add_custom_command(TARGET tincd_bin POST_BUILD
  COMMAND "${CMAKE_COMMAND}" -E copy_if_different
    "$<TARGET_FILE:tincd_bin>"
    "${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/libtincd.so"
  COMMENT "Installing libtincd.so")
