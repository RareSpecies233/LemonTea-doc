#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOC_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
WORKSPACE_DIR="$(cd "${DOC_DIR}/.." && pwd)"
HONEY_DIR="${WORKSPACE_DIR}/HoneyTea"
LEMON_DIR="${WORKSPACE_DIR}/LemonTea"
STAGE_DIR="${DOC_DIR}/.build-release"
RELEASE_DIR="${WORKSPACE_DIR}/release"

BUILD_TYPE="Release"
BUILD_HONEY_RPI=false
BUILD_LEMON_MACOS=false
BUILD_LEMON_LINUX=false
CLEAN=false
HONEY_RPI_TOOLCHAIN=""
LEMON_LINUX_TOOLCHAIN=""

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
  --clean                          Remove .build-release before building
  -h, --help                       Show this help message

Examples:
  ./scripts/build_release.sh --build-lemon-macos
  ./scripts/build_release.sh \
    --build-honey-rpi \
    --honey-rpi-toolchain /abs/path/rpi-aarch64-clang.cmake
  ./scripts/build_release.sh \
    --build-honey-rpi \
    --build-lemon-macos \
    --build-lemon-linux \
    --honey-rpi-toolchain /abs/path/rpi-aarch64-clang.cmake \
    --lemon-linux-toolchain /abs/path/linux-x64-toolchain.cmake
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

configure_and_build() {
  local source_dir="$1"
  local build_dir="$2"
  shift 2

  cmake -S "${source_dir}" -B "${build_dir}" -DCMAKE_BUILD_TYPE="${BUILD_TYPE}" "$@"
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
  require_command cmake

  [[ -d "${HONEY_DIR}" ]] || fail "HoneyTea directory not found: ${HONEY_DIR}"
  [[ -d "${LEMON_DIR}" ]] || fail "LemonTea directory not found: ${LEMON_DIR}"

  if [[ "${CLEAN}" == true ]]; then
    log "removing stage directory ${STAGE_DIR}"
    rm -rf "${STAGE_DIR}"
  fi

  mkdir -p "${STAGE_DIR}"
  mkdir -p "${RELEASE_DIR}"

  if [[ "${BUILD_HONEY_RPI}" == false && "${BUILD_LEMON_MACOS}" == false && "${BUILD_LEMON_LINUX}" == false ]]; then
    BUILD_LEMON_MACOS=true
    log "no explicit build target selected, defaulting to --build-lemon-macos"
  fi
}

build_honey_rpi() {
  [[ -n "${HONEY_RPI_TOOLCHAIN}" ]] || fail "HoneyTea Raspberry Pi build requires --honey-rpi-toolchain"
  require_file "${HONEY_RPI_TOOLCHAIN}"

  local build_dir="${STAGE_DIR}/honeytea-rpi-arm64"
  log "building HoneyTea for Raspberry Pi arm64"
  configure_and_build "${HONEY_DIR}" "${build_dir}" -DCMAKE_TOOLCHAIN_FILE="${HONEY_RPI_TOOLCHAIN}"
  copy_artifact "${build_dir}/honeytea" "${RELEASE_DIR}/honeytea/raspberrypi-arm64" "honeytea"
}

build_lemon_macos() {
  local build_dir="${STAGE_DIR}/lemontea-macos"
  log "building LemonTea for macOS native"
  configure_and_build "${LEMON_DIR}" "${build_dir}"
  copy_artifact "${build_dir}/lemontea" "${RELEASE_DIR}/lemontea/macos" "lemontea"
}

build_lemon_linux() {
  [[ -n "${LEMON_LINUX_TOOLCHAIN}" ]] || fail "LemonTea Linux build requires --lemon-linux-toolchain"
  require_file "${LEMON_LINUX_TOOLCHAIN}"

  local build_dir="${STAGE_DIR}/lemontea-linux-x64"
  log "building LemonTea for Linux x64"
  configure_and_build "${LEMON_DIR}" "${build_dir}" -DCMAKE_TOOLCHAIN_FILE="${LEMON_LINUX_TOOLCHAIN}"
  copy_artifact "${build_dir}/lemontea" "${RELEASE_DIR}/lemontea/linux-x64" "lemontea"
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