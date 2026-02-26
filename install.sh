#!/bin/bash
#
# OpenClaw 飞书插件 API 缓存修复工具 - 快速安装脚本
#
# 使用方法:
#   curl -fsSL https://raw.githubusercontent.com/hutao562/openclaw-feishu-cache-fix/main/install.sh | bash
#

set -e

REPO_URL="https://github.com/hutao562/openclaw-feishu-cache-fix"
INSTALL_DIR="$HOME/.openclaw-feishu-cache-fix"
BIN_DIR="$HOME/.local/bin"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }

print_header() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║  OpenClaw 飞书插件 API 缓存修复工具 - 快速安装              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# 检查依赖
check_dependencies() {
    local missing=()
    
    if ! command -v curl &> /dev/null && ! command -v wget &> /dev/null; then
        missing+=("curl 或 wget")
    fi
    
    if ! command -v git &> /dev/null; then
        missing+=("git")
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        print_error "缺少必要的依赖: ${missing[*]}"
        echo "请安装后重试"
        exit 1
    fi
}

# 下载并安装
install_tool() {
    print_info "正在下载..."
    
    # 清理旧版本
    if [[ -d "$INSTALL_DIR" ]]; then
        rm -rf "$INSTALL_DIR"
    fi
    
    # 克隆仓库
    if command -v git &> /dev/null; then
        git clone --depth 1 "$REPO_URL.git" "$INSTALL_DIR" 2>/dev/null
    fi
    
    # 如果 git 失败，尝试直接下载
    if [[ ! -d "$INSTALL_DIR" ]]; then
        print_info "使用备用下载方式..."
        mkdir -p "$INSTALL_DIR"
        cd "$INSTALL_DIR"
        
        # 下载主脚本
        if command -v curl &> /dev/null; then
            curl -fsSL "$REPO_URL/raw/main/fix-feishu-cache.sh" -o fix-feishu-cache.sh
            curl -fsSL "$REPO_URL/raw/main/README.md" -o README.md
        elif command -v wget &> /dev/null; then
            wget -q "$REPO_URL/raw/main/fix-feishu-cache.sh" -O fix-feishu-cache.sh
            wget -q "$REPO_URL/raw/main/README.md" -O README.md
        fi
    fi
    
    # 设置权限
    chmod +x "$INSTALL_DIR/fix-feishu-cache.sh"
    
    # 创建 bin 目录
    mkdir -p "$BIN_DIR"
    
    # 创建符号链接
    ln -sf "$INSTALL_DIR/fix-feishu-cache.sh" "$BIN_DIR/fix-feishu-cache"
    
    print_success "安装完成！"
}

# 添加到 PATH
add_to_path() {
    local shell_rc=""
    
    if [[ -n "$ZSH_VERSION" ]] || [[ "$SHELL" == *"zsh"* ]]; then
        shell_rc="$HOME/.zshrc"
    elif [[ -n "$BASH_VERSION" ]] || [[ "$SHELL" == *"bash"* ]]; then
        shell_rc="$HOME/.bashrc"
    else
        shell_rc="$HOME/.profile"
    fi
    
    if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
        print_info "添加 $BIN_DIR 到 PATH..."
        echo "export PATH=\"\$PATH:$BIN_DIR\"" >> "$shell_rc"
        print_warning "请运行: source $shell_rc"
    fi
}

# 验证安装
verify_install() {
    echo ""
    print_info "验证安装..."
    
    if [[ -f "$INSTALL_DIR/fix-feishu-cache.sh" ]]; then
        print_success "主脚本已安装"
    else
        print_error "安装失败"
        exit 1
    fi
    
    if [[ -L "$BIN_DIR/fix-feishu-cache" ]]; then
        print_success "命令链接已创建"
    fi
    
    # 检查 OpenClaw
    if command -v openclaw &> /dev/null; then
        print_success "OpenClaw 已安装"
    else
        print_warning "未检测到 OpenClaw，请先安装"
    fi
}

# 显示使用说明
show_usage() {
    echo ""
    echo "🎉 安装成功！"
    echo ""
    echo "使用方法:"
    echo "  fix-feishu-cache           # 自动检测并修复"
    echo "  fix-feishu-cache --status  # 查看当前状态"
    echo "  fix-feishu-cache --restore # 恢复原始版本"
    echo ""
    echo "或直接运行:"
    echo "  $INSTALL_DIR/fix-feishu-cache.sh"
    echo ""
    echo "📖 更多信息请查看: $INSTALL_DIR/README.md"
    echo ""
    echo "⚡ 建议立即运行修复:"
    echo "  fix-feishu-cache"
    echo ""
}

# 主程序
main() {
    print_header
    
    check_dependencies
    install_tool
    add_to_path
    verify_install
    show_usage
}

main "$@"
