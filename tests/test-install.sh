#!/bin/bash
#
# 安装测试脚本
# 用于验证 fix-feishu-cache 工具的基本功能
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
FIX_SCRIPT="$PROJECT_DIR/fix-feishu-cache.sh"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${BLUE}[TEST]${NC} $1"; }
print_success() { echo -e "${GREEN}[PASS]${NC} $1"; }
print_error() { echo -e "${RED}[FAIL]${NC} $1"; }
print_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# 测试计数
TESTS_PASSED=0
TESTS_FAILED=0

# 运行单个测试
run_test() {
    local test_name="$1"
    local test_cmd="$2"
    
    print_info "运行: $test_name"
    if eval "$test_cmd" > /dev/null 2>&1; then
        print_success "$test_name"
        ((TESTS_PASSED++))
        return 0
    else
        print_error "$test_name"
        ((TESTS_FAILED++))
        return 1
    fi
}

# 测试 1: 脚本文件存在
test_script_exists() {
    run_test "脚本文件存在" "[[ -f $FIX_SCRIPT ]]"
}

# 测试 2: 脚本可执行
test_script_executable() {
    run_test "脚本可执行" "[[ -x $FIX_SCRIPT ]]"
}

# 测试 3: 显示帮助
test_help() {
    run_test "显示帮助 (--help)" "$FIX_SCRIPT --help"
}

# 测试 4: 显示版本
test_version() {
    run_test "显示版本 (--version)" "$FIX_SCRIPT --version"
}

# 测试 5: 显示状态（可能失败如果没有安装 OpenClaw）
test_status() {
    if command -v openclaw &> /dev/null; then
        run_test "显示状态 (--status)" "$FIX_SCRIPT --status"
    else
        print_warn "跳过状态测试（未安装 OpenClaw）"
    fi
}

# 测试 6: 试运行模式
test_dry_run() {
    run_test "试运行模式 (--dry-run)" "$FIX_SCRIPT --dry-run"
}

# 测试 7: 检查代码完整性
test_code_integrity() {
    local required_patterns=(
        "OK_TTL_MS"
        "FAIL_TTL_MS"
        "QUOTA_FAIL_TTL_MS"
        "probeFeishu"
        "cache"
    )
    
    local all_found=true
    for pattern in "${required_patterns[@]}"; do
        if ! grep -q "$pattern" "$FIX_SCRIPT"; then
            print_error "缺少关键代码: $pattern"
            all_found=false
        fi
    done
    
    if $all_found; then
        print_success "代码完整性检查"
        ((TESTS_PASSED++))
    else
        ((TESTS_FAILED++))
    fi
}

# 测试 8: 检查函数定义
test_functions() {
    local required_functions=(
        "print_info"
        "print_success"
        "print_error"
        "find_plugin_path"
        "apply_fix"
        "backup_original"
    )
    
    local all_found=true
    for func in "${required_functions[@]}"; do
        if ! grep -q "^$func()" "$FIX_SCRIPT" && ! grep -q "function $func" "$FIX_SCRIPT"; then
            print_error "缺少函数: $func"
            all_found=false
        fi
    done
    
    if $all_found; then
        print_success "函数定义检查"
        ((TESTS_PASSED++))
    else
        ((TESTS_FAILED++))
    fi
}

# 测试 9: 语法检查
test_syntax() {
    run_test "Bash 语法检查" "bash -n $FIX_SCRIPT"
}

# 测试 10: 检查文档
test_documentation() {
    local readme="$PROJECT_DIR/README.md"
    if [[ -f $readme ]]; then
        run_test "README 存在" "[[ -f $readme ]]"
    else
        print_error "README.md 不存在"
        ((TESTS_FAILED++))
    fi
}

# 主测试函数
main() {
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║           OpenClaw 飞书缓存修复工具 - 测试套件              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    
    cd "$PROJECT_DIR"
    
    # 确保脚本可执行
    chmod +x "$FIX_SCRIPT"
    
    # 运行所有测试
    test_script_exists
    test_script_executable
    test_help
    test_version
    test_status
    test_dry_run
    test_code_integrity
    test_functions
    test_syntax
    test_documentation
    
    # 输出总结
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  测试完成:"
    echo "    通过: $TESTS_PASSED"
    echo "    失败: $TESTS_FAILED"
    echo "═══════════════════════════════════════════════════════════════"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo ""
        print_success "所有测试通过！✅"
        exit 0
    else
        echo ""
        print_error "部分测试失败，请检查以上输出"
        exit 1
    fi
}

main "$@"
