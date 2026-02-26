# 项目结构说明

## 文件列表

```
openclaw-feishu-cache-fix/
├── README.md                   # 项目主文档（中文）
├── LICENSE                     # MIT 许可证
├── CHANGELOG.md                # 更新日志
├── CONTRIBUTING.md             # 贡献指南
├── PROJECT_STRUCTURE.md        # 本文件
├── .gitignore                  # Git 忽略规则
│
├── fix-feishu-cache.sh         # 主修复脚本（Bash/Linux/macOS）
├── fix-feishu-cache.ps1        # Windows PowerShell 脚本
├── install.sh                  # 快速安装脚本
│
├── src/
│   └── probe.ts.template       # 缓存修复模板代码（TypeScript）
│
└── tests/
    └── test-install.sh         # 安装测试脚本
```

## 文件说明

### 核心脚本

| 文件 | 用途 | 平台 |
|-----|------|------|
| `fix-feishu-cache.sh` | 主修复脚本，自动检测并修复 | Linux/macOS/WSL |
| `fix-feishu-cache.ps1` | Windows PowerShell 版本 | Windows |
| `install.sh` | 一键安装脚本（下载+安装+配置PATH） | 全平台 |

### 文档

| 文件 | 内容 |
|-----|------|
| `README.md` | 项目介绍、使用方法、故障排除 |
| `LICENSE` | MIT 许可证 |
| `CHANGELOG.md` | 版本更新记录 |
| `CONTRIBUTING.md` | 贡献指南、代码规范 |
| `PROJECT_STRUCTURE.md` | 本文件，项目结构说明 |

### 源代码

| 文件 | 内容 |
|-----|------|
| `src/probe.ts.template` | 完整的缓存修复 TypeScript 代码模板 |

### 测试

| 文件 | 内容 |
|-----|------|
| `tests/test-install.sh` | 自动化测试脚本，验证脚本完整性 |

## 使用流程

### 1. 快速安装（推荐）

```bash
curl -fsSL https://raw.githubusercontent.com/yourusername/openclaw-feishu-cache-fix/main/install.sh | bash
```

### 2. 手动使用

```bash
# 下载项目
git clone https://github.com/yourusername/openclaw-feishu-cache-fix.git
cd openclaw-feishu-cache-fix

# 运行修复
chmod +x fix-feishu-cache.sh
./fix-feishu-cache.sh
```

### 3. 命令选项

```bash
fix-feishu-cache --help

# 常用命令
fix-feishu-cache              # 自动检测并修复
fix-feishu-cache --status     # 查看当前状态
fix-feishu-cache --restore    # 恢复原始版本
fix-feishu-cache --dry-run    # 试运行（不修改）
```

## 工作原理

### 自动检测逻辑

脚本按以下优先级自动检测插件位置：

1. **内置插件**（npm 全局安装）：
   - `~/.npm-global/lib/node_modules/openclaw/extensions/feishu`
   - `/usr/lib/node_modules/openclaw/extensions/feishu`
   
2. **独立安装**（旧版本）：
   - `~/.npm-global/lib/node_modules/@openclaw/feishu`
   - `/usr/lib/node_modules/@openclaw/feishu`

3. **本地开发**：
   - `~/openclaw/extensions/feishu`

### 缓存策略

| 场景 | 缓存时间 | 说明 |
|-----|---------|------|
| 成功响应 | 6 小时 | bot 信息变化不频繁 |
| 普通失败 | 10 分钟 | 防止瞬时抖动 |
| 配额超限 (99991403) | 24 小时 | 避免失败风暴 |
| 并发请求 | 自动去重 | in-flight 请求合并 |

### 备份机制

每次修改前自动创建备份：
- 命名格式：`probe.ts.backup-YYYYMMDD-HHMMSS`
- 存储位置：`probe.ts` 同级目录
- 恢复命令：`fix-feishu-cache --restore`

## 发布检查清单

在发布到 GitHub 前，请确认：

- [ ] 更新 `README.md` 中的 GitHub 链接
- [ ] 更新 `install.sh` 中的仓库地址
- [ ] 检查版本号一致性（脚本和文档）
- [ ] 运行测试脚本 `./tests/test-install.sh`
- [ ] 添加 GitHub Actions（可选）
- [ ] 创建 GitHub Release
- [ ] 更新 `CHANGELOG.md`

## GitHub 仓库设置建议

### 必要配置

1. **Settings** → **General**
   - 描述：`自动修复 OpenClaw 飞书插件高频 API 调用问题`
   - 主题：`openclaw`, `feishu`, `lark`, `api-cache`, `rate-limit`

2. **Settings** → **Topics**
   - 添加：openclaw, feishu, lark, cache-fix, rate-limit

3. **Settings** → **Manage access**
   - 添加协作者（如有）

### 可选配置

1. **GitHub Actions**
   - 添加自动化测试
   - 添加代码风格检查

2. **Issues Templates**
   - Bug 报告模板
   - 功能请求模板

3. **Pull Request Template**
   - 规范 PR 描述

---

**注意**：使用前请确保已阅读 `README.md` 中的使用说明和注意事项。
