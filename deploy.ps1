# ============================================
# ZCode 一键人格部署工具
# 使用: 右键 -> 使用 PowerShell 运行
# 或: powershell -ExecutionPolicy Bypass -File deploy.ps1 install
# ============================================
param(
    [Parameter(Position=0)]
    [ValidateSet("install","restore","status")]
    [string]$Action = "status"
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$PromptFile = Join-Path $ScriptDir "人格.txt"

# === 自动检测 ZCode 安装路径 ===
function Find-ZCode {
    $candidates = @(
        "F:\zcode",
        "C:\zcode",
        "D:\zcode",
        "$env:LOCALAPPDATA\Programs\zcode",
        "$env:LOCALAPPDATA\Programs\ZCode",
        "C:\Program Files\zcode",
        "C:\Program Files\ZCode",
        "C:\Program Files (x86)\zcode"
    )
    # 也尝试从运行中的进程检测
    try {
        $proc = Get-Process -Name "ZCode" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($proc -and $proc.Path) {
            $procDir = Split-Path -Parent $proc.Path
            if (Test-Path (Join-Path $procDir "resources\glm\zcode.cjs")) {
                return $procDir
            }
        }
    } catch {}
    foreach ($c in $candidates) {
        if (Test-Path (Join-Path $c "resources\glm\zcode.cjs")) {
            return $c
        }
    }
    # 扫描所有盘符根目录
    foreach ($drive in (Get-PSDrive -PSType FileSystem)) {
        $p = Join-Path $drive.Root "zcode"
        if (Test-Path (Join-Path $p "resources\glm\zcode.cjs")) {
            return $p
        }
    }
    return $null
}

$ZcodeDir = Find-ZCode

if (-not $ZcodeDir) {
    Write-Host "[ERROR] 未找到 ZCode 安装目录" -ForegroundColor Red
    Write-Host "请确认 ZCode 已安装" -ForegroundColor Yellow
    Write-Host "支持路径: F:\zcode, C:\zcode, AppData\Programs\zcode 等" -ForegroundColor Gray
    exit 1
}

$ZcodeCjs    = Join-Path $ZcodeDir "resources\glm\zcode.cjs"
$ZcodeBackup = "$ZcodeCjs.bak"
$ZcodeExe    = Join-Path $ZcodeDir "ZCode.exe"

# 转换路径为正斜杠（JS 兼容）
$PromptFileJS = $PromptFile -replace '\\', '/'

Write-Host "ZCode 目录:  $ZcodeDir" -ForegroundColor Cyan
Write-Host "人格文件:    $PromptFile" -ForegroundColor Cyan
Write-Host ""

function Kill-ZCode {
    Get-Process -Name "ZCode" -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Seconds 3
}

function Start-ZCode {
    # 用 WMI 完全脱离父进程启动，关窗口不会杀 ZCode
    Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{CommandLine = "`"$ZcodeExe`""} | Out-Null
    Start-Sleep -Seconds 5
    $count = (Get-Process -Name "ZCode" -ErrorAction SilentlyContinue).Count
    Write-Host "[OK] ZCode 已启动 ($count 个进程)" -ForegroundColor Green
}

function Test-Modified {
    if (-not (Test-Path $ZcodeCjs)) { return $false }
    $content = [System.IO.File]::ReadAllText($ZcodeCjs)
    return $content.Contains($PromptFileJS)
}

switch ($Action) {

    "status" {
        Write-Host "=== ZCode 部署状态 ===" -ForegroundColor Cyan
        Write-Host ""
        $modified = Test-Modified
        $hasBak = Test-Path $ZcodeBackup
        $hasPrompt = Test-Path $PromptFile
        $promptSize = if ($hasPrompt) { (Get-Item $PromptFile).Length } else { 0 }
        Write-Host "ZCode:     $ZcodeDir"
        Write-Host "备份:      $(if ($hasBak) { '有' } else { '无' })"
        Write-Host "人格文件:  $(if ($hasPrompt) { "有 ($promptSize bytes)" } else { '无' })"
        Write-Host "已部署:    $(if ($modified) { '是' } else { '否' })"
        Write-Host ""
        if ($modified) {
            Write-Host "模式: 自定义人格" -ForegroundColor Yellow
        } else {
            Write-Host "模式: ZCode 原版" -ForegroundColor Green
        }
    }

    "install" {
        Write-Host "[1/5] 检查人格文件..." -ForegroundColor Cyan
        if (-not (Test-Path $PromptFile)) {
            Write-Host "  [ERROR] 未找到 $PromptFile" -ForegroundColor Red
            Write-Host "  请把人格文件放在脚本同目录，命名为 人格.txt" -ForegroundColor Yellow
            exit 1
        }
        $pSize = (Get-Item $PromptFile).Length
        Write-Host "  [OK] $PromptFile ($pSize bytes)" -ForegroundColor Green

        Write-Host "[2/5] 备份原文件..." -ForegroundColor Cyan
        if (-not (Test-Path $ZcodeBackup)) {
            Copy-Item $ZcodeCjs $ZcodeBackup -Force
            Write-Host "  备份 -> $ZcodeBackup" -ForegroundColor Gray
        } else {
            Write-Host "  备份已存在" -ForegroundColor Gray
        }

        Write-Host "[3/5] 修改 zcode.cjs..." -ForegroundColor Cyan
        $content = [System.IO.File]::ReadAllText($ZcodeCjs)

        # 补丁 1: CLI Prefix 置空
        $old1 = 'Djo="You are ZCode, an interactive coding agent"'
        $new1 = 'Djo=""'
        if ($content.Contains($old1)) {
            $content = $content.Replace($old1, $new1)
            Write-Host "  [OK] CLI Prefix 已置空" -ForegroundColor Green
        } elseif ($content.Contains($new1)) {
            Write-Host "  [跳过] 已修改过" -ForegroundColor Gray
        } else {
            Write-Host "  [警告] 未找到目标" -ForegroundColor Yellow
        }

        # 补丁 2: build() 读外部文件
        $old2 = 'n=this.config.customSystemPrompt?.trim(),o=!!n;'
        $new2 = "n=(function(){try{return require(`"fs`").readFileSync(`"$PromptFileJS`",`"utf8`")}catch(e){return null}})()?.trim(),o=!!n;"
        if ($content.Contains($old2)) {
            $content = $content.Replace($old2, $new2)
            Write-Host "  [OK] system prompt 已改为读外部文件" -ForegroundColor Green
        } elseif ($content.Contains($PromptFileJS)) {
            Write-Host "  [跳过] 已修改过" -ForegroundColor Gray
        } else {
            Write-Host "  [警告] 未找到目标" -ForegroundColor Yellow
        }

        # 补丁 3: Eut() 读外部文件
        $old3 = 'function Eut(e){let t=Njo(e);return{name:"Agent Identity",source:"identity",injectionTarget:"system",cacheHint:"stable",chars:t.length,tokens:ns(t),content:t,preview:t.slice(0,100)}}'
        $new3 = "function Eut(e){let t;try{t=require(`"fs`").readFileSync(`"$PromptFileJS`",`"utf8`")}catch(r){t=Njo(e)}return{name:`"Agent Identity`",source:`"identity`",injectionTarget:`"system`",cacheHint:`"stable`",chars:t.length,tokens:ns(t),content:t,preview:t.slice(0,100)}}"
        if ($content.Contains($old3)) {
            $content = $content.Replace($old3, $new3)
            Write-Host "  [OK] Agent Identity 已改为读外部文件" -ForegroundColor Green
        } elseif ($content.Contains("function Eut(e){let t;try")) {
            Write-Host "  [跳过] 已修改过" -ForegroundColor Gray
        } else {
            Write-Host "  [警告] 未找到目标" -ForegroundColor Yellow
        }

        # 补丁 4: 日期提醒移除
        $freIdx = $content.IndexOf("function fre(e){if(!e)return null")
        if ($freIdx -ge 0) {
            $freEnd = $content.IndexOf("}}", $freIdx)
            $fullFre = $content.Substring($freIdx, $freEnd - $freIdx + 2)
            $content = $content.Replace($fullFre, "function fre(e){return null}")
            Write-Host "  [OK] 日期提醒已移除" -ForegroundColor Green
        } elseif ($content.Contains("function fre(e){return null}")) {
            Write-Host "  [跳过] 已修改过" -ForegroundColor Gray
        } else {
            Write-Host "  [警告] 未找到目标" -ForegroundColor Yellow
        }

        # 补丁 5: Skills 列表注入移除
        $old5 = 'function sre(e){if(e.outcome.skills.length===0)return null;let t=iFo(e.outcome.skills,e.metadataBudget??nFo);return{name:"Skills",source:"skills",injectionTarget:"meta_user",cacheHint:"dynamic",chars:t.length,tokens:ns(t),content:t,preview:t.slice(0,100)}}'
        $new5 = 'function sre(e){return null}'
        if ($content.Contains($old5)) {
            $content = $content.Replace($old5, $new5)
            Write-Host "  [OK] Skills 列表注入已移除" -ForegroundColor Green
        } elseif ($content.Contains($new5)) {
            Write-Host "  [跳过] 已修改过" -ForegroundColor Gray
        } else {
            Write-Host "  [警告] 未找到目标" -ForegroundColor Yellow
        }
        # 补丁 6: Request User Context 注入移除
        $old6 = 'function F1e(e){let t=HFo(e);return t?{name:"Request User Context",source:"request_user_context",injectionTarget:"meta_user",cacheHint:"dynamic",chars:t.length,tokens:ns(t),content:t,preview:t.slice(0,100)}:null}'
        $new6 = 'function F1e(e){return null}'
        if ($content.Contains($old6)) {
            $content = $content.Replace($old6, $new6)
            Write-Host "  [OK] Request User Context 注入已移除" -ForegroundColor Green
        } elseif ($content.Contains($new6)) {
            Write-Host "  [跳过] 已修改过" -ForegroundColor Gray
        } else {
            Write-Host "  [警告] 未找到目标" -ForegroundColor Yellow
        }
                [System.IO.File]::WriteAllText($ZcodeCjs, $content, [System.Text.UTF8Encoding]::new($false))
        Write-Host "  文件已保存" -ForegroundColor Gray

        Write-Host "[4/5] 检查路径..." -ForegroundColor Cyan
        Write-Host "  人格文件路径: $PromptFileJS" -ForegroundColor Gray
        Write-Host "  (此路径已写入 zcode.cjs，换机器需重新跑 install)" -ForegroundColor Gray

        Write-Host "[5/5] 重启 ZCode..." -ForegroundColor Cyan
        Kill-ZCode
        Start-ZCode

        Write-Host ""
        Write-Host "=== 部署完成 ===" -ForegroundColor Green
        Write-Host ""
        Write-Host "System prompt 文件: $PromptFile" -ForegroundColor Yellow
        Write-Host "编辑该文件即可换人格，新对话生效" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "注意: 如果把此文件夹移到别的位置，需要重新跑 install" -ForegroundColor Yellow
        Write-Host "      (因为路径写死在 zcode.cjs 里)" -ForegroundColor Yellow
    }

    "restore" {
        Write-Host "[1/3] 还原代码..." -ForegroundColor Cyan
        if (Test-Path $ZcodeBackup) {
            Copy-Item $ZcodeBackup $ZcodeCjs -Force
            Write-Host "  [OK] 已还原" -ForegroundColor Green
        } else {
            Write-Host "  [ERROR] 备份不存在" -ForegroundColor Red
            exit 1
        }

        Write-Host "[2/3] 保留人格文件..." -ForegroundColor Cyan
        Write-Host "  [KEEP] $PromptFile 保留" -ForegroundColor Green

        Write-Host "[3/3] 重启 ZCode..." -ForegroundColor Cyan
        Kill-ZCode
        Start-ZCode

        Write-Host ""
        Write-Host "=== 恢复完成 ===" -ForegroundColor Green
        Write-Host "ZCode 已回到原版" -ForegroundColor Green
    }
}