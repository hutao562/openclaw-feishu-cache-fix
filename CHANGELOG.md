# 更新日志

所有重要的变更都将记录在此文件中。

格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.0.0/)，
并且本项目遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

## [未发布]

## [1.0.0] - 2026-02-26

### 🎉 初始发布

#### 新增

- ✅ 自动检测飞书插件安装位置（内置/独立安装）
- ✅ 智能缓存机制：
  - 成功响应缓存：6 小时
  - 普通失败缓存：10 分钟
  - 配额超限缓存：24 小时（错误码 99991403）
- ✅ 并发请求去重（in-flight 合并）
- ✅ 自动备份原始文件
- ✅ 一键恢复功能
- ✅ 多平台支持（Linux/macOS/Windows WSL）
- ✅ 完整的命令行界面

#### 修复

- 🔧 修复飞书插件每分钟调用 `/bot/v3/info` 导致 API 配额耗尽的问题
- 🔧 修复配额超限后的"失败风暴"问题

#### 性能

- 🚀 API 调用从 ~1,440 次/天 降至 ~4 次/天（减少 99.7%）

## [1.0.0] - 2026-02-26

### Added

- Initial release with all core features
- Bash and PowerShell scripts
- Automatic plugin location detection
- Caching mechanism for API calls
- Backup and restore functionality
- Complete documentation

[未发布]: https://github.com/yourusername/openclaw-feishu-cache-fix/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/yourusername/openclaw-feishu-cache-fix/releases/tag/v1.0.0
