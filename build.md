# 构建与发布说明

本文档以 [scripts/macOS_build_release.sh](scripts/macOS_build_release.sh) 为准，说明如何在 macOS 开发机上构建和验证以下产物：

- HoneyTea 的 Raspberry Pi arm64 版本
- LemonTea 的 macOS 原生版本
- LemonTea 的 Linux x86_64 交叉编译版本

我已在当前工作区实际执行过以下命令并通过：

```bash
cd LemonTea-doc
./scripts/macOS_build_release.sh --build-lemon-macos
```

该命令成功生成了 [release/lemontea/macos](release/lemontea/macos) 下的 `lemontea`，并同时打包了运行所需的 `libdatachannel` 动态库。

另外，我也已实际执行并通过以下全量构建命令：

```bash
cd LemonTea-doc
./scripts/macOS_build_release.sh --clean
```

该命令会清理 [LemonTea-doc/.build-release](LemonTea-doc/.build-release)，然后默认构建 HoneyTea Raspberry Pi arm64、LemonTea macOS 和 LemonTea Linux x86_64 三个目标。

前端 LemonTea-vue3 不包含在该脚本中，因此前端改动仍需单独执行：

```bash
cd ../LemonTea-vue3
npm run build
```

## 脚本位置

- [scripts/macOS_build_release.sh](scripts/macOS_build_release.sh)
- [toolchains/rpi-aarch64-clang-toolchain.example.cmake](toolchains/rpi-aarch64-clang-toolchain.example.cmake)
- [toolchains/linux-x64-clang-toolchain.example.cmake](toolchains/linux-x64-clang-toolchain.example.cmake)

## 输出目录

构建完成后，产物统一放在工作区根目录下的 [release](release) 中：

```text
release/
  honeytea/
    raspberrypi-arm64/
      honeytea
      lib*.so*
  lemontea/
    macos/
      lemontea
      libdatachannel*.dylib
    linux-x64/
      lemontea
      lib*.so*
```

## 推荐用法

### 仅验证 macOS 本机构建

这是当前开发调试最直接的方式：

```bash
cd LemonTea-doc
./scripts/macOS_build_release.sh --build-lemon-macos
```

### 清理后构建全部目标

```bash
cd LemonTea-doc
./scripts/macOS_build_release.sh --clean
./scripts/macOS_build_release.sh
```

当未显式指定目标时，脚本会默认构建全部目标。

### 仅构建 Raspberry Pi 版本 HoneyTea

```bash
cd LemonTea-doc
./scripts/macOS_build_release.sh --build-honey-rpi
```

如果你想显式指定脚本自动生成的 GCC toolchain：

```bash
cd LemonTea-doc
./scripts/macOS_build_release.sh \
  --build-honey-rpi \
  --honey-rpi-toolchain .build-release/toolchains/rpi-aarch64-gcc.cmake
```

### 构建 Linux x64 版本 LemonTea

```bash
cd LemonTea-doc
./scripts/macOS_build_release.sh --build-lemon-linux
```

## 脚本行为说明

脚本会执行以下工作：

- 在 [LemonTea-doc/.build-release](LemonTea-doc/.build-release) 下创建独立中间构建目录，避免污染仓库自带的调试 `build/` 目录
- 优先复用工作区现有的 FetchContent 源码缓存，例如根目录 `build/_deps`、[HoneyTea/build](HoneyTea/build) 和 [LemonTea/build](LemonTea/build) 下的 `_deps`
- 优先使用 Ninja 作为生成器，避免 Makefile 生成器差异
- 将最终可执行文件与运行时需要的动态库一并复制到 [release](release)
- 默认启用 bootstrap，自动准备 Homebrew 依赖与交叉编译相关工具链

## 常用参数

- `--build-honey-rpi`: 构建 HoneyTea 的 Raspberry Pi arm64 版本
- `--build-lemon-macos`: 构建 LemonTea 的 macOS 原生版本
- `--build-lemon-linux`: 构建 LemonTea 的 Linux x86_64 版本
- `--honey-rpi-toolchain PATH`: 指定 HoneyTea 的 Raspberry Pi toolchain 文件
- `--lemon-linux-toolchain PATH`: 指定 LemonTea 的 Linux x64 toolchain 文件
- `--build-type TYPE`: 指定 CMake 构建类型，默认 `Release`
- `--skip-bootstrap`: 跳过 brew bootstrap 和交叉依赖准备
- `--clean`: 删除 [LemonTea-doc/.build-release](LemonTea-doc/.build-release) 后重新构建

## clang 工具链用法

如果你更偏好 clang 交叉编译，可以从示例文件复制一份本地 toolchain：

```bash
cd LemonTea-doc
cp toolchains/rpi-aarch64-clang-toolchain.example.cmake toolchains/rpi-aarch64-clang-toolchain.local.cmake
cp toolchains/linux-x64-clang-toolchain.example.cmake toolchains/linux-x64-clang-toolchain.local.cmake
```

然后编辑 `.local.cmake` 中的以下字段：

- `TOOLCHAIN_ROOT`
- `TARGET_SYSROOT`
- `CMAKE_C_COMPILER`
- `CMAKE_CXX_COMPILER`

之后再执行：

```bash
cd LemonTea-doc
./scripts/macOS_build_release.sh \
  --build-honey-rpi \
  --build-lemon-linux \
  --honey-rpi-toolchain ./toolchains/rpi-aarch64-clang-toolchain.local.cmake \
  --lemon-linux-toolchain ./toolchains/linux-x64-clang-toolchain.local.cmake
```

## 常见问题

- 提示 `toolchain ... references compiler ... not in PATH`
  说明 toolchain 文件里的编译器路径无效，或者变量展开后仍然指向不存在的位置。优先检查 `TOOLCHAIN_ROOT`、`TARGET_TRIPLE`、`TARGET_SYSROOT`。
- 提示生成器不匹配或 `CMAKE_MAKE_PROGRAM is not set`
  先运行 `./scripts/macOS_build_release.sh --clean`，并确认本机已安装 `ninja`。
- 交叉构建时报 OpenSSL 或 TLS 相关错误
  如果你使用 `--skip-bootstrap`，需要自行保证目标 sysroot 中已经包含 OpenSSL 头文件和库。
- FetchContent 下载失败
  优先检查当前工作区已有的 `_deps/*-src` 是否完整；脚本会优先离线复用这些缓存。
- 运行时缺少动态库
  请直接使用 [release](release) 下脚本打包后的目录，不要只单独复制可执行文件。

## 部署建议

- macOS 版 LemonTea：直接使用 [release/lemontea/macos](release/lemontea/macos)
- Linux x64 版 LemonTea：复制 [release/lemontea/linux-x64](release/lemontea/linux-x64) 整个目录到目标机器
- Raspberry Pi 版 HoneyTea：复制 [release/honeytea/raspberrypi-arm64](release/honeytea/raspberrypi-arm64) 整个目录到树莓派

## 相关文件

- [README.md](README.md)
- [architecture.md](architecture.md)
- [http-api.md](http-api.md)
- [macos-testing.md](macos-testing.md)