cmake_minimum_required(VERSION 3.20)

# Example toolchain for building LemonTea on macOS with clang targeting
# Linux x86_64.
#
# Usage:
#   cp toolchains/linux-x64-clang-toolchain.example.cmake \
#      toolchains/linux-x64-clang-toolchain.local.cmake
#   Edit TOOLCHAIN_ROOT and TARGET_SYSROOT in the local copy.

set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR x86_64)
set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)

set(TARGET_TRIPLE "x86_64-unknown-linux-gnu" CACHE STRING "Target triple")
set(TOOLCHAIN_ROOT "/opt/llvm-cross" CACHE PATH "Directory containing clang, clang++, llvm-ar, llvm-ranlib")
set(TARGET_SYSROOT "/opt/sysroots/linux-x64" CACHE PATH "Target sysroot directory")

set(CMAKE_SYSROOT "${TARGET_SYSROOT}")

set(CMAKE_C_COMPILER "${TOOLCHAIN_ROOT}/bin/clang")
set(CMAKE_CXX_COMPILER "${TOOLCHAIN_ROOT}/bin/clang++")
set(CMAKE_ASM_COMPILER "${TOOLCHAIN_ROOT}/bin/clang")
set(CMAKE_AR "${TOOLCHAIN_ROOT}/bin/llvm-ar")
set(CMAKE_RANLIB "${TOOLCHAIN_ROOT}/bin/llvm-ranlib")
set(CMAKE_LINKER "${TOOLCHAIN_ROOT}/bin/ld.lld")
set(CMAKE_NM "${TOOLCHAIN_ROOT}/bin/llvm-nm")
set(CMAKE_OBJCOPY "${TOOLCHAIN_ROOT}/bin/llvm-objcopy")
set(CMAKE_OBJDUMP "${TOOLCHAIN_ROOT}/bin/llvm-objdump")
set(CMAKE_STRIP "${TOOLCHAIN_ROOT}/bin/llvm-strip")

set(CMAKE_C_COMPILER_TARGET "${TARGET_TRIPLE}")
set(CMAKE_CXX_COMPILER_TARGET "${TARGET_TRIPLE}")
set(CMAKE_ASM_COMPILER_TARGET "${TARGET_TRIPLE}")

set(COMMON_TARGET_FLAGS "--target=${TARGET_TRIPLE} --sysroot=${TARGET_SYSROOT} -fuse-ld=lld")
set(CMAKE_C_FLAGS_INIT "${COMMON_TARGET_FLAGS}")
set(CMAKE_CXX_FLAGS_INIT "${COMMON_TARGET_FLAGS}")
set(CMAKE_EXE_LINKER_FLAGS_INIT "${COMMON_TARGET_FLAGS}")
set(CMAKE_SHARED_LINKER_FLAGS_INIT "${COMMON_TARGET_FLAGS}")
set(CMAKE_MODULE_LINKER_FLAGS_INIT "${COMMON_TARGET_FLAGS}")

set(CMAKE_FIND_ROOT_PATH "${TARGET_SYSROOT}")
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

set(ENV{PKG_CONFIG_DIR} "")
set(ENV{PKG_CONFIG_SYSROOT_DIR} "${TARGET_SYSROOT}")
set(ENV{PKG_CONFIG_LIBDIR} "${TARGET_SYSROOT}/usr/lib/x86_64-linux-gnu/pkgconfig:${TARGET_SYSROOT}/usr/lib/pkgconfig:${TARGET_SYSROOT}/usr/share/pkgconfig")
