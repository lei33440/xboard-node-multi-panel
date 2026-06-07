# Xboard-Node 多面板/多实例安装脚本

<p align="center">
  <img src="https://img.shields.io/badge/Alpine-Linux-blue?style=flat-square&logo=alpine-linux" alt="Alpine Linux">
  <img src="https://img.shields.io/github/v/release/lei33440/xboard-node-multi-panel?style=flat-square" alt="Version">
  <img src="https://img.shields.io/github/stars/lei33440/xboard-node-multi-panel?style=flat-square" alt="Stars">
  <img src="https://img.shields.io/github/forks/lei33440/xboard-node-multi-panel?style=flat-square" alt="Forks">
</p>

一个专为 **Alpine Linux** 设计的 Xboard-Node **多面板/多实例** 一键安装脚本，支持在同一台服务器上对接多个面板。

> 💡 如果你只需要对接**单个面板**，请使用 [xboard-node-alpine-install](https://github.com/lei33440/xboard-node-alpine-install) 项目。

## 功能特性

- ✅ **多面板支持** - 一台服务器对接多个不同面板
- ✅ **独立实例** - 每个实例独立运行，互不影响
- ✅ **独立管理** - 每个实例可单独启动/停止/查看日志
- ✅ **一键部署** - 只需一条命令即可完成安装
- ✅ **自动端口分配** - 自动分配不同端口，避免冲突
- ✅ **多架构支持** - 支持 amd64 和 arm64
- ✅ **稳定的服务管理** - 使用 OpenRC local.d 方式

## 应用场景

| 场景 | 说明 |
|------|------|
| **多线路接入** | 同一台服务器加入多个面板的节点池 |
| **负载均衡** | 多个面板分担流量 |
| **备份方案** | 主面板故障时备用面板仍可用 |
| **测试环境** | 开发测试不同面板配置 |

## 支持的系统

| 系统 | 架构 | 状态 |
|------|------|------|
| Alpine Linux 3.15+ | x86_64 (amd64) | ✅ 支持 |
| Alpine Linux 3.15+ | aarch64 (arm64) | ✅ 支持 |

## 快速开始

### 添加新实例（面板）

```bash
# 添加第一个面板
curl -fsSL https://raw.githubusercontent.com/lei33440/xboard-node-multi-panel/main/install-instance.sh | sh -s --   --name mypanel   --panel http://面板1地址   --token 面板1TOKEN   --machine-id 1

# 添加第二个面板
curl -fsSL https://raw.githubusercontent.com/lei33440/xboard-node-multi-panel/main/install-instance.sh | sh -s --   --name backup   --panel http://面板2地址   --token 面板2TOKEN   --machine-id 1
```

### 参数说明

| 参数 | 必需 | 说明 |
|------|------|------|
| `--name` | 是 | 实例名称（英文，唯一标识） |
| `--panel` | 是 | 面板地址 URL |
| `--token` | 是 | 通信令牌 |
| `--machine-id` | 是 | 机器 ID |
| `--version` | 否 | Xboard-Node 版本（默认：latest） |
| `--help` | 否 | 显示帮助信息 |

## 实例管理

### 查看所有实例

```bash
# 查看所有实例状态
ls -la /etc/xboard-node-*/

# 查看进程
ps aux | grep xboard-node | grep -v grep

# 查看端口
ss -tlnp | grep xboard
```

### 重启所有实例

```bash
# 停止所有
pkill -9 xboard-node

# 启动所有
/etc/local/start-xboard-all
```

### 卸载实例

```bash
# 卸载指定实例
curl -fsSL https://raw.githubusercontent.com/lei33440/xboard-node-multi-panel/main/uninstall-instance.sh | sh -s -- --name mypanel

# 卸载所有实例
curl -fsSL https://raw.githubusercontent.com/lei33440/xboard-node-multi-panel/main/uninstall-all.sh | sh
```

## 文件位置

| 文件 | 路径 |
|------|------|
| 实例配置 | `/etc/xboard-node-{实例名}/config.yml` |
| 实例日志 | `/var/log/xboard-node-{实例名}.log` |
| 启动脚本 | `/etc/local/start-xboard-all` |
| 开机脚本 | `/etc/local.d/xboard-node.start` |

## 常见问题

### Q: 实例名称有什么要求？

A: 只能是英文字母、数字和连字符，不能有特殊字符。例如：`mypanel`、`panel-1`、`backup`。

### Q: 如何确认实例正常运行？

A: 查看进程和端口：
```bash
ps aux | grep xboard-node | grep -v grep
ss -tlnp | grep xboard
```

### Q: 可以同时运行多少个实例？

A: 理论上没有限制，但受服务器性能和端口数量限制。建议不超过 10 个实例。

### Q: 为什么服务状态显示 crashed？

A: 这是正常的。我们的安装脚本使用直接启动方式而不是 OpenRC 服务管理，所以 OpenRC 状态显示可能不准确。只要进程在运行且端口在监听，服务就是正常的。

### Q: 如何备份配置？

A:
```bash
# 备份所有实例配置
tar -czf xboard-node-backup.tar.gz /etc/xboard-node-* /var/log/xboard-node-*.log

# 恢复备份
tar -xzf xboard-node-backup.tar.gz -C /
```

## 更新日志

### v1.0.1 (2026-06-07)
- 🔧 优化服务管理，使用统一的开机启动脚本
- 🔧 修复多实例 OpenRC 服务脚本冲突问题
- 🔧 改进服务启动逻辑
- 📝 更新文档，添加常见问题解答

### v1.0.0 (2026-06-07)
- 🎉 首发版本
- ✅ 支持多面板/多实例
- ✅ 独立实例管理
- ✅ 支持 amd64 和 arm64 架构
- ✅ 自动配置 OpenRC 服务
- ✅ 支持开机自启

## 相关项目

- [xboard-node-alpine-install](https://github.com/lei33440/xboard-node-alpine-install) - 单面板一键安装
- [Xboard](https://github.com/cedar2025/Xboard) - 功能强大的代理面板
- [Xboard-Node](https://github.com/cedar2025/Xboard-Node) - Xboard 节点后端

## 许可证

本项目基于 MPL-2.0 许可证开源。

## 联系方式

- GitHub: https://github.com/lei33440
- 项目反馈: https://github.com/lei33440/xboard-node-multi-panel/issues
