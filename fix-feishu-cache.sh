#!/bin/bash
#
# OpenClaw 飞书插件 API 缓存修复脚本
# 自动检测并修复飞书插件高频 API 调用问题
#
# 使用方法:
#   ./fix-feishu-cache.sh           # 自动检测并修复
#   ./fix-feishu-cache.sh --restore # 恢复原始版本
#   ./fix-feishu-cache.sh --status  # 查看当前状态
#   ./fix-feishu-cache.sh --path /custom/path  # 指定自定义路径
#

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 版本信息
VERSION="1.0.0"

# 可能的插件安装路径（按优先级排序）
PLUGIN_PATHS=(
    # 内置插件（npm 全局安装）
    "$HOME/.npm-global/lib/node_modules/openclaw/extensions/feishu"
    "$HOME/.config/npm/lib/node_modules/openclaw/extensions/feishu"
    "/usr/lib/node_modules/openclaw/extensions/feishu"
    "/usr/local/lib/node_modules/openclaw/extensions/feishu"
    
    # 独立安装（旧版本）
    "$HOME/.npm-global/lib/node_modules/@openclaw/feishu"
    "$HOME/.config/npm/lib/node_modules/@openclaw/feishu"
    "/usr/lib/node_modules/@openclaw/feishu"
    "/usr/local/lib/node_modules/@openclaw/feishu"
    
    # 本地开发路径
    "$HOME/openclaw/extensions/feishu"
    "$HOME/code/openclaw/extensions/feishu"
    "./openclaw/extensions/feishu"
)

# 缓存修复代码（嵌入脚本中，无需外部文件）
CACHE_PROBE_CODE='import type { FeishuProbeResult } from "./types.js";
import { createFeishuClient, type FeishuClientCredentials } from "./client.js";

const OK_TTL_MS = 6 * 60 * 60 * 1000;        // 6小时
const FAIL_TTL_MS = 10 * 60 * 1000;          // 10分钟
const QUOTA_FAIL_TTL_MS = 24 * 60 * 60 * 1000; // 24小时（本月额度用尽）

type CacheEntry = { data: FeishuProbeResult; expiresAt: number };

const cache = new Map<string, CacheEntry>();
const inFlight = new Map<string, Promise<FeishuProbeResult>>();

// 可选：复用 client，减少 tenant_access_token/internal 被频繁触发的概率
const clientCache = new Map<string, unknown>();

function keyOf(creds: FeishuClientCredentials) {
  const domain = (creds as any).domain ?? "";
  return `${domain}::${creds.appId}::${creds.appSecret}`;
}

function getClient(creds: FeishuClientCredentials) {
  const k = keyOf(creds);
  const hit = clientCache.get(k);
  if (hit) return hit;
  const c = createFeishuClient(creds);
  clientCache.set(k, c);
  return c;
}

export async function probeFeishu(creds?: FeishuClientCredentials): Promise<FeishuProbeResult> {
  if (!creds?.appId || !creds?.appSecret) {
    return { ok: false, error: "missing credentials (appId, appSecret)" };
  }

  const k = keyOf(creds);
  const now = Date.now();

  const cached = cache.get(k);
  if (cached && cached.expiresAt > now) return cached.data;

  const running = inFlight.get(k);
  if (running) return await running;

  const p = (async () => {
    try {
      const client = getClient(creds);

      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const response = await (client as any).request({
        method: "GET",
        url: "/open-apis/bot/v3/info",
        data: {},
      });

      if (response.code !== 0) {
        const ttl = response.code === 99991403 ? QUOTA_FAIL_TTL_MS : FAIL_TTL_MS;
        const fail: FeishuProbeResult = {
          ok: false,
          appId: creds.appId,
          error: `API error: ${response.msg || \`code ${response.code}\`}`,
        };
        cache.set(k, { data: fail, expiresAt: now + ttl });
        return fail;
      }

      const bot = response.bot || response.data?.bot;
      const ok: FeishuProbeResult = {
        ok: true,
        appId: creds.appId,
        botName: bot?.bot_name,
        botOpenId: bot?.open_id,
      };
      cache.set(k, { data: ok, expiresAt: now + OK_TTL_MS });
      return ok;
    } catch (err) {
      const fail: FeishuProbeResult = {
        ok: false,
        appId: creds.appId,
        error: err instanceof Error ? err.message : String(err),
      };
      cache.set(k, { data: fail, expiresAt: now + FAIL_TTL_MS });
      return fail;
    } finally {
      inFlight.delete(k);
    }
  })();

  inFlight.set(k, p);
  return await p;
}'

