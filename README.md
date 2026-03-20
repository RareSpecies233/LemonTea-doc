# LemonTea 远程控制测试原型

LemonTea-doc 是整个远程控制测试原型的文档与导航仓库，负责说明系统架构、接口设计、构建方法和联调流程。

当前这套工程由四个目录组成：

- [HoneyTea](https://github.com/RareSpecies233/HoneyTea): 客户端，运行在树莓派或其他边缘设备上，负责暴露设备能力
- [LemonTea](https://github.com/RareSpecies233/LemonTea): 服务端，接收 HoneyTea 连接，并通过 Crow 暴露 HTTP API
- [LemonTea-doc](https://github.com/RareSpecies233/LemonTea-doc): 文档仓库
- [LemonTea-vue3](https://github.com/RareSpecies233/LemonTea-vue3): Vue 3 前端控制台

## 当前能力概览

- HoneyTea 与 LemonTea 支持 TCP / WebRTC 双模式控制链路
- LemonTea 通过 Crow 暴露 HTTP API
- HoneyTea 支持 shell 执行、文件访问、插件管理
- LemonTea 支持服务端本地插件管理
- LemonTea-vue3 提供图形控制台页面
- 客户端与服务端都具备较详细的日志输出

## 文档索引

- [architecture.md](architecture.md): 系统架构、通信协议、插件接入规范
- [http-api.md](http-api.md): LemonTea HTTP API 说明与 curl 示例
- [macos-testing.md](macos-testing.md): macOS 联调能力与当前限制
- [build.md](build.md): 统一构建脚本、交叉编译参数、产物目录说明

## 快速上手

### 1. 构建服务端与客户端

如果你只是做本机验证，可以分别进入 [../LemonTea/README.md](../LemonTea/README.md) 和 [../HoneyTea/README.md](../HoneyTea/README.md) 中的构建章节执行。

如果你需要统一生成发布目录中的产物，请使用文档仓库里的脚本：

```bash
./scripts/build_release.sh --build-lemon-macos
```

如果需要同时进行交叉编译，请参考 [build.md](build.md) 中的完整示例。

### 2. 启动 LemonTea 服务端

```bash
cd ../LemonTea
cp config/server.example.json config/server.local.json
./build/lemontea config/server.local.json
```

### 3. 启动 HoneyTea 客户端

```bash
cd ../HoneyTea
cp config/client.example.json config/client.local.json
./build/honeytea config/client.local.json
```

### 4. 启动前端

```bash
cd ../LemonTea-vue3
npm install
npm run dev
```

默认情况下，前端通过 http://127.0.0.1:18080 访问 LemonTea。

## 使用方式

推荐的联调顺序如下：

1. 启动 LemonTea
2. 启动 HoneyTea
3. 访问 LemonTea 的健康检查接口确认链路建立
4. 使用 LemonTea-vue3 或 curl 调用 LemonTea 的 HTTP API

健康检查示例：

```bash
curl http://127.0.0.1:18080/health
```

远程执行命令示例：

```bash
curl -X POST http://127.0.0.1:18080/api/clients/raspi-dev-01/shell \
  -H 'Content-Type: application/json' \
  -d '{"command":"uname -a"}'
```

## 仓库入口

- [../HoneyTea/README.md](../HoneyTea/README.md)
- [../LemonTea/README.md](../LemonTea/README.md)
- [../LemonTea-vue3/README.md](../LemonTea-vue3/README.md)

## 重要说明

当前版本以联调原型为目标，不是完整生产版。

尤其需要注意：

- WebRTC 当前重点覆盖 DataChannel 控制链路
- 摄像头连续视频流仍是后续工作
- shell 目前是非 PTY 的一次性命令执行模型