#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOC_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
WORKSPACE_DIR="$(cd "${DOC_DIR}/.." && pwd)"
HONEY_DIR="${WORKSPACE_DIR}/HoneyTea"
LEMON_DIR="${WORKSPACE_DIR}/LemonTea"
STAGE_DIR="${DOC_DIR}/.build-release"
RELEASE_DIR="${WORKSPACE_DIR}/release"
GENERATED_TOOLCHAIN_DIR="${STAGE_DIR}/toolchains"
BREW_CACHE_DIR="${HOME}/Library/Caches/Homebrew/downloads"

BUILD_TYPE="Release"
BUILD_HONEY_RPI=false
BUILD_LEMON_MACOS=false
BUILD_LEMON_LINUX=false
CLEAN=false
HONEY_RPI_TOOLCHAIN=""
LEMON_LINUX_TOOLCHAIN=""
BOOTSTRAP=true

AARCH64_FORMULA="aarch64-unknown-linux-gnu"
X64_FORMULA="x86_64-unknown-linux-gnu"
OPENSSL_FORMULA="openssl@3"
ASIO_FORMULA="asio"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/build_release.sh [options]

Options:
  --build-honey-rpi                 Build HoneyTea for Raspberry Pi arm64
  --build-lemon-macos              Build LemonTea for native macOS
  --build-lemon-linux              Build LemonTea for Linux x64 cross target
  --honey-rpi-toolchain PATH       CMake toolchain file for Raspberry Pi arm64 build
  --lemon-linux-toolchain PATH     CMake toolchain file for Linux x64 cross build
  --build-type TYPE                CMake build type, default: Release
  --skip-bootstrap                 Skip brew bootstrap and dependency preparation
  --clean                          Remove .build-release before building
  -h, --help                       Show this help message

Examples:
  ./scripts/build_release.sh
  ./scripts/build_release.sh --build-lemon-macos
  ./scripts/build_release.sh \
    --build-honey-rpi \
    --honey-rpi-toolchain /abs/path/rpi-aarch64-gcc.cmake
  ./scripts/build_release.sh \
    --build-honey-rpi \
    --build-lemon-macos \
    --build-lemon-linux \
    --honey-rpi-toolchain /abs/path/rpi-aarch64-gcc.cmake \
    --lemon-linux-toolchain /abs/path/linux-x64-gcc.cmake
EOF
}

log() {
  printf '[build_release] %s\n' "$*"
}

fail() {
  printf '[build_release] ERROR: %s\n' "$*" >&2
  exit 1
}

require_command() {
  local command_name="$1"
  command -v "${command_name}" >/dev/null 2>&1 || fail "missing required command: ${command_name}"
}

require_file() {
  local file_path="$1"
  [[ -f "${file_path}" ]] || fail "required file not found: ${file_path}"
}

brew_prefix() {
  brew --prefix "$1"
}

ensure_brew_formula() {
  local formula="$1"
  if brew list --versions "${formula}" >/dev/null 2>&1; then
    return
  fi
  log "installing brew formula ${formula}"
  brew install "${formula}"
}

ensure_brew_source_tarball() {
  local formula="$1"
  local pattern="$2"
  brew fetch --build-from-source "${formula}" >/dev/null
  local tarball
  tarball="$(find "${BREW_CACHE_DIR}" -maxdepth 1 -type f -name "${pattern}" | sort | tail -n 1)"
  [[ -n "${tarball}" ]] || fail "unable to locate source tarball for ${formula}"
  printf '%s\n' "${tarball}"
}

toolchain_root_for_formula() {
  local formula="$1"
  printf '%s/toolchain\n' "$(brew_prefix "${formula}")"
}

sysroot_for_formula() {
  local formula="$1"
  local triple="$2"
  printf '%s/%s/sysroot\n' "$(toolchain_root_for_formula "${formula}")" "${triple}"
}

openssl_present_in_sysroot() {
  local sysroot="$1"
  find "${sysroot}/usr" -type f \( -name 'libcrypto.a' -o -name 'libcrypto.so' -o -name 'libcrypto.so.3' \) | grep -q .
}

