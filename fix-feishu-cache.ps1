#Requires -Version 5.1
<#
.SYNOPSIS
    OpenClaw 飞书插件 API 缓存修复工具 (Windows PowerShell 版本)
.DESCRIPTION
    自动检测并修复飞书插件高频 API 调用问题
.PARAMETER Restore
    恢复原始版本（从备份恢复）
.PARAMETER Status
    检查当前状态
.PARAMETER Path
    指定自定义插件路径
.PARAMETER DryRun
    试运行（不实际修改文件）
.EXAMPLE
    .\fix-feishu-cache.ps1
    # 自动检测并修复
.EXAMPLE
    .\fix-feishu-cache.ps1 -Restore
    # 恢复原始版本
.EXAMPLE
    .\fix-feishu-cache.ps1 -Status
    # 查看当前状态
.EXAMPLE
    .\fix-feishu-cache.ps1 -Path "C:\custom\path\to\feishu"
    # 指定自定义路径
#>

[CmdletBinding()]
param(
    [switch]$Restore,
    [switch]$Status,
    [string]$Path,
    [switch]$DryRun
)

# 版本信息
$VERSION = "1.0.0"

# 颜色定义
function Write-Info($message) { Write-Host "ℹ️  $message" -ForegroundColor Cyan }
function Write-Success($message) { Write-Host "✅ $message" -ForegroundColor Green }
function Write-Warning($message) { Write-Host "⚠️  $message" -ForegroundColor Yellow }
function Write-Error($message) { Write-Host "❌ $message" -ForegroundColor Red }

# 可能的插件安装路径（按优先级排序）
$PLUGIN_PATHS = @(
    # 内置插件（npm 全局安装）
    "$env:USERPROFILE\.npm-global\lib\node_modules\openclaw\extensions\feishu"
    "$env:USERPROFILE\AppData\Roaming\npm\node_modules\openclaw\extensions\feishu"
    "$env:ProgramFiles\nodejs\node_modules\openclaw\extensions\feishu"
    
    # WSL 路径
    "\wsl$\Ubuntu\home\$env:USERNAME\.npm-global\lib\node_modules\openclaw\extensions\feishu"
    
    # 独立安装（旧版本）
    "$env:USERPROFILE\.npm-global\lib\node_modules\@openclaw\feishu"
    "$env:USERPROFILE\AppData\Roaming\npm\node_modules\@openclaw\feishu"
)

function Show-Header {
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║     OpenClaw 飞书插件 API 缓存修复工具 v$VERSION         ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

function Find-PluginPath {
    param([string]$CustomPath)
    
    # 如果指定了自定义路径，优先使用
    if ($CustomPath) {
        $probePath = Join-Path $CustomPath "src\probe.ts"
        if (Test-Path $probePath) {
            return $CustomPath
        } else {
            Write-Error "指定的路径不存在或无效: $CustomPath"
            return $null
        }
    }
    
    # 自动检测
    Write-Info "正在搜索飞书插件安装位置..."
    
    foreach ($path in $PLUGIN_PATHS) {
        $probePath = Join-Path $path "src\probe.ts"
        if (Test-Path $probePath) {
            return $path
        }
    }
    
    return $null
}

function Get-PluginType {
    param([string]$PluginPath)
    
    if ($PluginPath -like "*openclaw\extensions*") {
        return "内置插件"
    } elseif ($PluginPath -like "*@openclaw\feishu*") {
        return "独立安装"
    } else {
        return "未知类型"
    }
}

function Test-AlreadyPatched {
    param([string]$ProbeFile)
    
    $content = Get-Content $ProbeFile -Raw -ErrorAction SilentlyContinue
    return $content -match "OK_TTL_MS"
}

function Backup-Original {
    param([string]$ProbeFile)
    
    $backupDir = Split-Path $ProbeFile -Parent
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $backupFile = Join-Path $backupDir "probe.ts.backup-$timestamp"
    
    try {
        Copy-Item $ProbeFile $backupFile -Force
        return $backupFile
    } catch {
        return $null
    }
}

function Apply-Fix {
    param(
        [string]$PluginPath,
        [bool]$DryRun = $false
    )
    
    $probeFile = Join-Path $PluginPath "src\probe.ts"
    
    # 检查是否已经修复
    if (Test-AlreadyPatched $probeFile) {
        Write-Warning "检测到 probe.ts 已经包含缓存代码，跳过修复"
        return $true
    }
    
    # 备份
    $backupFile = Backup-Original $probeFile
    if (-not $backupFile) {
        Write-Error "备份失败"
        return $false
    }
    Write-Success "已备份原始文件: $(Split-Path $backupFile -Leaf)"
    
    # 应用修复
    if ($DryRun) {
        Write-Info "[试运行] 将写入缓存代码到: $probeFile"
        return $true
    }
    
    try {
        # 使用 here-string 直接写入代码，避免转义问题
        $probeCode = @'
import type { FeishuProbeResult } from "./types.js";
import { createFeishuClient, type FeishuClientCredentials } from "./client.js";

const OK_TTL_MS = 6 * 60 * 60 * 1000;
const FAIL_TTL_MS = 10 * 60 * 1000;
const QUOTA_FAIL_TTL_MS = 24 * 60 * 60 * 1000;

type CacheEntry = { data: FeishuProbeResult; expiresAt: number };

const cache = new Map<string, CacheEntry>();
const inFlight = new Map<string, Promise<FeishuProbeResult>>();
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
          error: "API error: " + (response.msg || "code " + response.code),
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
}
'@
        $probeCode | Out-File $probeFile -Encoding UTF8 -NoNewline
        Write-Success "缓存代码已应用"
        return $true
    } catch {
        Write-Error "应用缓存代码失败: $_"
        return $false
    }
}