# 打印带颜色的消息 (输出到 stderr，避免被变量捕获)
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}" >&2
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}" >&2
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}" >&2
}

print_error() {
    echo -e "${RED}❌ $1${NC}" >&2
}

print_header() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║     OpenClaw 飞书插件 API 缓存修复工具 v${VERSION}         ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# 显示帮助信息
show_help() {
    cat << EOF
OpenClaw 飞书插件 API 缓存修复工具

使用方法:
    $0 [选项]

选项:
    --help, -h          显示此帮助信息
    --version, -v       显示版本信息
    --restore           恢复原始版本（从备份恢复）
    --status            检查当前状态
    --uninstall         卸载工具并清理安装文件
    --path PATH         指定自定义插件路径
    --dry-run           试运行（不实际修改文件）

示例:
    $0                  # 自动检测并修复（交互式菜单）
    $0 --restore        # 恢复原始版本
    $0 --status         # 查看当前状态
    $0 --uninstall      # 卸载工具
    $0 --path /custom/path/to/feishu  # 指定自定义路径

EOF
}

# 显示版本信息
show_version() {
    echo "OpenClaw 飞书插件 API 缓存修复工具 v${VERSION}"
}

# 检查 OpenClaw 是否安装
check_openclaw_installed() {
    if ! command -v openclaw &> /dev/null; then
        print_error "未找到 OpenClaw 命令，请先安装 OpenClaw"
        exit 1
    fi
    
    local version
    version=$(openclaw --version 2>/dev/null || echo "unknown")
    print_info "检测到 OpenClaw 版本: $version"
}

# 查找插件安装位置
find_plugin_path() {
    local custom_path="$1"
    
    # 如果指定了自定义路径，优先使用
    if [[ -n "$custom_path" ]]; then
        if [[ -d "$custom_path/src" ]]; then
            echo "$custom_path"
            return 0
        else
            print_error "指定的路径不存在或无效: $custom_path"
            return 1
        fi
    fi
    
    # 自动检测
    print_info "正在搜索飞书插件安装位置..."
    
    for path in "${PLUGIN_PATHS[@]}"; do
        if [[ -d "$path/src" ]]; then
            # 检查 probe.ts 是否存在
            if [[ -f "$path/src/probe.ts" ]]; then
                echo "$path"
                return 0
            fi
        fi
    done
    
    return 1
}

# 检测插件类型（内置或独立）
detect_plugin_type() {
    local plugin_path="$1"
    
    if [[ "$plugin_path" == *"openclaw/extensions"* ]]; then
        echo "内置插件"
    elif [[ "$plugin_path" == *"@openclaw/feishu"* ]]; then
        echo "独立安装"
    else
        echo "未知类型"
    fi
}

# 备份原始文件
backup_original() {
    local probe_file="$1"
    local backup_dir="$(dirname "$probe_file")"
    local timestamp
    timestamp=$(date +"%Y%m%d-%H%M%S")
    local backup_file="${backup_dir}/probe.ts.backup-${timestamp}"
    
    if cp "$probe_file" "$backup_file"; then
        echo "$backup_file"
        return 0
    else
        return 1
    fi
}

# 检查是否已经应用过修复
check_if_already_patched() {
    local probe_file="$1"
    
    if grep -q "OK_TTL_MS" "$probe_file" 2>/dev/null; then
        return 0  # 已修复
    else
        return 1  # 未修复
    fi
}

# 应用修复
apply_fix() {
    local plugin_path="$1"
    local probe_file="${plugin_path}/src/probe.ts"
    local dry_run="${2:-false}"
    
    # 检查是否已经修复
    if check_if_already_patched "$probe_file"; then
        print_warning "检测到 probe.ts 已经包含缓存代码，跳过修复"
        return 0
    fi
    
    # 备份
    local backup_file
    backup_file=$(backup_original "$probe_file")
    if [[ $? -ne 0 ]]; then
        print_error "备份失败"
        return 1
    fi
    print_success "已备份原始文件: $(basename "$backup_file")"
    
    # 应用修复
    if [[ "$dry_run" == "true" ]]; then
        print_info "[试运行] 将写入缓存代码到: $probe_file"
        return 0
    fi
    
    # 写入缓存代码
    echo "$CACHE_PROBE_CODE" > "$probe_file"
    
    if [[ $? -eq 0 ]]; then
        print_success "缓存代码已应用"
        return 0
    else
        print_error "应用缓存代码失败"
        return 1
    fi
}

