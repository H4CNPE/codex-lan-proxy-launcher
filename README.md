# Codex LAN Proxy Launcher

让 Windows 版 Codex 的 Chromium 前端与 Codex 后台进程同时通过局域网 HTTP 代理连接，无需 TUN 模式，也不会设置系统全局代理。

## 为什么需要这个启动器

只给 `ChatGPT.exe` 添加 `--proxy-server` 参数时，Chromium 网络进程会走代理，但 Codex 后台进程仍可能直连公网并反复重连。本项目同时完成两件事：

1. 向 Chromium 传入 `--proxy-server`；
2. 在启动前注入 `HTTP_PROXY`、`HTTPS_PROXY` 和 `ALL_PROXY`，让子进程继承代理。

## 安装

要求：Windows 10/11、已安装 Windows 版 Codex、可访问的 HTTP 或 mixed 代理端口。

1. 编辑 `proxy-config.json`：

   ```json
   {
     "host": "192.168.0.130",
     "port": 7893
   }
   ```

2. 在项目目录运行：

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\Install.ps1
   ```

3. 从系统托盘完全退出已经运行的 Codex。
4. 双击桌面的 **Codex (LAN Proxy)**。

启动器不会修改系统代理，也不会结束已运行的 Codex。检测到 Codex 正在运行时，它会提示先退出，从而避免中断现有聊天。

## 验证

通过快捷方式启动 Codex 后运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Verify.ps1
```

正确结果应满足：

- `MainProcessHasProxyArguments: True`
- `ProxyConnectionCount` 大于 0
- `NonProxyInternetConnectionCount: 0`
- `Verified: True`

启动日志保存在 `%LOCALAPPDATA%\CodexLanProxyLauncher\launcher.log`。

## 卸载

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Uninstall.ps1
```

卸载脚本仅删除桌面快捷方式，不修改 Codex 或聊天数据。

## 来源与许可

本项目基于 [Capedvilla/codex-without-tun](https://github.com/Capedvilla/codex-without-tun) 的思路扩展，修正了新版 Windows Codex 使用 `ChatGPT.exe` 作为主进程的情况，并为 Codex 后台进程补充代理环境变量传递。

使用 MIT License，原项目版权声明保留在 [LICENSE](LICENSE) 中。