generate_gcc_toolchain_file() {
  local file_path="$1"
  local toolchain_root="$2"
  local target_triple="$3"
  local target_arch="$4"
  local extra_lines="$5"

  cat > "${file_path}" <<EOF
cmake_minimum_required(VERSION 3.20)

set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR ${target_arch})
set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)

set(TOOLCHAIN_ROOT "${toolchain_root}" CACHE PATH "Brew cross toolchain root")
set(TARGET_TRIPLE "${target_triple}" CACHE STRING "Target triple")
set(TARGET_SYSROOT "\
\${TOOLCHAIN_ROOT}/\${TARGET_TRIPLE}/sysroot" CACHE PATH "Target sysroot")

set(CMAKE_SYSROOT "\${TARGET_SYSROOT}")

set(CMAKE_C_COMPILER "\${TOOLCHAIN_ROOT}/bin/\${TARGET_TRIPLE}-gcc")
set(CMAKE_CXX_COMPILER "\${TOOLCHAIN_ROOT}/bin/\${TARGET_TRIPLE}-g++")
set(CMAKE_ASM_COMPILER "\${TOOLCHAIN_ROOT}/bin/\${TARGET_TRIPLE}-gcc")
set(CMAKE_AR "\${TOOLCHAIN_ROOT}/bin/\${TARGET_TRIPLE}-ar")
set(CMAKE_RANLIB "\${TOOLCHAIN_ROOT}/bin/\${TARGET_TRIPLE}-ranlib")
set(CMAKE_NM "\${TOOLCHAIN_ROOT}/bin/\${TARGET_TRIPLE}-nm")
set(CMAKE_OBJCOPY "\${TOOLCHAIN_ROOT}/bin/\${TARGET_TRIPLE}-objcopy")
set(CMAKE_OBJDUMP "\${TOOLCHAIN_ROOT}/bin/\${TARGET_TRIPLE}-objdump")
set(CMAKE_STRIP "\${TOOLCHAIN_ROOT}/bin/\${TARGET_TRIPLE}-strip")

set(CMAKE_C_COMPILER_TARGET "\${TARGET_TRIPLE}")
set(CMAKE_CXX_COMPILER_TARGET "\${TARGET_TRIPLE}")
set(CMAKE_ASM_COMPILER_TARGET "\${TARGET_TRIPLE}")

set(CMAKE_C_FLAGS_INIT "--sysroot=\${TARGET_SYSROOT}")
set(CMAKE_CXX_FLAGS_INIT "--sysroot=\${TARGET_SYSROOT}")
set(CMAKE_EXE_LINKER_FLAGS_INIT "--sysroot=\${TARGET_SYSROOT}")
set(CMAKE_SHARED_LINKER_FLAGS_INIT "--sysroot=\${TARGET_SYSROOT}")
set(CMAKE_MODULE_LINKER_FLAGS_INIT "--sysroot=\${TARGET_SYSROOT}")

set(CMAKE_FIND_ROOT_PATH "\${TARGET_SYSROOT}")
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
${extra_lines}
EOF
}

build_cross_openssl() {
  local formula="$1"
  local target_triple="$2"
  local configure_target="$3"
  local sysroot="$4"
  local toolchain_root="$5"
  local source_tarball="$6"
  local work_dir="$7"

  local src_dir="${work_dir}/openssl-src"
  mkdir -p "${work_dir}"
  tar -xzf "${source_tarball}" -C "${work_dir}"
  src_dir="$(find "${work_dir}" -maxdepth 1 -type d -name 'openssl-*' | head -n 1)"
  [[ -n "${src_dir}" ]] || fail "failed to unpack OpenSSL sources for ${target_triple}"

  log "building OpenSSL for ${target_triple}"
  (
    cd "${src_dir}"
    export CC="${toolchain_root}/bin/${target_triple}-gcc --sysroot=${sysroot}"
    export AR="${toolchain_root}/bin/${target_triple}-ar"
    export RANLIB="${toolchain_root}/bin/${target_triple}-ranlib"
    ./Configure "${configure_target}" --prefix=/usr --openssldir=/etc/ssl no-tests
    make -j"$(sysctl -n hw.ncpu)"
    make install_sw DESTDIR="${sysroot}"
  )
}