function Restore-Original {
    param([string]$PluginPath)
    
    $backupDir = Join-Path $PluginPath "src"
    $backups = Get-ChildItem $backupDir -Filter "probe.ts.backup-*" -ErrorAction SilentlyContinue | 
               Sort-Object LastWriteTime -Descending
    
    if (-not $backups) {
        Write-Error "未找到备份文件"
        return $false
    }
    
    $latestBackup = $backups[0]
    Write-Info "找到备份: $($latestBackup.Name)"
    
    $probeFile = Join-Path $backupDir "probe.ts"
    try {
        Copy-Item $latestBackup.FullName $probeFile -Force
        Write-Success "已恢复原始版本"
        return $true
    } catch {
        Write-Error "恢复失败: $_"
        return $false
    }
}

function Restart-Gateway {
    Write-Info "正在重启 OpenClaw 网关..."
    
    # 尝试使用 WSL
    $wslAvailable = $false
    try {
        $wslResult = wsl echo "test" 2>$null
        if ($wslResult -eq "test") {
            $wslAvailable = $true
        }
    } catch {}
    
    if ($wslAvailable) {
        try {
            wsl systemctl --user restart openclaw-gateway 2>$null
            Write-Success "网关已重启 (WSL systemctl)"
            Start-Sleep -Seconds 3
            return $true
        } catch {}
        
        try {
            wsl bash -c "killall openclaw-gateway 2>/dev/null; sleep 2; openclaw gateway start" 2>$null
            Write-Success "网关已重启 (WSL)"
            Start-Sleep -Seconds 3
            return $true
        } catch {}
    }
    
    Write-Warning "自动重启失败，请在 WSL 中手动运行: openclaw gateway restart"
    return $false
}

function Show-Status {
    $pluginPath = Find-PluginPath ""
    
    if (-not $pluginPath) {
        Write-Error "未找到飞书插件"
        return
    }
    
    $probeFile = Join-Path $pluginPath "src\probe.ts"
    $pluginType = Get-PluginType $pluginPath
    
    Write-Host ""
    Write-Host "📍 插件位置: $pluginPath"
    Write-Host "📦 插件类型: $pluginType"
    Write-Host ""
    
    if (Test-AlreadyPatched $probeFile) {
        Write-Success "状态: 已应用缓存修复 ✅"
        
        $content = Get-Content $probeFile -Raw
        
        # 解析缓存配置
        if ($content -match "OK_TTL_MS\s*=\s*(\d+)") {
            $okHours = [int]($matches[1] / 3600000)
            Write-Host ""
            Write-Host "📊 缓存配置:"
            Write-Host "   • 成功响应缓存: $okHours 小时"
        }
    } else {
        Write-Warning "状态: 未应用缓存修复 ⚠️"
        Write-Host ""
        Write-Host "💡 建议运行: .\fix-feishu-cache.ps1"
    }
    
    $backupDir = Join-Path $pluginPath "src"
    $backups = Get-ChildItem $backupDir -Filter "probe.ts.backup-*" -ErrorAction SilentlyContinue
    if ($backups) {
        Write-Host ""
        Write-Host "📁 备份文件: $($backups.Count) 个"
    }
    
    Write-Host ""
}

# 主程序
Show-Header

# 状态检查
if ($Status) {
    Show-Status
    exit 0
}

# 查找插件
$pluginPath = Find-PluginPath $Path
if (-not $pluginPath) {
    Write-Error "未找到飞书插件安装位置"
    Write-Host ""
    Write-Host "已搜索的路径:"
    $PLUGIN_PATHS | ForEach-Object { Write-Host "  - $_" }
    Write-Host ""
    Write-Host "💡 提示: 使用 -Path 参数指定自定义路径"
    exit 1
}

$pluginType = Get-PluginType $pluginPath
Write-Success "找到 $pluginType`: $pluginPath"

# 恢复模式
if ($Restore) {
    if (Restore-Original $pluginPath) {
        Restart-Gateway
    }
    exit 0
}

# 修复模式
Write-Host ""
Write-Info "开始应用缓存修复..."

if (Apply-Fix $pluginPath $DryRun) {
    if (-not $DryRun) {
        Restart-Gateway
        
        Write-Host ""
        Write-Success "修复完成！🎉"
        Write-Host ""
        Write-Host "📊 预期效果:"
        Write-Host "   • 修复前: ~1,440 次/天"
        Write-Host "   • 修复后: ~4 次/天"
        Write-Host "   • 减少: 99.7%"
        Write-Host ""
        Write-Host "⏰ 请 10 分钟后检查飞书后台日志验证效果"
        Write-Host ""
    }
} else {
    exit 1
}
