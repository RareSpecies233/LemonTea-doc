# 构建与发布说明

本文档说明 LemonTea-doc 下的统一构建脚本如何使用，以及 HoneyTea 与 LemonTea 的发布产物会被放到哪里。

## 脚本位置

- [scripts/build_release.sh](scripts/build_release.sh)
- [toolchains/rpi-aarch64-clang-toolchain.example.cmake](toolchains/rpi-aarch64-clang-toolchain.example.cmake)
- [toolchains/linux-x64-clang-toolchain.example.cmake](toolchains/linux-x64-clang-toolchain.example.cmake)

该脚本统一负责以下任务：

- 编译 HoneyTea 的 Raspberry Pi 64 位版本
- 编译 LemonTea 的 macOS 原生版本
- 编译 LemonTea 的 Linux 64 位交叉编译版本
- 将产物复制到工作区根目录下的 release/ 目录

## 输出目录

脚本执行后会生成如下目录结构：

```text
release/
  honeytea/
    raspberrypi-arm64/
      honeytea
  lemontea/
    macos/
      lemontea
    linux-x64/
      lemontea
```

## 前置条件

### 通用依赖

- CMake 3.20 及以上
- Ninja 或系统默认生成器可用
- 可访问外网，以便 CMake FetchContent 下载依赖

### macOS 原生构建

- 本机安装 Apple Clang 或其他可用 C++17 编译器

### Linux 64 位交叉编译

- 已准备好 Linux x86_64 目标工具链
- 已准备好对应 sysroot
- 已编写可用的 CMake toolchain 文件

### Raspberry Pi 64 位交叉编译

- 已准备好 aarch64 Linux 目标工具链
- 推荐使用 clang + sysroot 的方式交叉编译
- 已编写可用的 CMake toolchain 文件

脚本不会假设你的工具链安装在固定路径，而是通过参数接收 toolchain 文件位置。这种做法更适合不同机器和不同交叉编译环境。

## 最常用的命令

只构建 macOS 原生版 LemonTea：

```bash
./scripts/build_release.sh --build-lemon-macos
```

构建 HoneyTea 的树莓派版本：

```bash
cp toolchains/rpi-aarch64-clang-toolchain.example.cmake toolchains/rpi-aarch64-clang-toolchain.local.cmake
# 编辑 toolchains/rpi-aarch64-clang-toolchain.local.cmake 中的 TOOLCHAIN_ROOT 和 TARGET_SYSROOT

./scripts/build_release.sh \
  --build-honey-rpi \
  --honey-rpi-toolchain ./toolchains/rpi-aarch64-clang-toolchain.local.cmake
```

构建 LemonTea 的 Linux 64 位交叉编译版本：

```bash
cp toolchains/linux-x64-clang-toolchain.example.cmake toolchains/linux-x64-clang-toolchain.local.cmake
# 编辑 toolchains/linux-x64-clang-toolchain.local.cmake 中的 TOOLCHAIN_ROOT 和 TARGET_SYSROOT

./scripts/build_release.sh \
  --build-lemon-linux \
  --lemon-linux-toolchain ./toolchains/linux-x64-clang-toolchain.local.cmake
```

一次性构建三种目标：

```bash
./scripts/build_release.sh \
  --build-honey-rpi \
  --build-lemon-macos \
  --build-lemon-linux \
  --honey-rpi-toolchain ./toolchains/rpi-aarch64-clang-toolchain.local.cmake \
  --lemon-linux-toolchain ./toolchains/linux-x64-clang-toolchain.local.cmake
```

## 参数说明

- --build-honey-rpi: 构建 HoneyTea 的 Raspberry Pi 64 位版本
- --build-lemon-macos: 构建 LemonTea 的 macOS 原生版本
- --build-lemon-linux: 构建 LemonTea 的 Linux 64 位版本
- --honey-rpi-toolchain PATH: HoneyTea 树莓派交叉编译所需的 CMake toolchain 文件
- --lemon-linux-toolchain PATH: LemonTea Linux 交叉编译所需的 CMake toolchain 文件
- --build-type TYPE: 传给 CMake 的构建类型，默认 Release
- --clean: 清理脚本所使用的中间构建目录后再重新构建

## 构建目录

脚本不会复用仓库中已有的 build/ 目录，而是使用 LemonTea-doc 下的专用中间目录：

```text
LemonTea-doc/.build-release/
```

这样可以避免污染你当前已经存在的本地调试构建目录。

## 关于 clang 交叉编译 Raspberry Pi 64 位

你提到偏好 clang 交叉编译 64 位版本，这完全可以通过 CMake toolchain 文件实现。脚本本身不锁死编译器，只要求 toolchain 文件正确设置以下内容：

- CMAKE_SYSTEM_NAME
- CMAKE_SYSTEM_PROCESSOR
- CMAKE_SYSROOT
- CMAKE_C_COMPILER
- CMAKE_CXX_COMPILER
- 必要时的 CMAKE_C_FLAGS 和 CMAKE_CXX_FLAGS
- 必要时的链接器和查找路径

一个典型目标应当是：

- system name: Linux
- processor: aarch64
- compiler: clang / clang++

仓库中已提供示例模板：[toolchains/rpi-aarch64-clang-toolchain.example.cmake](toolchains/rpi-aarch64-clang-toolchain.example.cmake)。

## 关于 Linux x64 交叉编译

如果你希望从 macOS 交叉编译出可在 Linux x64 上运行的 LemonTea，可以直接从模板开始：

- [toolchains/linux-x64-clang-toolchain.example.cmake](toolchains/linux-x64-clang-toolchain.example.cmake)

这个模板同样基于 clang + sysroot 的方式，适合你统一维护一套 LLVM 交叉编译环境。

## 建议的 toolchain 文件检查项

如果交叉编译失败，优先检查：

1. sysroot 是否完整
2. clang 的 target triple 是否正确
3. 头文件与运行库是否来自同一套目标系统
4. CMake 是否把 find path 限制到了目标 sysroot
5. libdatachannel 依赖在交叉环境下是否都能被正确解析

## 发布产物使用建议

- macOS 版本 LemonTea 可直接用于本机联调
- Linux x64 版本 LemonTea 适合部署到远端 Linux 主机
- Raspberry Pi 64 位版本 HoneyTea 适合复制到树莓派设备上运行

复制到目标设备后，仍需配套准备相应配置文件：

- HoneyTea 使用 [../HoneyTea/config/client.example.json](../HoneyTea/config/client.example.json)
- LemonTea 使用 [../LemonTea/config/server.example.json](../LemonTea/config/server.example.json)

## 相关文档

- [README.md](README.md)
- [architecture.md](architecture.md)
- [http-api.md](http-api.md)