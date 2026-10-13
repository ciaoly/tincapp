# Tinc Mesh VPN: Android client and user interface
#
# Fetches wslay, the WebSocket library used by tinc's WebSocket metadata
# transport (MetaTransport = websocket), and exposes its sources for direct
# compilation into libtincd.so.
#
# wslay ships its own build systems (autotools, CMake); neither is used here
# because its CMake build declares cmake_minimum_required(VERSION 2.8), whose
# policy settings break the Android NDK toolchain. The library is only four
# translation units, so they are compiled directly instead.
#
# The tarball is fetched once into a cache shared by all ABIs. On networks that
# need a proxy, set https_proxy (and http_proxy) in the environment before
# running Gradle; CMake's downloader honours them.
#
# Defines:
#   WSLAY_SOURCES   - sources to compile
#   WSLAY_INCLUDES  - include directories for wslay/wslay.h

set(WSLAY_VERSION 1.1.1)
set(WSLAY_URL
  "https://github.com/tatsuhiro-t/wslay/releases/download/release-${WSLAY_VERSION}/wslay-${WSLAY_VERSION}.tar.gz")
set(WSLAY_SHA256 90ce68c6dfd614722d44fbb14563a3f6dacc68b548b20ae382ac4f4952c55268)

set(WSLAY_CACHE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/.cxx/wslay")
set(WSLAY_SRC_DIR "${WSLAY_CACHE_DIR}/wslay-${WSLAY_VERSION}")

file(MAKE_DIRECTORY "${WSLAY_CACHE_DIR}")

# Several ABIs are configured concurrently by the Android Gradle plugin; the
# lock keeps them from unpacking the archive on top of each other.
file(LOCK "${WSLAY_CACHE_DIR}/wslay.lock" TIMEOUT 600)

if(NOT EXISTS "${WSLAY_SRC_DIR}/lib/wslay_event.c")
  set(WSLAY_ARCHIVE "${WSLAY_CACHE_DIR}/wslay-${WSLAY_VERSION}.tar.gz")

  if(NOT EXISTS "${WSLAY_ARCHIVE}")
    message(STATUS "Downloading wslay ${WSLAY_VERSION}")
    file(DOWNLOAD "${WSLAY_URL}" "${WSLAY_ARCHIVE}"
      EXPECTED_HASH SHA256=${WSLAY_SHA256}
      TLS_VERIFY ON
      STATUS wslay_download_status)
    list(GET wslay_download_status 0 wslay_download_code)

    if(NOT wslay_download_code EQUAL 0)
      list(GET wslay_download_status 1 wslay_download_message)
      file(REMOVE "${WSLAY_ARCHIVE}")
      message(FATAL_ERROR
        "Could not download wslay ${WSLAY_VERSION}: ${wslay_download_message}\n"
        "Set https_proxy/http_proxy if this network requires a proxy, or place the\n"
        "tarball at ${WSLAY_ARCHIVE} manually.")
    endif()
  endif()

  file(ARCHIVE_EXTRACT INPUT "${WSLAY_ARCHIVE}" DESTINATION "${WSLAY_CACHE_DIR}")
endif()

file(LOCK "${WSLAY_CACHE_DIR}/wslay.lock" RELEASE)

if(NOT EXISTS "${WSLAY_SRC_DIR}/lib/wslay_event.c")
  message(FATAL_ERROR "wslay sources not found in ${WSLAY_SRC_DIR}")
endif()

set(WSLAY_SOURCES
  "${WSLAY_SRC_DIR}/lib/wslay_event.c"
  "${WSLAY_SRC_DIR}/lib/wslay_frame.c"
  "${WSLAY_SRC_DIR}/lib/wslay_net.c"
  "${WSLAY_SRC_DIR}/lib/wslay_queue.c")

set(WSLAY_INCLUDES "${WSLAY_SRC_DIR}/lib/includes")
