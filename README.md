# OpenClaw 飞书插件 API 缓存修复工具

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![OpenClaw](https://img.shields.io/badge/OpenClaw-2026.2.17+-blue.svg)](https://github.com/openclaw/openclaw)

一个自动修复 OpenClaw 飞书(Feishu/Lark)插件高频 API 调用问题的工具。

## 🎯 问题背景

OpenClaw 的飞书通道默认每 60 秒执行一次健康检查，每次检查都会调用 `/open-apis/bot/v3/info` API。这导致：

- **免费版用户**：每月 10,000 次配额在几天内耗尽
- **错误代码**：`99991403 This month's API call quota has been exceeded`
- **日志表现**：飞书后台显示每分钟一次的固定周期调用

## ✅ 解决方案

本工具通过以下策略减少 API 调用：

| 场景 | 缓存时间 | 说明 |
|------|---------|------|
| 成功响应 | 6 小时 | bot 信息变化不频繁 |
| 普通失败 | 10 分钟 | 防止瞬时抖动 |
| 配额超限 (99991403) | **24 小时** | 避免失败风暴 |
| 并发请求 | 自动去重 | 同一时间只发 1 个请求 |

**效果对比：**
- 修复前：~1,440 次/天
- 修复后：~4 次/天（减少 **99.7%**）

## 🔧 使用方法

### 快速运行（推荐）

无需安装，直接运行：

```bash
curl -fsSL https://raw.githubusercontent.com/hutao562/openclaw-feishu-cache-fix/main/fix-feishu-cache.sh | bash
```

运行后会显示交互式菜单：

```
╔══════════════════════════════════════════════════════════════╗
║     OpenClaw 飞书插件 API 缓存修复工具 v1.0.0                ║
╚══════════════════════════════════════════════════════════════╝

请选择操作:

  [1] 🔧 应用缓存修复
  [2] 🔄 恢复原始版本
  [3] 📊 查看当前状态
  [4] ❌ 退出

请输入选项 (1-4):
```

### 命令行参数（非交互模式）

如果需要脚本化调用，可以使用参数：

```bash
# 查看状态
curl -fsSL https://raw.githubusercontent.com/hutao562/openclaw-feishu-cache-fix/main/fix-feishu-cache.sh | bash -s -- --status

# 直接修复（跳过菜单）
curl -fsSL https://raw.githubusercontent.com/hutao562/openclaw-feishu-cache-fix/main/fix-feishu-cache.sh | bash -s -- --path /custom/path

# 恢复原始版本
curl -fsSL https://raw.githubusercontent.com/hutao562/openclaw-feishu-cache-fix/main/fix-feishu-cache.sh | bash -s -- --restore
```

**可用参数：**

| 参数 | 说明 |
|------|------|
| `--status` | 查看当前修复状态 |
| `--restore` | 恢复原始版本 |
| `--path <路径>` | 指定自定义插件路径 |
| `--help` | 显示帮助信息 |

## 🏗️ 项目结构

```
openclaw-feishu-cache-fix/
├── README.md                 # 项目说明文档
├── LICENSE                   # MIT 许可证
├── CHANGELOG.md              # 更新日志
├── CONTRIBUTING.md           # 贡献指南
├── install.sh                # 快速安装脚本
├── fix-feishu-cache.sh       # 主修复脚本（Bash）
├── fix-feishu-cache.ps1      # Windows PowerShell 脚本
├── src/
│   └── probe.ts.template     # 缓存修复模板代码
└── tests/
    └── test-install.sh       # 安装测试脚本
```

## 🖥️ 系统要求

- **OpenClaw**: 2026.2.17 或更高版本
- **操作系统**: Linux, macOS, Windows (WSL)
- **依赖**: bash, curl/wget, systemctl (Linux)

## 🔍 技术细节

### 检测逻辑

脚本会按以下优先级自动检测插件位置：

1. **内置插件**（推荐）：`~/.npm-global/lib/node_modules/openclaw/extensions/feishu/`
2. **独立安装**：`~/.npm-global/lib/node_modules/@openclaw/feishu/`
3. **本地开发**：`~/openclaw/extensions/feishu/`

### 缓存实现

核心修改在 `probeFeishu()` 函数：

```typescript
// 内存缓存（Map）存储 probe 结果
const cache = new Map<string, CacheEntry>();

// 并发去重（in-flight 请求合并）
const inFlight = new Map<string, Promise<FeishuProbeResult>>();

// 缓存 key 包含 domain + appId + appSecret
function keyOf(creds: FeishuClientCredentials) {
  const domain = (creds as any).domain ?? "";
  return `${domain}::${creds.appId}::${creds.appSecret}`;
}
```

## ⚠️ 注意事项

1. **修改前会自动备份**：原始文件保存在 `probe.ts.backup-YYYYMMDD-HHMMSS`
2. **需要重启网关**：修改后脚本会自动重启 OpenClaw 网关
3. **多账户支持**：缓存 key 包含 appId，支持多账户配置
4. **配额超限处理**：错误码 99991403 会缓存 24 小时，避免持续重试

## 🐛 故障排除

### 问题 1：找不到插件位置

**症状**：`❌ 未找到飞书插件安装位置`

**解决**：
```bash
# 手动指定插件路径
./fix-feishu-cache.sh --path /your/custom/path/to/feishu
```

### 问题 2：权限不足

**症状**：`Permission denied`

**解决**：
```bash
chmod +x fix-feishu-cache.sh
sudo ./fix-feishu-cache.sh
```

### 问题 3：网关重启失败

**症状**：`systemctl: command not found`

**解决**：手动重启
```bash
killall openclaw-gateway
openclaw gateway start
```

## 📊 验证修复效果

修复后，可以通过以下方式验证：

### 1. 查看飞书后台日志

登录 [飞书开放平台](https://open.feishu.cn/app/) → 你的应用 → 日志检索

- **修复前**：每分钟一次 `/open-apis/bot/v3/info` 调用
- **修复后**：每 6 小时一次调用（或更少）

### 2. 本地日志检查

```bash
tail -f /tmp/openclaw/openclaw-$(date +%Y-%m-%d).log | grep "bot/v3/info"
```

### 3. 状态检查

```bash
./fix-feishu-cache.sh --status
```

## 🤝 贡献指南

欢迎提交 Issue 和 PR！请阅读 [CONTRIBUTING.md](CONTRIBUTING.md) 了解详情。

## 📜 许可证

本项目采用 [MIT 许可证](LICENSE)。

## 🙏 致谢

- [OpenClaw](https://github.com/openclaw/openclaw) 社区
- [元亨大吉](https://mp.weixin.qq.com/s/KSC-GaRLvF7BTbv3lOlPkg) 的技术分享
- 所有贡献者

## 📮 联系与支持

- **GitHub Issues**: [提交问题](https://github.com/hutao562/openclaw-feishu-cache-fix/issues)
- **讨论区**: [GitHub Discussions](https://github.com/hutao562/openclaw-feishu-cache-fix/discussions)

---

**免责声明**：本工具为非官方社区项目，使用风险自负。建议在修改前备份重要数据。