# 恢复原始版本
restore_original() {
    local plugin_path="$1"
    local backup_dir="${plugin_path}/src"
    
    # 查找最新的备份
    local latest_backup
    latest_backup=$(ls -t "${backup_dir}"/probe.ts.backup-* 2>/dev/null | head -1)
    
    if [[ -z "$latest_backup" ]]; then
        print_error "未找到备份文件"
        return 1
    fi
    
    print_info "找到备份: $(basename "$latest_backup")"
    
    local probe_file="${backup_dir}/probe.ts"
    if cp "$latest_backup" "$probe_file"; then
        print_success "已恢复原始版本"
        
        # 重启网关
        restart_gateway
        return 0
    else
        print_error "恢复失败"
        return 1
    fi
}

# 重启 OpenClaw 网关
restart_gateway() {
    print_info "正在重启 OpenClaw 网关..."
    
    # 尝试使用 systemctl
    if command -v systemctl &> /dev/null; then
        if systemctl --user restart openclaw-gateway 2>/dev/null; then
            print_success "网关已重启 (systemctl)"
            sleep 3
            return 0
        fi
    fi
    
    # 备用方案：直接 kill 并启动
    if killall openclaw-gateway 2>/dev/null; then
        sleep 2
    fi
    
    if openclaw gateway start &>/dev/null; then
        print_success "网关已重启"
        sleep 3
        return 0
    fi
    
    print_warning "自动重启失败，请手动运行: openclaw gateway restart"
    return 1
}

# 检查当前状态
check_status() {
    local plugin_path
    plugin_path=$(find_plugin_path "")
    
    if [[ -z "$plugin_path" ]]; then
        print_error "未找到飞书插件"
        return 1
    fi
    
    local probe_file="${plugin_path}/src/probe.ts"
    local plugin_type
    plugin_type=$(detect_plugin_type "$plugin_path")
    
    echo ""
    echo "📍 插件位置: $plugin_path"
    echo "📦 插件类型: $plugin_type"
    echo ""
    
    if check_if_already_patched "$probe_file"; then
        print_success "状态: 已应用缓存修复 ✅"
        
        # 显示缓存配置
        local ok_ttl fail_ttl quota_ttl
        ok_ttl=$(grep "OK_TTL_MS" "$probe_file" | head -1 | grep -o "[0-9]*" | head -1)
        fail_ttl=$(grep "FAIL_TTL_MS" "$probe_file" | head -1 | grep -o "[0-9]*" | head -1)
        quota_ttl=$(grep "QUOTA_FAIL_TTL_MS" "$probe_file" | head -1 | grep -o "[0-9]*" | head -1)
        
        echo ""
        echo "📊 缓存配置:"
        echo "   • 成功响应缓存: $((ok_ttl / 3600000)) 小时"
        echo "   • 普通失败缓存: $((fail_ttl / 60000)) 分钟"
        echo "   • 配额超限缓存: $((quota_ttl / 3600000)) 小时"
    else
        print_warning "状态: 未应用缓存修复 ⚠️"
        echo ""
        echo "💡 建议运行: $0"
    fi
    
    # 检查备份
    local backup_count
    backup_count=$(ls "${plugin_path}/src"/probe.ts.backup-* 2>/dev/null | wc -l)
    if [[ $backup_count -gt 0 ]]; then
        echo ""
        echo "📁 备份文件: $backup_count 个"
    fi
    
    echo ""
}