ensure_cross_prerequisites() {
  [[ "${BOOTSTRAP}" == true ]] || return

  require_command brew
  brew tap messense/macos-cross-toolchains >/dev/null 2>&1 || true

  ensure_brew_formula cmake
  ensure_brew_formula ninja
  ensure_brew_formula pkgconf
  ensure_brew_formula "${ASIO_FORMULA}"
  ensure_brew_formula "${OPENSSL_FORMULA}"
  ensure_brew_formula "${AARCH64_FORMULA}"
  ensure_brew_formula "${X64_FORMULA}"
}

prepare_generated_toolchains() {
  mkdir -p "${GENERATED_TOOLCHAIN_DIR}"

  if [[ -z "${HONEY_RPI_TOOLCHAIN}" ]]; then
    HONEY_RPI_TOOLCHAIN="${GENERATED_TOOLCHAIN_DIR}/rpi-aarch64-gcc.cmake"
    generate_gcc_toolchain_file \
      "${HONEY_RPI_TOOLCHAIN}" \
      "$(toolchain_root_for_formula "${AARCH64_FORMULA}")" \
      "aarch64-unknown-linux-gnu" \
      "aarch64" \
      ""
  fi

  if [[ -z "${LEMON_LINUX_TOOLCHAIN}" ]]; then
    LEMON_LINUX_TOOLCHAIN="${GENERATED_TOOLCHAIN_DIR}/linux-x64-gcc.cmake"
    generate_gcc_toolchain_file \
      "${LEMON_LINUX_TOOLCHAIN}" \
      "$(toolchain_root_for_formula "${X64_FORMULA}")" \
      "x86_64-unknown-linux-gnu" \
      "x86_64" \
      "set(ASIO_INCLUDE_DIR \"$(brew_prefix "${ASIO_FORMULA}")/include\" CACHE PATH \"Host Asio include directory\")"
  fi
}

prepare_cross_openssl() {
  [[ "${BOOTSTRAP}" == true ]] || return

  local openssl_tarball
  openssl_tarball="$(ensure_brew_source_tarball "${OPENSSL_FORMULA}" '*--openssl-*.tar.gz')"

  local aarch64_sysroot x64_sysroot
  aarch64_sysroot="$(sysroot_for_formula "${AARCH64_FORMULA}" 'aarch64-unknown-linux-gnu')"
  x64_sysroot="$(sysroot_for_formula "${X64_FORMULA}" 'x86_64-unknown-linux-gnu')"

  if ! openssl_present_in_sysroot "${aarch64_sysroot}"; then
    build_cross_openssl \
      "${AARCH64_FORMULA}" \
      "aarch64-unknown-linux-gnu" \
      "linux-aarch64" \
      "${aarch64_sysroot}" \
      "$(toolchain_root_for_formula "${AARCH64_FORMULA}")" \
      "${openssl_tarball}" \
      "${STAGE_DIR}/openssl-aarch64"
  fi

  if ! openssl_present_in_sysroot "${x64_sysroot}"; then
    build_cross_openssl \
      "${X64_FORMULA}" \
      "x86_64-unknown-linux-gnu" \
      "linux-x86_64" \
      "${x64_sysroot}" \
      "$(toolchain_root_for_formula "${X64_FORMULA}")" \
      "${openssl_tarball}" \
      "${STAGE_DIR}/openssl-x64"
  fi
}

configure_and_build() {
  local source_dir="$1"
  local build_dir="$2"
  shift 2

  # Prefer Ninja generator if available to avoid Makefile/tool selection issues
  local generator_args=()
  if command -v ninja >/dev/null 2>&1; then
    generator_args=( -G Ninja )
  fi

  # If an existing build dir was created with a different generator, remove it
  # to avoid CMake generator mismatch errors.
  if [[ -d "${build_dir}" && -f "${build_dir}/CMakeCache.txt" ]]; then
    log "removing stale build dir ${build_dir} to avoid generator mismatch"
    rm -rf "${build_dir}"
  fi

  cmake -S "${source_dir}" -B "${build_dir}" "${generator_args[@]}" -DCMAKE_BUILD_TYPE="${BUILD_TYPE}" "$@"
  cmake --build "${build_dir}" --config "${BUILD_TYPE}"
}

