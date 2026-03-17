# LemonTea / HoneyTea 测试版架构说明

## 1. 当前交付范围

本次交付实现的是一套可在本地进行联调的测试原型，覆盖以下链路：

- HoneyTea 客户端主动连接 LemonTea 服务端
- LemonTea 使用 Crow 暴露 HTTP API
- 服务端通过 TCP 或 WebRTC 控制链路向客户端下发命令
- 客户端支持 shell 执行、文件列目录、文件下载、文件写入
- 客户端支持基于 TCP JSON 的子进程插件管理
- 服务端支持本地插件管理
- 客户端具备断线重连与心跳
- 子进程采用“程序 + manifest.json”模式接入
- LemonTea-vue3 提供四个独立图形功能页

## 2. 目录说明

- HoneyTea: 客户端测试程序
- LemonTea: 服务端测试程序
- LemonTea-doc: 文档仓库
- LemonTea-vue3: 前端仓库，已实现控制台原型

## 3. 系统结构

### 3.1 HoneyTea

HoneyTea 当前由一个主进程和多个插件子进程组成：

- 主进程负责连接 LemonTea
- 主进程负责把控制请求分发到 shell、文件系统或本地插件
- 插件子进程通过本地 TCP 端口暴露能力
- 插件通过 manifest 描述启动方式、端口、名称

### 3.2 LemonTea

LemonTea 当前由两个部分组成：

- 一个 TCP 或 WebRTC 信令入口，用于接收 HoneyTea 的控制连接
- 一个 Crow HTTP 服务，用于把客户端能力暴露成 HTTP API

请求路径如下：

1. 前端或测试工具调用 LemonTea HTTP API
2. LemonTea 生成控制请求并转发给 HoneyTea
3. HoneyTea 执行命令或访问插件
4. HoneyTea 将结果回传给 LemonTea
5. LemonTea 返回 HTTP JSON 响应

## 4. 通信协议

### 4.1 LemonTea <-> HoneyTea

当前测试版本支持两种模式：

- TCP：基于按行 JSON 的控制协议
- WebRTC：基于 libdatachannel 的 DataChannel 控制协议

模式由配置文件中的 `transport.mode` 决定。

当前协议消息类型：

- hello
- heartbeat
- shell_exec
- list_files
- read_file
- write_file
- plugin_list
- plugin_call
- plugin_start
- plugin_stop
- response

WebRTC 模式另外包含信令消息：

- signal_hello
- description
- candidate

### 4.2 主进程 <-> 插件子进程

采用本地 TCP + JSON 单请求单响应模式。

请求示例：

```json
{"action":"get_status","payload":{}}
```

响应示例：

```json
{"ok":true,"data":{"supported":true}}
```

## 5. 子进程接入规范

每个插件由一个 manifest 文件描述，字段如下：

```json
{
  "name": "camera",
  "description": "camera bridge",
  "executable": "python3",
  "script": "camera_plugin.py",
  "port": 9101,
  "auto_start": true
}
```

约束如下：

- 插件自行监听 manifest 指定的本地端口
- 插件按行读取 JSON 请求
- 插件按行返回 JSON 响应
- 插件无需侵入主进程，只要遵循协议即可接入

## 6. 已提供的测试插件

HoneyTea 侧：

- camera: 枚举 macOS 摄像头，若安装 imagesnap 可抓取单帧图片
- angle_sensor: 自动探测系统中可能存在的角度/方向相关字段
- light_sensor: 自动探测系统中可能存在的环境光相关控制器和数值

LemonTea 侧：

- server_echo: 服务端本地插件样例，可用于验证服务端插件管理链路

## 7. 日志与调试

HoneyTea 和 LemonTea 都会输出带时间戳的日志，便于观察：

- 连接建立
- 心跳
- 请求分发
- 子进程启动/停止
- 异常与重连

## 8. 前端结构

LemonTea-vue3 当前已经提供：

- 主页导航
- SSH 控制页
- 文件管理页
- HoneyTea 子进程管理页
- LemonTea 子进程管理页

前端全部通过 LemonTea 的 Crow HTTP API 与系统交互，不直接连接 HoneyTea。

## 9. 后续建议演进

建议按以下顺序继续增强：

1. 把摄像头能力升级为连续视频帧推送
2. 在 WebRTC 模式上继续增加媒体轨支持
3. 把 shell 改为真正的交互式 PTY，而不是当前一次性命令执行
4. 引入鉴权、访问控制、文件权限限制和审计日志