# 卸载工具
uninstall_tool() {
    print_header
    echo ""
    print_warning "即将卸载 OpenClaw 飞书缓存修复工具"
    echo ""
    
    local install_dir="$HOME/.openclaw-feishu-cache-fix"
    local bin_link="$HOME/.local/bin/fix-feishu-cache"
    local removed=0
    
    # 1. 尝试恢复原始版本（如果已修复）
    local plugin_path
    if plugin_path=$(find_plugin_path "" 2>/dev/null); then
        if [[ -f "$plugin_path/src/probe.ts" ]]; then
            if check_if_already_patched "$plugin_path/src/probe.ts"; then
                print_info "检测到已应用缓存修复，正在恢复原始版本..."
                if restore_original "$plugin_path" 2>/dev/null; then
                    print_success "已恢复原始版本"
                else
                    print_warning "恢复原始版本失败，请手动检查"
                fi
            fi
        fi
    fi
    
    # 2. 删除命令链接
    if [[ -L "$bin_link" ]] || [[ -f "$bin_link" ]]; then
        rm -f "$bin_link"
        print_success "已删除命令链接: $bin_link"
        removed=1
    fi
    
    # 3. 删除安装目录
    if [[ -d "$install_dir" ]]; then
        rm -rf "$install_dir"
        print_success "已删除安装目录: $install_dir"
        removed=1
    fi
    
    echo ""
    if [[ $removed -eq 1 ]]; then
        print_success "卸载完成！"
        echo ""
        echo "📋 残留检查:"
        echo "  • 插件备份文件: 保留在插件目录（如需清理请手动删除）"
        echo "  • PATH 环境变量: 如需清理请编辑 ~/.zshrc 或 ~/.bashrc"
    else
        print_info "未找到已安装的文件，无需卸载"
    fi
    echo ""
}

# 显示交互式菜单
show_menu() {
    print_header
    echo ""
    echo "请选择操作:"
    echo ""
    echo "  [1] 🔧 应用缓存修复"
    echo "  [2] 🔄 恢复原始版本"
    echo "  [3] 📊 查看当前状态"
    echo "  [4] 🗑️  卸载工具"
    echo "  [5] ❌ 退出"
    echo ""
}

# 读取用户选择
read_choice() {
    local choice
    read -p "请输入选项 (1-5): " choice
    echo "$choice"
}

# 主函数
main() {
    local custom_path=""
    local dry_run=false
    local action=""  # 空表示交互模式
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                show_help
                exit 0
                ;;
            --version|-v)
                show_version
                exit 0
                ;;
            --restore)
                action="restore"
                shift
                ;;
            --status)
                action="status"
                shift
                ;;
                --uninstall)
                action="uninstall"
                shift
                ;;
            --path)
                custom_path="$2"
                shift 2
                ;;
            --dry-run)
                dry_run=true
                shift
                ;;
            *)
                print_error "未知选项: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # 如果没有指定动作，进入交互模式
    if [[ -z "$action" ]]; then
        show_menu
        local choice
        choice=$(read_choice)
        
        case $choice in
            1)
                action="fix"
                ;;
            2)
                action="restore"
                ;;
            3)
                action="status"
                ;;
            4)
                uninstall_tool
                exit 0
                ;;
            5|*)
                echo ""
                echo "👋 再见!"
                exit 0
                ;;
        esac
    else
        # 非交互模式，先打印 header
        print_header
    fi
    
    # 状态检查
    if [[ "$action" == "status" ]]; then
        check_status
        exit 0
    fi
    
    # 卸载模式
    if [[ "$action" == "uninstall" ]]; then
        uninstall_tool
        exit 0
    fi
    
    # 检查 OpenClaw 安装
    check_openclaw_installed
    
    # 查找插件
    local plugin_path
    if ! plugin_path=$(find_plugin_path "$custom_path"); then
        print_error "未找到飞书插件安装位置"
        echo ""
        echo "已搜索的路径:"
        for path in "${PLUGIN_PATHS[@]}"; do
            echo "  - $path"
        done
        echo ""
        echo "💡 提示: 使用 --path 参数指定自定义路径"
        exit 1
    fi
    
    local plugin_type
    plugin_type=$(detect_plugin_type "$plugin_path")
    
    print_success "找到 $plugin_type: $plugin_path"
    
    # 恢复模式
    if [[ "$action" == "restore" ]]; then
        restore_original "$plugin_path"
        exit $?
    fi
    
    # 修复模式
    echo ""
    print_info "开始应用缓存修复..."
    
    if apply_fix "$plugin_path" "$dry_run"; then
        if [[ "$dry_run" != "true" ]]; then
            restart_gateway
            
            echo ""
            print_success "修复完成！🎉"
            echo ""
            echo "📊 预期效果:"
            echo "   • 修复前: ~1,440 次/天"
            echo "   • 修复后: ~4 次/天"
            echo "   • 减少: 99.7%"
            echo ""
            echo "⏰ 请 10 分钟后检查飞书后台日志验证效果"
            echo ""
        fi
    else
        print_error "修复失败"
        exit 1
    fi
}

# 运行主函数
main "$@"
