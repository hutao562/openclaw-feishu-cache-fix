# OpenClaw 飞书插件 API 缓存修复工具

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![OpenClaw](https://img.shields.io/badge/OpenClaw-2026.2.17+-blue.svg)](https://github.com/openclaw/openclaw)

> 一键修复 OpenClaw 飞书插件 API 配额超限问题，让免费版用户也能愉快使用。

## 🚀 快速开始（选一种方式）

### 方式 A：让 OpenClaw 自己修（最省事）

**把这句话复制发给你的 OpenClaw：**

```
请阅读 https://raw.githubusercontent.com/hutao562/openclaw-feishu-cache-fix/main/OPENCLAW.md 并按指示执行飞书缓存修复
```

然后等着它告诉你修好了就行。

### 方式 B：手动运行（30秒搞定）

**选择你的系统，复制对应命令：**

#### Linux / macOS / WSL

```bash
curl -fsSL https://raw.githubusercontent.com/hutao562/openclaw-feishu-cache-fix/main/fix-feishu-cache.sh -o /tmp/fix.sh && bash /tmp/fix.sh
```

运行后显示菜单，输入 `1` 回车即可。

#### Windows (PowerShell)

```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/hutao562/openclaw-feishu-cache-fix/main/fix-feishu-cache.ps1" -OutFile "$env:TEMP\fix.ps1"; & "$env:TEMP\fix.ps1"
```

**第一次运行 PowerShell 脚本？** 先执行：
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
```

---

## 📖 详细使用指南

### 交互式菜单（推荐新手）

下载脚本后运行，会显示友好的菜单界面：

```
╔══════════════════════════════════════════════════════════════╗
║     OpenClaw 飞书插件 API 缓存修复工具 v1.0.0                ║
╚══════════════════════════════════════════════════════════════╝

请选择操作:

  [1] 🔧 应用缓存修复    ← 选这个，一键搞定
  [2] 🔄 恢复原始版本    ← 后悔药，恢复备份
  [3] 📊 查看当前状态    ← 看看修好了没
  [4] 🗑️  卸载本工具     ← 清理所有文件
  [5] ❌ 退出
```

### 命令行参数（适合自动化）

懒得看菜单？直接用参数：

```bash
# Linux/macOS - 直接修复（无需交互）
curl -fsSL https://raw.githubusercontent.com/hutao562/openclaw-feishu-cache-fix/main/fix-feishu-cache.sh | bash -s -- --status

# Windows PowerShell - 直接修复
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/hutao562/openclaw-feishu-cache-fix/main/fix-feishu-cache.ps1" -OutFile "fix.ps1"
.\fix.ps1 -Status
```

**常用参数：**

| 参数 | 作用 | 示例 |
|------|------|------|
| `--status` / `-Status` | 查看当前状态 | 检查是否已经修复 |
| `--restore` / `-Restore` | 恢复原始版本 | 从备份还原 |
| `--uninstall` | 卸载本工具 | 删除所有相关文件 |
| `--path <路径>` / `-Path` | 指定插件位置 | 自动检测失败时使用 |

---

## ✅ 验证修复成功

运行完修复命令后，可以通过以下方式确认是否生效：

### 方法1：看飞书后台（最直观）

登录 [飞书开放平台](https://open.feishu.cn/app/) → 你的应用 → **日志检索**

| 时间 | 修复前 | 修复后 |
|------|--------|--------|
| 第1分钟 | 有 `bot/v3/info` 记录 | 有记录（最后一次）|
| 第2-60分钟 | 每分钟都有记录 | **没有记录** ✅ |
| 第6小时后 | 已有 360 条记录 | 才有下一条记录 ✅ |

**说明**：修复成功后，API 调用从每分钟1次变成每6小时1次。

### 方法2：脚本自检（最简单）

```bash
bash fix-feishu-cache.sh --status
```

看到 `已应用缓存修复 ✅` 就对了。

### 方法3：本地看日志（适合技术党）

```bash
# 持续监控 OpenClaw 日志
tail -f /tmp/openclaw/openclaw-$(date +%Y-%m-%d).log | grep "bot/v3/info"
```

观察几分钟，如果**没有新的调用记录**就是成功了。按 `Ctrl+C` 退出。

---

## 🤔 这是什么？能解决什么问题？

### 问题现象

如果你在使用 OpenClaw 的飞书通道，可能会遇到：

- **飞书机器人突然不回复了**
- **日志里出现**：`99991403 This month's API call quota has been exceeded`
- **飞书后台显示**：每分钟都在调用 `/open-apis/bot/v3/info`

**原因**：OpenClaw 默认每 60 秒检查一次飞书连接状态，每次检查都调用 API。免费版每月只有 10,000 次配额，一周左右就用完了。

### 解决方案

本工具给 OpenClaw 的飞书插件加个"缓存层"：

| 情况 | 原来 | 修复后 | 说明 |
|------|------|--------|------|
| 正常时 | 每分钟查 1 次 | 6 小时查 1 次 | 省 99.3% |
| 出错了 | 每分钟重试 | 10 分钟重试 | 防止刷屏 |
| 配额用完 | 一直重试 | 24 小时后再试 | 避免雪上加霜 |
| 同时多个请求 | 每个都发 | 合并成 1 个 | 去重优化 |

**效果**：API 调用从 **~1,440 次/天** 降到 **~4 次/天**，免费版绰绰有余。

---

## 🖥️ 系统要求

| 系统 | 要求 | 备注 |
|------|------|------|
| **Linux** | bash + curl | 几乎所有发行版都自带 |
| **macOS** | bash + curl | 系统自带 |
| **Windows** | PowerShell 5.1+ 或 WSL | Win10/11 都支持 |
| **OpenClaw** | 2026.2.17+ | 飞书插件需已安装 |

**不懂命令行？** Windows 用户推荐用 [Git Bash](https://git-scm.com/download/win)，界面和 Linux 一样。

---

## 🛠️ 工作原理（可选阅读）

### 1. 自动找插件位置

脚本会智能猜测你的 OpenClaw 飞书插件装在哪：

```
1. ~/.npm-global/lib/node_modules/openclaw/extensions/feishu  ← 最常见
2. /usr/lib/node_modules/openclaw/extensions/feishu           ← 系统安装
3. ~/openclaw/extensions/feishu                               ← 本地开发
```

找不到？用 `--path` 手动指定：
```bash
bash fix-feishu-cache.sh --path /你的/自定义/路径
```

### 2. 自动备份

修改前，脚本会把原始文件备份为 `probe.ts.backup-20260226-143022`（带时间戳）。

**误操作了？** 运行 `--restore` 一键还原。

### 3. 修改代码

把飞书插件的核心文件 `probe.ts` 替换为带缓存的版本，核心逻辑：

```typescript
// 加个内存缓存
const cache = new Map<string, CacheEntry>();

// 检查缓存，有就直接返回
if (cached && cached.expiresAt > now) return cached.data;

// 同时多个请求？合并成一个
if (running) return await running;
```

### 4. 自动重启

修改完成后，脚本会自动重启 OpenClaw 网关，立即生效。

---

## 🐛 常见问题

### Q1: 运行命令没反应？

**可能是网络问题**，手动下载再运行：

```bash
# 用浏览器访问下面链接，下载文件
# https://raw.githubusercontent.com/hutao562/openclaw-feishu-cache-fix/main/fix-feishu-cache.sh

# 然后本地运行
bash fix-feishu-cache.sh
```

### Q2: 提示 "未找到飞书插件"？

**说明你装了 OpenClaw 但没装飞书插件**，先安装：
```bash
openclaw install feishu
```

或者你的插件装在奇怪的位置，手动指定：
```bash
bash fix-feishu-cache.sh --path /usr/lib/node_modules/openclaw/extensions/feishu
```

### Q3: 提示 "Permission denied"？

Linux/macOS 需要执行权限：
```bash
chmod +x fix-feishu-cache.sh
./fix-feishu-cache.sh
```

或者直接用 `bash` 运行（不需要 chmod）：
```bash
bash fix-feishu-cache.sh
```

### Q4: Windows 提示 "无法加载脚本"？

PowerShell 默认禁止运行脚本，需要改执行策略：
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
```

### Q5: 修复后飞书还是不工作？

可能是**配额已经用完**了，等下个月自动恢复，或者：
1. 检查飞书后台是否显示 API 调用减少了
2. 用 `--status` 查看修复状态
3. 重启 OpenClaw 网关：`openclaw gateway restart`

```
openclaw-feishu-cache-fix/
├── README.md                 # 本文件
├── LICENSE                   # MIT 开源协议
├── fix-feishu-cache.sh       # Linux/macOS 脚本
├── fix-feishu-cache.ps1      # Windows 脚本
└── src/
    └── probe.ts.template     # 缓存代码模板（供参考）
```

**没有 install.sh？** 对，本工具设计理念就是**用完即走**，不需要安装，运行完脚本可以删掉。

---

## 🤝 参与贡献

发现 bug 或有新想法？欢迎：
- [提交 Issue](https://github.com/hutao562/openclaw-feishu-cache-fix/issues)
- [发起讨论](https://github.com/hutao562/openclaw-feishu-cache-fix/discussions)

---

## 📜 许可证

MIT 协议，随便用，出问题别找我 😄

---

**最后**：如果这工具帮到了你，点个 ⭐ Star 鼓励一下作者吧！
