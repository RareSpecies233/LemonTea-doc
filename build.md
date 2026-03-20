# 构建与发布说明（已更新）

本文档说明如何使用仓库内的统一构建脚本 `scripts/build_release.sh` 构建三种发布产物：

- HoneyTea（Raspberry Pi aarch64）
- LemonTea（macOS 原生）
- LemonTea（Linux x86_64 交叉编译）

建议先阅读“快速开始”并按照示例执行，再根据需要调整 toolchain 文件或 sysroot。

**输出目录**

构建完成后产物放在仓库根目录的 `release/` 下，默认结构：

```text
release/
  honeytea/
    raspberrypi-arm64/
      honeytea
      lib*.so*    # 如果是 Linux/aarch64 的共享库会与可执行文件同目录
  lemontea/
    macos/
      lemontea
    linux-x64/
      lemontea
```

**快速开始（推荐） — 使用脚本自动生成并使用 GCC 工具链**

脚本可以自动生成基于 Homebrew cross toolchains 的 GCC 类型 toolchain，并为交叉构建准备 OpenSSL 等依赖（若启用 bootstrap）。这是最少手工干预的流程：

```bash
# 1) 全部清理并生成（推荐）
./scripts/build_release.sh --clean

# 2) 构建所有目标（macOS 本机 + Linux x64 + Raspberry Pi）
./scripts/build_release.sh

# 或者仅构建 Raspberry Pi（使用脚本自动生成的 toolchain）
./scripts/build_release.sh --clean --build-honey-rpi

# 若要显式使用脚本生成的工具链：
./scripts/build_release.sh --build-honey-rpi --honey-rpi-toolchain .build-release/toolchains/rpi-aarch64-gcc.cmake
```

该工作流适合在 macOS 主机上，结合 Homebrew 提供的交叉工具链包使用（脚本会尝试安装需要的 formula）。

**手动工作流 — 使用 clang + 本地 toolchain（可选）**

如果你更偏好 clang + 自行准备的 sysroot，按原始文档步骤：

1. 复制示例 toolchain：

```bash
cp toolchains/rpi-aarch64-clang-toolchain.example.cmake toolchains/rpi-aarch64-clang-toolchain.local.cmake
```

2. 编辑 `toolchains/rpi-aarch64-clang-toolchain.local.cmake`：将 `TOOLCHAIN_ROOT` 和 `TARGET_SYSROOT` 修改为你环境中的实际路径；确保 `CMAKE_C_COMPILER` 与 `CMAKE_CXX_COMPILER` 指向可执行的编译器（绝对路径或在 PATH 中可见）。

3. 使用脚本并传入本地 toolchain：

```bash
./scripts/build_release.sh --build-honey-rpi --honey-rpi-toolchain ./toolchains/rpi-aarch64-clang-toolchain.local.cmake
```

注意：示例文件中通常包含占位符 `${TOOLCHAIN_ROOT}`，必须替换为真实路径；脚本在找不到你指定的 `.local.cmake` 时会尝试从对应 `.example.cmake` 复制一个副本供你编辑。

**常见问题与解决**

- CMake 报 "toolchain references compiler ${TOOLCHAIN_ROOT}/bin/clang which is not in PATH": 编辑对应的 `.local.cmake`，把 `TOOLCHAIN_ROOT` 指向实际交叉编译器根目录，或把编译器放到 PATH 中。
- CMake 报 "CMAKE_MAKE_PROGRAM is not set" 或生成器不匹配：确保系统安装 `ninja`（脚本会优先使用 Ninja），或者在清理后重新运行 `--clean`。
- 找不到 OpenSSL 或 TLS 相关错误：如果使用脚本的 bootstrap，它会尝试把 OpenSSL 编译并安装到交叉 sysroot 中；若跳过 bootstrap，请确保 sysroot 内含 OpenSSL 头文件与库。
- 运行时缺少 `libdatachannel.so.*`：脚本已经把构建出的共享库拷贝到 `release/...` 下；把整个目录复制到树莓派后直接运行即可，或把库安装到系统目录并 `ldconfig`。

**部署到目标设备（树莓派）**

把 `release/honeytea/raspberrypi-arm64/` 整个目录拷贝到树莓派，进入目录直接运行：

```bash
scp -r release/honeytea/raspberrypi-arm64 pi@<RPI_IP>:/home/pi/rarespecies/honeytea
ssh pi@<RPI_IP>
cd /home/pi/rarespecies/honeytea/raspberrypi-arm64
./honeytea
```

如果不愿意拷整目录，也可以把 `libdatachannel.so.*` 文件拷到树莓派 `/usr/local/lib` 并运行 `sudo ldconfig`。

**脚本参数速查**

- `--build-honey-rpi` : 构建 HoneyTea（Raspberry Pi aarch64）
- `--build-lemon-macos` : 构建 LemonTea（macOS 原生）
- `--build-lemon-linux` : 构建 LemonTea（Linux x86_64）
- `--honey-rpi-toolchain PATH` : 指定 Raspberry Pi 的 CMake toolchain 文件
- `--lemon-linux-toolchain PATH` : 指定 Linux x64 的 CMake toolchain 文件
- `--build-type TYPE` : CMake 构建类型，默认 `Release`
- `--skip-bootstrap` : 跳过脚本的 bootstrap（不会安装 brew formula 或交叉编译 OpenSSL）
- `--clean` : 删除中间目录 `.build-release` 后再构建

**参考与示例文件**

- 工具链示例：`toolchains/rpi-aarch64-clang-toolchain.example.cmake`、`toolchains/linux-x64-clang-toolchain.example.cmake`
- 构建脚本：`scripts/build_release.sh`

如需我替你在本机运行并上传构建产物，请回复 “执行”，我会运行并把生成的 release 路径与日志反馈给你。

---
（本页已更新以包含脚本自动生成工具链与常见故障排查说明）
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