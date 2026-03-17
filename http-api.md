# LemonTea HTTP API

当前 HTTP API 由 Crow 提供，默认监听 `18080` 端口。

无论 LemonTea 与 HoneyTea 之间底层选用 TCP 还是 WebRTC，前端调用方式都保持不变。

## 1. 健康检查

### GET /health

返回服务端状态和当前已连接客户端列表。

## 2. 客户端列表

### GET /api/clients

返回所有已连接 HoneyTea 客户端。

## 3. 执行命令

### POST /api/clients/{clientId}/shell

请求体：

```json
{
  "command": "uname -a"
}
```

## 4. 列目录

### GET /api/clients/{clientId}/files?path=

参数：

- path: 相对于客户端 `file_root` 的路径

## 5. 下载文件

### GET /api/clients/{clientId}/file?path=relative/path.txt

返回 base64 文件内容。

## 6. 上传/写文件

### POST /api/clients/{clientId}/file/write

请求体：

```json
{
  "path": "tmp/hello.txt",
  "content_base64": "aGVsbG8K"
}
```

## 7. 查看客户端插件

### GET /api/clients/{clientId}/plugins

## 8. 调用客户端插件

### POST /api/clients/{clientId}/plugins/{pluginName}/call

请求体：

```json
{
  "action": "get_status",
  "payload": {}
}
```

摄像头抓拍示例：

```json
{
  "action": "capture_once",
  "payload": {
    "device_name": "FaceTime HD Camera"
  }
}
```

## 9. 启停客户端插件

### POST /api/clients/{clientId}/plugins/{pluginName}/start

### POST /api/clients/{clientId}/plugins/{pluginName}/stop

## 10. 查看服务端插件

### GET /api/server/plugins

## 11. 调用服务端插件

### POST /api/server/plugins/{pluginName}/call

请求体：

```json
{
  "action": "echo",
  "payload": {
    "message": "hello"
  }
}
```

## 12. 启停服务端插件

### POST /api/server/plugins/{pluginName}/start

### POST /api/server/plugins/{pluginName}/stop

## 13. curl 测试示例

### 获取客户端列表

```bash
curl http://127.0.0.1:18080/api/clients
```

### 在客户端执行命令

```bash
curl -X POST http://127.0.0.1:18080/api/clients/raspi-dev-01/shell \
  -H 'Content-Type: application/json' \
  -d '{"command":"pwd && ls -la"}'
```

### 查看客户端插件状态

```bash
curl http://127.0.0.1:18080/api/clients/raspi-dev-01/plugins
```

### 调用摄像头插件

```bash
curl -X POST http://127.0.0.1:18080/api/clients/raspi-dev-01/plugins/camera/call \
  -H 'Content-Type: application/json' \
  -d '{"action":"list_devices","payload":{}}'
```