copy_artifact() {
  local source_path="$1"
  local target_dir="$2"
  local target_name="$3"

  require_file "${source_path}"
  mkdir -p "${target_dir}"
  cp "${source_path}" "${target_dir}/${target_name}"
  chmod +x "${target_dir}/${target_name}"
  log "copied ${source_path} -> ${target_dir}/${target_name}"
}

copy_shared_libraries() {
  local build_dir="$1"
  local target_dir="$2"

  # Copy any shared libraries produced in the build tree (lib*.so*, *.dylib)
  # so the executable can run with an $ORIGIN rpath or when LD_LIBRARY_PATH
  # points to the same directory.
  if [[ -d "${build_dir}" ]]; then
    mkdir -p "${target_dir}"
    # Linux shared libs (use find -print0 to handle spaces and avoid array expansion)
    while IFS= read -r -d '' f; do
      cp -p "$f" "${target_dir}/" || true
      log "bundled shared lib $f -> ${target_dir}/"
    done < <(find "${build_dir}" -type f -name 'lib*.so*' -print0 2>/dev/null)

    # macOS dylibs
    while IFS= read -r -d '' f; do
      cp -p "$f" "${target_dir}/" || true
      log "bundled dylib $f -> ${target_dir}/"
    done < <(find "${build_dir}" -type f -name '*.dylib' -print0 2>/dev/null)
  fi
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --build-honey-rpi)
        BUILD_HONEY_RPI=true
        ;;
      --build-lemon-macos)
        BUILD_LEMON_MACOS=true
        ;;
      --build-lemon-linux)
        BUILD_LEMON_LINUX=true
        ;;
      --honey-rpi-toolchain)
        shift
        [[ $# -gt 0 ]] || fail "--honey-rpi-toolchain requires a path"
        HONEY_RPI_TOOLCHAIN="$1"
        ;;
      --lemon-linux-toolchain)
        shift
        [[ $# -gt 0 ]] || fail "--lemon-linux-toolchain requires a path"
        LEMON_LINUX_TOOLCHAIN="$1"
        ;;
      --build-type)
        shift
        [[ $# -gt 0 ]] || fail "--build-type requires a value"
        BUILD_TYPE="$1"
        ;;
      --skip-bootstrap)
        BOOTSTRAP=false
        ;;
      --clean)
        CLEAN=true
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        fail "unknown argument: $1"
        ;;
    esac
    shift
  done
}

prepare() {
  [[ -d "${HONEY_DIR}" ]] || fail "HoneyTea directory not found: ${HONEY_DIR}"
  [[ -d "${LEMON_DIR}" ]] || fail "LemonTea directory not found: ${LEMON_DIR}"

  if [[ "${CLEAN}" == true ]]; then
    log "removing stage directory ${STAGE_DIR}"
    rm -rf "${STAGE_DIR}"
  fi

  mkdir -p "${STAGE_DIR}"
  mkdir -p "${RELEASE_DIR}"

  if [[ "${BUILD_HONEY_RPI}" == false && "${BUILD_LEMON_MACOS}" == false && "${BUILD_LEMON_LINUX}" == false ]]; then
    BUILD_HONEY_RPI=true
    BUILD_LEMON_MACOS=true
    BUILD_LEMON_LINUX=true
    log "no explicit build target selected, defaulting to all targets"
  fi

  ensure_cross_prerequisites
  require_command cmake
  prepare_generated_toolchains
  # If user provided a toolchain path but the file doesn't exist, attempt to
  # create a local toolchain by copying from an example file in the toolchains/
  # directory (e.g. foo.example.cmake -> foo.local.cmake). This helps users
  # who followed the docs but forgot to copy the example.
  if [[ -n "${HONEY_RPI_TOOLCHAIN}" && ! -f "${HONEY_RPI_TOOLCHAIN}" ]]; then
    local example
    example="${HONEY_RPI_TOOLCHAIN/.local.cmake/.example.cmake}"
    if [[ -f "${example}" ]]; then
      log "toolchain ${HONEY_RPI_TOOLCHAIN} not found, copying example ${example} -> ${HONEY_RPI_TOOLCHAIN} (please edit TOOLCHAIN_ROOT/TARGET_SYSROOT)"
      mkdir -p "$(dirname "${HONEY_RPI_TOOLCHAIN}")"
      cp "${example}" "${HONEY_RPI_TOOLCHAIN}"
    else
      # try a generic example with same basename
      example="$(dirname "${HONEY_RPI_TOOLCHAIN}")/$(basename "${HONEY_RPI_TOOLCHAIN}" .local.cmake).example.cmake"
      if [[ -f "${example}" ]]; then
        log "toolchain ${HONEY_RPI_TOOLCHAIN} not found, copying example ${example} -> ${HONEY_RPI_TOOLCHAIN} (please edit TOOLCHAIN_ROOT/TARGET_SYSROOT)"
        mkdir -p "$(dirname "${HONEY_RPI_TOOLCHAIN}")"
        cp "${example}" "${HONEY_RPI_TOOLCHAIN}"
      fi
    fi
  fi

  if [[ -n "${LEMON_LINUX_TOOLCHAIN}" && ! -f "${LEMON_LINUX_TOOLCHAIN}" ]]; then
    local example2
    example2="${LEMON_LINUX_TOOLCHAIN/.local.cmake/.example.cmake}"
    if [[ -f "${example2}" ]]; then
      log "toolchain ${LEMON_LINUX_TOOLCHAIN} not found, copying example ${example2} -> ${LEMON_LINUX_TOOLCHAIN} (please edit TOOLCHAIN_ROOT/TARGET_SYSROOT)"
      mkdir -p "$(dirname "${LEMON_LINUX_TOOLCHAIN}")"
      cp "${example2}" "${LEMON_LINUX_TOOLCHAIN}"
    else
      example2="$(dirname "${LEMON_LINUX_TOOLCHAIN}")/$(basename "${LEMON_LINUX_TOOLCHAIN}" .local.cmake).example.cmake"
      if [[ -f "${example2}" ]]; then
        log "toolchain ${LEMON_LINUX_TOOLCHAIN} not found, copying example ${example2} -> ${LEMON_LINUX_TOOLCHAIN} (please edit TOOLCHAIN_ROOT/TARGET_SYSROOT)"
        mkdir -p "$(dirname "${LEMON_LINUX_TOOLCHAIN}")"
        cp "${example2}" "${LEMON_LINUX_TOOLCHAIN}"
      fi
    fi
  fi
  # Normalize toolchain paths to absolute paths so CMake can always locate them
  make_abs_path() {
    local p="$1"
    if [[ -z "${p}" ]]; then
      printf '%s' ""
      return
    fi
    if [[ "${p}" = /* ]]; then
      printf '%s' "${p}"
      return
    fi
    # interpret relative paths as relative to DOC_DIR
    printf '%s' "${DOC_DIR%/}/${p#./}"
  }

  if [[ -n "${HONEY_RPI_TOOLCHAIN}" ]]; then
    HONEY_RPI_TOOLCHAIN="$(make_abs_path "${HONEY_RPI_TOOLCHAIN}")"
  fi
  if [[ -n "${LEMON_LINUX_TOOLCHAIN}" ]]; then
    LEMON_LINUX_TOOLCHAIN="$(make_abs_path "${LEMON_LINUX_TOOLCHAIN}")"
  fi

  validate_toolchain() {
    local f="$1"
    local cc cpp
    # extract quoted value if present
    cc="$(grep -E 'CMAKE_C_COMPILER' "${f}" 2>/dev/null | head -n1 | sed -E 's/.*"([^"]+)".*/\1/')"
    cpp="$(grep -E 'CMAKE_CXX_COMPILER' "${f}" 2>/dev/null | head -n1 | sed -E 's/.*"([^"]+)".*/\1/')"
    # fallback: extract unquoted token
    if [[ -z "${cc}" ]]; then
      cc="$(grep -E 'CMAKE_C_COMPILER' "${f}" 2>/dev/null | head -n1 | awk '{print $2}' | tr -d '()')"
    fi
    if [[ -z "${cpp}" ]]; then
      cpp="$(grep -E 'CMAKE_CXX_COMPILER' "${f}" 2>/dev/null | head -n1 | awk '{print $2}' | tr -d '()')"
    fi
    for p in "${cc}" "${cpp}"; do
      if [[ -n "${p}" ]]; then
        if [[ "${p}" = /* ]]; then
          if [[ ! -x "${p}" ]]; then
            fail "toolchain ${f} references compiler ${p} which does not exist or is not executable; please edit the toolchain file"
          fi
        else
          # relative or bare name; check PATH
          if ! command -v "${p}" >/dev/null 2>&1; then
            fail "toolchain ${f} references compiler ${p} which is not in PATH; please edit the toolchain file to point to a valid compiler"
          fi
        fi
      fi
    done
  }

  if [[ -n "${HONEY_RPI_TOOLCHAIN}" && -f "${HONEY_RPI_TOOLCHAIN}" ]]; then
    validate_toolchain "${HONEY_RPI_TOOLCHAIN}"
  fi
  if [[ -n "${LEMON_LINUX_TOOLCHAIN}" && -f "${LEMON_LINUX_TOOLCHAIN}" ]]; then
    validate_toolchain "${LEMON_LINUX_TOOLCHAIN}"
  fi

  if [[ "${BUILD_HONEY_RPI}" == true || "${BUILD_LEMON_LINUX}" == true ]]; then
    prepare_cross_openssl
  fi
}

build_honey_rpi() {
  [[ -n "${HONEY_RPI_TOOLCHAIN}" ]] || fail "HoneyTea Raspberry Pi build requires --honey-rpi-toolchain"
  require_file "${HONEY_RPI_TOOLCHAIN}"

  local build_dir="${STAGE_DIR}/honeytea-rpi-arm64"
  log "building HoneyTea for Raspberry Pi arm64"
  configure_and_build "${HONEY_DIR}" "${build_dir}" -DCMAKE_TOOLCHAIN_FILE="${HONEY_RPI_TOOLCHAIN}"
  copy_artifact "${build_dir}/honeytea" "${RELEASE_DIR}/honeytea/raspberrypi-arm64" "honeytea"
  copy_shared_libraries "${build_dir}" "${RELEASE_DIR}/honeytea/raspberrypi-arm64"
}

build_lemon_macos() {
  local build_dir="${STAGE_DIR}/lemontea-macos"
  log "building LemonTea for macOS native"
  configure_and_build "${LEMON_DIR}" "${build_dir}"
  copy_artifact "${build_dir}/lemontea" "${RELEASE_DIR}/lemontea/macos" "lemontea"
  copy_shared_libraries "${build_dir}" "${RELEASE_DIR}/lemontea/macos"
}

build_lemon_linux() {
  [[ -n "${LEMON_LINUX_TOOLCHAIN}" ]] || fail "LemonTea Linux build requires --lemon-linux-toolchain"
  require_file "${LEMON_LINUX_TOOLCHAIN}"

  local build_dir="${STAGE_DIR}/lemontea-linux-x64"
  log "building LemonTea for Linux x64"
  configure_and_build "${LEMON_DIR}" "${build_dir}" -DCMAKE_TOOLCHAIN_FILE="${LEMON_LINUX_TOOLCHAIN}"
  copy_artifact "${build_dir}/lemontea" "${RELEASE_DIR}/lemontea/linux-x64" "lemontea"
  copy_shared_libraries "${build_dir}" "${RELEASE_DIR}/lemontea/linux-x64"
}

main() {
  parse_args "$@"
  prepare

  if [[ "${BUILD_HONEY_RPI}" == true ]]; then
    build_honey_rpi
  fi

  if [[ "${BUILD_LEMON_MACOS}" == true ]]; then
    build_lemon_macos
  fi

  if [[ "${BUILD_LEMON_LINUX}" == true ]]; then
    build_lemon_linux
  fi

  log "all requested builds completed"
  log "release output directory: ${RELEASE_DIR}"
}

main "$@"