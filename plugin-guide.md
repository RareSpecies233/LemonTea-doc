# LemonTea / HoneyTea 插件编写指南

本文档说明前端可识别并安装的插件包规范。当前规范同时适用于：

- HoneyTea 客户端插件
- LemonTea 服务端插件

## 1. 插件包基本约束

前端上传安装插件时，会把一个插件包拆成两部分发送给后端：

- `manifest`: 一个 JSON 对象
- `files`: 一组附带文件，通常包含 Python 脚本与它依赖的本地资源

后端会把插件安装到托管目录，例如：

- HoneyTea: `plugins/installed/<plugin-name>/`
- LemonTea: `plugins/installed/<plugin-name>/`

要被前端识别并成功安装，插件必须满足以下约束：

1. `name` 只能包含字母、数字、`.`、`_`、`-`
2. `script` 必须是相对路径，不能是绝对路径
3. 任意附带文件路径都不能包含 `..` 跳出插件目录
4. `port` 必须是有效的本地 TCP 监听端口
5. 上传时必须同时提交 manifest 和 manifest 所引用的入口脚本

## 2. Manifest 规范

推荐 manifest 如下：

```json
{
  "name": "camera",
  "description": "macOS camera bridge",
  "version": "1.0.0",
  "protocol_version": 1,
  "capabilities": ["list_devices", "capture_once", "get_status"],
  "executable": "python3",
  "script": "camera_plugin.py",
  "port": 9101,
  "auto_start": true
}
```

字段说明：

- `name`: 插件唯一标识，也是安装目录名
- `description`: 前端展示文案
- `version`: 插件版本号，建议使用语义化版本
- `protocol_version`: 插件协议版本，当前固定为 `1`
- `capabilities`: 插件声明的动作或能力列表，前端会用于展示
- `executable`: 启动命令，默认可用 `python3`
- `script`: 入口脚本相对路径
- `port`: 插件监听的本地端口
- `auto_start`: 安装完成后是否自动启动

## 3. 运行协议

主进程和插件子进程之间使用按行 JSON 的单请求单响应协议。

请求示例：

```json
{"action":"get_status","payload":{}}
```

响应示例：

```json
{"ok":true,"data":{"supported":true}}
```

推荐响应字段：

- `ok`: 布尔值，表示调用是否成功
- `data`: 正常响应内容
- `error`: 错误信息，失败时返回

## 4. 前端上传安装流程

当前 LemonTea-vue3 支持两种上传方式：

- 选择一组插件文件
- 选择整个插件目录

安装时的行为如下：

1. 前端解析 manifest
2. 前端将除 manifest 之外的文件内容编码为 base64
3. 后端校验 `name`、`script`、`port` 与文件路径
4. 后端写入托管目录并载入 manifest
5. 若 `auto_start=true`，则自动启动插件进程

如果同名插件已存在，可以在前端勾选“覆盖安装”。

## 5. Python 插件最小示例

```python
import json
import socket
import sys


def handle(action, payload):
    if action == "get_status":
        return {"ok": True, "data": {"plugin": "demo", "ready": True}}
    if action == "echo":
        return {"ok": True, "data": payload}
    return {"ok": False, "error": f"unsupported action: {action}"}


def main():
    port = int(sys.argv[1])
    server = socket.create_server(("127.0.0.1", port), reuse_port=False)
    while True:
        conn, _ = server.accept()
        with conn:
            request = conn.makefile("r", encoding="utf-8").readline()
            if not request:
                continue
            payload = json.loads(request)
            response = handle(payload.get("action", ""), payload.get("payload", {}))
            conn.sendall((json.dumps(response) + "\n").encode("utf-8"))


if __name__ == "__main__":
    main()
```

## 6. 建议实践

1. 插件动作名称尽量稳定，例如 `get_status`、`read`、`capture_once`
2. 失败时始终返回结构化错误，不要只在标准输出打印
3. 端口避免与现有插件冲突，建议按客户端 `9100+`、服务端 `9200+` 规划
4. 若插件会再拉起其他进程，建议也响应 `SIGTERM`，确保主进程退出时能一起清理