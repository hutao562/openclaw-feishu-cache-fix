# OpenClaw 飞书缓存修复 - AI 执行指南

> 这是给 OpenClaw AI 看的文件。如果你是人类用户，请把下面这段文字发给你的 OpenClaw：
> 
> **"请阅读 https://raw.githubusercontent.com/hutao562/openclaw-feishu-cache-fix/main/OPENCLAW.md 并按指示执行飞书缓存修复"**

---

## 任务说明

你的用户遇到了 OpenClaw 飞书插件 API 配额超限问题。本指南告诉你如何自动为他们执行修复。

## 执行步骤

### 步骤 1：下载修复脚本

```bash
curl -fsSL https://raw.githubusercontent.com/hutao562/openclaw-feishu-cache-fix/main/fix-feishu-cache.sh -o /tmp/fix-feishu-cache.sh
```

### 步骤 2：检测飞书插件位置

优先检查以下路径：

```bash
# 常见安装位置（按优先级）
~/.npm-global/lib/node_modules/openclaw/extensions/feishu
/usr/local/lib/node_modules/openclaw/extensions/feishu
/usr/lib/node_modules/openclaw/extensions/feishu
~/.local/share/fnm/node-versions/*/installation/lib/node_modules/openclaw/extensions/feishu
```

使用 `find` 或 `ls` 命令确认路径存在。

### 步骤 3：执行修复

**如果找到插件路径：**

```bash
bash /tmp/fix-feishu-cache.sh --path <检测到的路径>
```

**如果脚本提示需要交互：**
- 使用 `echo "1" | bash /tmp/fix-feishu-cache.sh --path <路径>` 自动选择选项 1（应用缓存修复）

**如果自动检测失败：**
- 询问用户飞书插件的安装位置
- 或者尝试常见路径逐一测试

### 步骤 4：重启网关

修复完成后，重启 OpenClaw 网关使修改生效：

```bash
openclaw gateway restart
```

或

```bash
killall openclaw-gateway 2>/dev/null; openclaw gateway start
```

### 步骤 5：验证修复

检查修复是否成功：

```bash
grep "OK_TTL_MS" <插件路径>/src/probe.ts
```

如果输出包含 `OK_TTL_MS`，说明修复成功。

## 故障处理

### 找不到插件位置

询问用户：
> "我找不到你的飞书插件安装位置。你能告诉我 OpenClaw 装在哪里吗？或者运行 `openclaw --version` 看看安装路径？"

### 权限不足

尝试使用 `sudo`：
```bash
sudo bash /tmp/fix-feishu-cache.sh --path <路径>
```

或修改文件权限：
```bash
chmod +x /tmp/fix-feishu-cache.sh
```

### 备份恢复

如果修复后出现问题，帮用户恢复：

```bash
bash /tmp/fix-feishu-cache.sh --path <路径> --restore
```

## 成功标准

- ✅ 脚本执行无错误
- ✅ probe.ts 包含 `OK_TTL_MS` 缓存代码
- ✅ 网关重启成功
- ✅ `--status` 检查显示"已应用缓存修复"

## 向用户报告

修复完成后，告诉用户：

1. **修复已完成** - API 调用从 ~1,440 次/天降到 ~4 次/天
2. **如何验证** - 登录飞书开放平台查看日志，调用频率应大幅降低
3. **注意事项** - 如果配额已用完，需要等下个月恢复

## 参考信息

- 项目地址：https://github.com/hutao562/openclaw-feishu-cache-fix
- 效果：减少 99.7% 的 API 调用
- 缓存策略：成功 6 小时，失败 10 分钟，配额超限 24 小时
