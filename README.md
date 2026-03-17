# LemonTea 远程控制测试原型

当前仓库包含一套用于本地联调的测试版远程控制系统文档。

## 仓库角色

- HoneyTea: 客户端，负责命令执行、文件访问、子进程插件管理
- LemonTea: 服务端，负责接收 HoneyTea 连接，并通过 Crow 暴露 HTTP API
- LemonTea-doc: 文档仓库
- LemonTea-vue3: 前端仓库，提供图形化控制台

## 本次已交付内容

- HoneyTea C++17 双模式客户端
- LemonTea C++17 双模式服务端
- Crow HTTP API
- 文件读写与目录浏览
- 命令执行
- 客户端插件机制
- 服务端插件机制
- 自动重连与心跳日志
- TCP / WebRTC 双模式切换
- macOS 摄像头枚举插件
- macOS 角度/光线传感器能力探测插件
- LemonTea-vue3 图形化控制台

## 重要说明

当前版本是测试原型，不是完整生产版。

当前 LemonTea 与 HoneyTea 已支持两种传输模式：

- TCP JSON 控制链路
- WebRTC DataChannel 控制链路

两种模式通过配置文件中的 `transport.mode` 字段切换。

## 文档索引

- [architecture.md](architecture.md): 架构、协议、插件规范
- [http-api.md](http-api.md): Crow HTTP API 说明和 curl 示例
- [macos-testing.md](macos-testing.md): macOS 联调范围与限制说明

## 快速开始

1. 先构建 LemonTea 服务端
2. 再构建 HoneyTea 客户端
3. 先启动 LemonTea，再启动 HoneyTea
4. 启动 LemonTea-vue3 或使用 curl 访问 LemonTea 的 HTTP API

示例接口：

```bash
curl http://127.0.0.1:18080/health
```

```bash
curl -X POST http://127.0.0.1:18080/api/clients/raspi-dev-01/shell \
	-H 'Content-Type: application/json' \
	-d '{"command":"uname -a"}'
```