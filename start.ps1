# Star Resonance Damage Counter - Setup & Start Script
# UTF-8 encoding

param(
    [Parameter(Position=0)]
    [string]$DeviceNumber = "", # 网络设备号
    [Parameter(Position=1)]
    [string]$LogLevel = "",     # 日志级别 (info|debug)
    [switch]$Install,           # 安装模式
    [switch]$Start,             # 启动模式 (默认)
    [switch]$Force,             # 强制重新安装
    [switch]$DebugMode,         # 调试模式
    [switch]$Help,              # 帮助信息
    [switch]$SkipCheck,         # 跳过环境检查，直接启动
    [string]$Proxy = "",        # 代理地址 (空字符串表示自动检测)
    [switch]$NoProxy,           # 不使用代理
    [switch]$Overlay            # 同时启动 Buff 悬浮窗
)

# Set encoding to UTF-8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# ===== 系统代理检测函数 =====
function Get-SystemProxySettings {
    try {
        # 从注册表获取系统代理设置
        $proxyRegPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
        $proxyEnabled = Get-ItemProperty -Path $proxyRegPath -Name "ProxyEnable" -ErrorAction SilentlyContinue
        $proxyServer = Get-ItemProperty -Path $proxyRegPath -Name "ProxyServer" -ErrorAction SilentlyContinue
        
        if ($proxyEnabled -and $proxyEnabled.ProxyEnable -eq 1 -and $proxyServer -and $proxyServer.ProxyServer) {
            $proxy = $proxyServer.ProxyServer
            
            # 处理不同格式的代理设置
            if ($proxy -match "^([^:]+):(\d+)$") {
                # 格式: host:port
                return $proxy
            } elseif ($proxy -match "http=([^;]+)") {
                # 格式: http=host:port;https=host:port
                return $matches[1]
            } elseif ($proxy -match "([^=;]+):(\d+)") {
                # 其他格式，提取第一个 host:port
                return $matches[0]
            } else {
                return $null
            }
        } else {
            return $null
        }
    } catch {
        return $null
    }
}

# ===== 配置文件管理函数 =====
function Get-AppConfig {
    $configPath = Join-Path $PSScriptRoot "app-config.json"
    if (Test-Path $configPath) {
        try {
            $configContent = Get-Content $configPath -Raw | ConvertFrom-Json
            return $configContent
        } catch {
            Write-Warning "配置文件读取失败，使用默认配置"
            return @{
                deviceNumber = $null
                logLevel = "info"
                lastUpdated = $null
            }
        }
    } else {
        # 创建默认配置文件
        $defaultConfig = @{
            deviceNumber = $null
            logLevel = "info"
            lastUpdated = $null
        }
        Save-AppConfig $defaultConfig
        return $defaultConfig
    }
}

function Save-AppConfig {
    param($Config)
    $configPath = Join-Path $PSScriptRoot "app-config.json"
    try {
        $Config.lastUpdated = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $Config | ConvertTo-Json -Depth 10 | Set-Content $configPath -Encoding UTF8
        Write-Debug "配置已保存到: $configPath"
    } catch {
        Write-Warning "配置文件保存失败: $_"
    }
}

function Update-AppConfig {
    param(
        [string]$DeviceNumber,
        [string]$LogLevel
    )
    $config = Get-AppConfig
    
    if (![string]::IsNullOrEmpty($DeviceNumber)) {
        $config.deviceNumber = $DeviceNumber
        Write-Debug "更新设备号: $DeviceNumber"
    }
    
    if (![string]::IsNullOrEmpty($LogLevel)) {
        $config.logLevel = $LogLevel
        Write-Debug "更新日志级别: $LogLevel"
    }
    
    Save-AppConfig $config
    return $config
}

# 自动检测系统代理设置
if (-not $NoProxy -and [string]::IsNullOrEmpty($Proxy)) {
    $systemProxy = Get-SystemProxySettings
    if ($systemProxy) {
        $Proxy = $systemProxy
    } else {
        $Proxy = "127.0.0.1:7890"  # 默认值
    }
}

if ($Help) {
    Write-Host @"
Star Resonance Damage Counter - Setup & Start Script

Usage: .\start.ps1 [DeviceNumber] [LogLevel] [Options]

Parameters:
  DeviceNumber 网络设备编号 (0-N，可选)
  LogLevel     日志级别 (info|debug，可选)

Modes:
  -Install     安装模式：安装所有依赖和环境
  -Start       启动模式：启动应用 (默认模式)
  
  如果不指定模式，脚本会自动判断：
  - 如果缺少依赖，自动进入安装模式
  - 如果依赖齐全，直接启动应用

Options:
  -Force       强制重新安装所有依赖
  -DebugMode   显示详细调试信息
  -SkipCheck   跳过环境检查，直接启动
  -Overlay     同时启动 Buff 悬浮窗 (需要 .NET 8 SDK 或已编译的 exe)
  -Proxy       代理地址 (默认: 自动检测系统代理，若无则为 127.0.0.1:7890)
  -NoProxy     不使用代理
  -Help        显示此帮助信息

Config Persistence:
  设备号和日志级别会自动保存到 app-config.json，下次启动时自动使用

Examples:
  .\start.ps1                    # 自动模式 (使用保存的配置)
  .\start.ps1 2 debug            # 使用设备2，调试日志级别
  .\start.ps1 -DeviceNumber 1    # 仅指定设备号
  .\start.ps1 -LogLevel info     # 仅指定日志级别
  .\start.ps1 -Install           # 强制安装模式
  .\start.ps1 -Start             # 强制启动模式
  .\start.ps1 -Install -Force    # 强制重新安装
  .\start.ps1 -DebugMode         # 调试模式
  .\start.ps1 -NoProxy           # 不使用代理安装
  .\start.ps1 -Proxy "127.0.0.1:1080"  # 手动指定代理地址
  .\start.ps1 -Start -SkipCheck  # 跳过检查快速启动
  .\start.ps1 -Overlay           # 同时启动 Buff 悬浮窗
  .\start.ps1 -Start -Overlay    # 强制启动模式 + 悬浮窗
"@ -ForegroundColor Cyan
    exit 0
}

# ===== 通用函数 =====
function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Write-Debug {
    param([string]$Message)
    if ($DebugMode) {
        Write-Host "[DEBUG] $Message" -ForegroundColor Cyan
    }
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Magenta
}

function Clear-ProgressLine {
    # 清理残留的进度信息行
    Write-Host "`r" -NoNewline
    Write-Host (" " * 120) -NoNewline  # 用空格覆盖整行
    Write-Host "`r" -NoNewline
}

function Show-Progress {
    param([string]$Activity, [int]$SecondsToWait = 3)
    Write-Host "$Activity" -NoNewline -ForegroundColor Yellow
    for ($i = 0; $i -lt $SecondsToWait; $i++) {
        Write-Host "." -NoNewline -ForegroundColor Yellow
        Start-Sleep -Seconds 1
    }
    Write-Host " 继续" -ForegroundColor Green
}

# ===== 环境检测函数 =====
function Test-NodeJS {
    Write-Debug "检查 Node.js..."
    try {
        $nodeVersion = & node --version 2>$null
        if ($nodeVersion) {
            Write-Debug "Node.js 版本: $nodeVersion"
            $versionNumber = [version]($nodeVersion -replace 'v', '')
            if ($versionNumber.Major -ge 18) {
                return $true
            } else {
                Write-Warning "Node.js 版本过低 ($nodeVersion)，建议升级到 >= 18.0.0"
                return $false
            }
        }
    } catch {
        return $false
    }
    return $false
}

function Test-PackageManager {
    Write-Debug "检查包管理器..."
    try {
        $pnpmVersion = & pnpm --version 2>$null
        if ($pnpmVersion) {
            Write-Debug "找到 pnpm 版本: $pnpmVersion"
            return "pnpm"
        }
    } catch { }
    
    try {
        $npmVersion = & npm --version 2>$null
        if ($npmVersion) {
            Write-Debug "找到 npm 版本: $npmVersion"
            return "npm"
        }
    } catch { }
    
    return $null
}

function Find-VisualStudio {
    Write-Debug "查找 Visual Studio..."
    
    # 检查保存的配置
    $configFile = "vs-config.json"
    if (Test-Path $configFile) {
        try {
            $config = Get-Content $configFile | ConvertFrom-Json
            if ($config.VSPath -and (Test-Path (Join-Path $config.VSPath "VC\Auxiliary\Build\vcvars64.bat"))) {
                Write-Debug "使用保存的 Visual Studio 路径: $($config.VSPath)"
                return Join-Path $config.VSPath "VC\Auxiliary\Build\vcvars64.bat"
            }
        } catch {
            Write-Debug "读取配置文件失败"
        }
    }
    
    # 使用 vswhere.exe 查找
    $possiblePaths = @(
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe",
        "${env:ProgramFiles}\Microsoft Visual Studio\Installer\vswhere.exe"
    )
    
    foreach ($path in $possiblePaths) {
        if (Test-Path $path) {
            try {
                $vsInstances = & $path -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath 2>$null
                if ($vsInstances) {
                    foreach ($vsPath in $vsInstances) {
                        $vcvarsPath = Join-Path $vsPath "VC\Auxiliary\Build\vcvars64.bat"
                        if (Test-Path $vcvarsPath) {
                            Write-Debug "找到 Visual Studio: $vsPath"
                            # 保存配置
                            try {
                                $configData = @{ VSPath = $vsPath; LastFound = (Get-Date).ToString() }
                                $configData | ConvertTo-Json | Set-Content $configFile -ErrorAction SilentlyContinue
                            } catch {}
                            return $vcvarsPath
                        }
                    }
                }
            } catch {
                Write-Debug "vswhere.exe 查找失败"
            }
            break
        }
    }
    
    return $null
}

function Find-NetworkDriver {
    Write-Debug "查找网络抓包驱动..."
    
    # 检查 Npcap
    $npcapPath = "C:\Windows\System32\Npcap\wpcap.dll"
    if (Test-Path $npcapPath) {
        Write-Debug "找到 Npcap 驱动"
        return "C:\Windows\System32\Npcap"
    }
    
    # 检查 WinPcap
    $winpcapPath = "C:\Windows\System32\wpcap.dll"
    if (Test-Path $winpcapPath) {
        Write-Debug "找到 WinPcap 驱动"
        return "C:\Windows\System32"
    }
    
    Write-Debug "未找到网络驱动，使用默认路径"
    return "C:\Windows\System32"
}

function Find-ElectronPaths {
    Write-Debug "查找 Electron 安装路径..."
    
    # 可能的 Electron 路径模式
    $possiblePaths = @(
        # pnpm 模式
        "node_modules\.pnpm\electron@*\node_modules\electron",
        # npm 模式  
        "node_modules\electron",
        # 其他可能的路径
        "node_modules\.bin\..\electron"
    )
    
    $result = @{
        InstallScript = $null
        Executable = $null
        Found = $false
    }
    
    foreach ($pathPattern in $possiblePaths) {
        Write-Debug "检查路径模式: $pathPattern"
        
        # 使用 Get-ChildItem 查找匹配的路径
        try {
            $matchedPaths = Get-ChildItem -Path $pathPattern -ErrorAction SilentlyContinue
            foreach ($electronDir in $matchedPaths) {
                if ($electronDir.PSIsContainer) {
                    $installScript = Join-Path $electronDir.FullName "install.js"
                    $executable = Join-Path $electronDir.FullName "dist\electron.exe"
                    
                    Write-Debug "检查: $($electronDir.FullName)"
                    Write-Debug "  安装脚本: $installScript (存在: $(Test-Path $installScript))"
                    Write-Debug "  可执行文件: $executable (存在: $(Test-Path $executable))"
                    
                    if (Test-Path $installScript) {
                        $result.InstallScript = $installScript
                        $result.Found = $true
                        Write-Debug "找到 Electron 安装脚本: $installScript"
                    }
                    
                    if (Test-Path $executable) {
                        $result.Executable = $executable
                        Write-Debug "找到 Electron 可执行文件: $executable"
                    }
                    
                    # 如果找到了，就使用第一个匹配的
                    if ($result.InstallScript) {
                        break
                    }
                }
            }
        } catch {
            Write-Debug "路径模式 $pathPattern 查找失败: $_"
        }
        
        if ($result.Found) {
            break
        }
    }
    
    if ($result.Found) {
        Write-Debug "Electron 路径查找结果:"
        Write-Debug "  安装脚本: $($result.InstallScript)"
        Write-Debug "  可执行文件: $($result.Executable)"
    } else {
        Write-Debug "未找到 Electron 安装路径"
    }
    
    return $result
}

function Test-DotNetSDK {
    Write-Debug "检查 .NET SDK..."
    try {
        $dotnetVersion = & dotnet --version 2>$null
        if ($dotnetVersion) {
            Write-Debug ".NET SDK 版本: $dotnetVersion"
            $major = [int]($dotnetVersion -split '\.')[0]
            return $major -ge 8
        }
    } catch { }
    return $false
}

function Get-OverlayExePath {
    $overlayDir = Join-Path $PSScriptRoot "overlay\BuffOverlay"
    # 优先查找已发布的 exe
    $publishExe = Join-Path $overlayDir "bin\Release\net8.0-windows\win-x64\publish\BuffOverlay.exe"
    if (Test-Path $publishExe) {
        Write-Debug "找到已发布的 overlay: $publishExe"
        return $publishExe
    }
    # 其次查找 Debug build
    $debugExe = Join-Path $overlayDir "bin\Debug\net8.0-windows\BuffOverlay.exe"
    if (Test-Path $debugExe) {
        Write-Debug "找到 Debug overlay: $debugExe"
        return $debugExe
    }
    return $null
}

function Build-Overlay {
    $overlayDir = Join-Path $PSScriptRoot "overlay\BuffOverlay"
    if (-not (Test-Path (Join-Path $overlayDir "BuffOverlay.csproj"))) {
        Write-Warning "overlay 项目不存在: $overlayDir"
        return $false
    }

    if (-not (Test-DotNetSDK)) {
        Write-Warning "未找到 .NET 8 SDK，无法编译 Buff 悬浮窗"
        Write-Host "请安装 .NET 8 SDK: https://dotnet.microsoft.com/download/dotnet/8.0" -ForegroundColor Yellow
        return $false
    }

    # 如果已经有编译好的 exe，跳过
    $existingExe = Get-OverlayExePath
    if ($existingExe) {
        Write-Debug "overlay 已编译，跳过"
        return $true
    }

    Write-Info "编译 Buff 悬浮窗..."
    try {
        & dotnet publish $overlayDir -c Release -r win-x64 --self-contained -v quiet 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Buff 悬浮窗编译成功"
            return $true
        } else {
            Write-Warning "Buff 悬浮窗编译失败 (退出代码: $LASTEXITCODE)"
            return $false
        }
    } catch {
        Write-Warning "Buff 悬浮窗编译异常: $_"
        return $false
    }
}

function Start-Overlay {
    param([int]$Port = 8989)

    $exePath = Get-OverlayExePath
    if ($exePath) {
        Write-Info "启动 Buff 悬浮窗 (端口: $Port)..."
        Start-Process -FilePath $exePath -ArgumentList "$Port" -WindowStyle Hidden
        return $true
    }

    # 没有 exe，尝试 dotnet run
    $overlayDir = Join-Path $PSScriptRoot "overlay\BuffOverlay"
    if ((Test-DotNetSDK) -and (Test-Path (Join-Path $overlayDir "BuffOverlay.csproj"))) {
        Write-Info "通过 dotnet run 启动 Buff 悬浮窗 (端口: $Port)..."
        Start-Process -FilePath "dotnet" -ArgumentList "run --project `"$overlayDir`" -- $Port" -WindowStyle Hidden
        return $true
    }

    Write-Warning "无法启动 Buff 悬浮窗：未找到可执行文件且无 .NET SDK"
    return $false
}

function Test-ElectronRequired {
    Write-Debug "检查项目是否需要 Electron..."
    
    if (-not (Test-Path "package.json")) {
        Write-Debug "package.json 不存在，假设不需要 Electron"
        return $false
    }
    
    try {
        $packageJson = Get-Content "package.json" -Raw | ConvertFrom-Json
        
        # 检查 dependencies 和 devDependencies 中是否有 electron
        $hasElectron = $false
        
        if ($packageJson.dependencies -and $packageJson.dependencies.electron) {
            $hasElectron = $true
            Write-Debug "在 dependencies 中找到 electron: $($packageJson.dependencies.electron)"
        }
        
        if ($packageJson.devDependencies -and $packageJson.devDependencies.electron) {
            $hasElectron = $true
            Write-Debug "在 devDependencies 中找到 electron: $($packageJson.devDependencies.electron)"
        }
        
        # 检查 scripts 中是否使用了 electron
        if ($packageJson.scripts -and $packageJson.scripts.start -and $packageJson.scripts.start -match "electron") {
            Write-Debug "启动脚本使用 electron: $($packageJson.scripts.start)"
        }
        
        Write-Debug "项目$(if ($hasElectron) { '需要' } else { '不需要' }) Electron"
        return $hasElectron
        
    } catch {
        Write-Debug "解析 package.json 失败: $_"
        return $false
    }
}

function Test-InstallationComplete {
    Write-Debug "检查安装完整性..."
    
    # 检查基本文件
    $requiredFiles = @("package.json", "server.js", "node_modules")
    foreach ($file in $requiredFiles) {
        if (-not (Test-Path $file)) {
            Write-Debug "缺少文件: $file"
            return $false
        }
    }
    
    # 检查 cap 模块（这是关键组件）
    $capModulePath = "node_modules\.pnpm\cap@*\node_modules\cap\build\Release\cap.node"
    $capBuilt = $false
    
    try {
        $capBinaryPaths = Get-ChildItem -Path $capModulePath -ErrorAction SilentlyContinue
        if ($capBinaryPaths) {
            foreach ($capBinary in $capBinaryPaths) {
                if (Test-Path $capBinary.FullName) {
                    Write-Debug "找到 cap 二进制文件: $($capBinary.FullName)"
                    $capBuilt = $true
                    break
                }
            }
        }
        
        # 如果没有找到编译好的二进制文件，再尝试运行时测试
        if (-not $capBuilt) {
            Write-Debug "未找到 cap 二进制文件，进行运行时测试"
            $driverPath = Find-NetworkDriver
            $originalPath = $env:PATH
            try {
                $env:PATH = $env:PATH + ";$driverPath"
                $result = & node -e "try { require('cap'); console.log('OK'); } catch(e) { console.log('FAILED'); process.exit(1); }" 2>$null
                $capBuilt = ($LASTEXITCODE -eq 0 -and $result -eq "OK")
            } finally {
                $env:PATH = $originalPath
            }
        }
        
        Write-Debug "cap 模块状态: $(if ($capBuilt) { '已编译' } else { '需要编译' })"
    } catch {
        Write-Debug "cap 模块检查异常: $_"
        $capBuilt = $false
    }
    
    # cap 模块是必须的，如果不工作就需要安装
    if (-not $capBuilt) {
        Write-Debug "cap 模块不可用，需要重新编译"
        return $false
    }
    
    # 只有当项目需要 Electron 时才检查 Electron 安装
    $electronRequired = Test-ElectronRequired
    if ($electronRequired) {
        $electronPaths = Find-ElectronPaths
        $electronWorking = $electronPaths.Found -and $electronPaths.Executable -and (Test-Path $electronPaths.Executable)
        Write-Debug "Electron 状态: $(if ($electronWorking) { '可用' } else { '缺失，需要安装' })"
        
        if (-not $electronWorking) {
            Write-Debug "项目需要 Electron 但未安装，需要重新安装"
            return $false
        }
    } else {
        Write-Debug "项目不需要 Electron，跳过 Electron 检查"
    }
    
    return $true
}

# ===== 安装相关函数 =====
function Set-ProxyEnvironment {
    if (-not $NoProxy) {
        Write-Info "设置代理环境变量: $Proxy"
        
        # 检查代理地址是否已包含协议头
        $proxyUrl = if ($Proxy -match "^https?://") { 
            $Proxy 
        } else { 
            "http://$Proxy" 
        }
        
        # 设置通用代理环境变量
        $env:HTTP_PROXY = $proxyUrl
        $env:HTTPS_PROXY = $proxyUrl
        $env:http_proxy = $proxyUrl  # 小写版本，某些工具需要
        $env:https_proxy = $proxyUrl
        
        # Electron 专用代理设置
        $env:ELECTRON_GET_USE_PROXY = "true"
        $env:ELECTRON_CUSTOM_DIR = $env:TEMP  # 使用临时目录避免权限问题
        
        Write-Debug "代理设置完成: $proxyUrl"
    } else {
        Write-Info "跳过代理设置"
    }
    
    # 设置 Electron 镜像源 (国内用户友好)
    # 尝试多个镜像源，提高下载成功率
    $electronMirrors = @(
        "https://cdn.npm.taobao.org/dist/electron/",
        "https://registry.npmmirror.com/electron/",
        "https://mirrors.cloud.tencent.com/electron/"
    )
    
    # 随机选择一个镜像源，避免单点故障
    $selectedMirror = $electronMirrors | Get-Random
    $env:ELECTRON_MIRROR = $selectedMirror
    $env:ELECTRON_CUSTOM_DIST_URL = $selectedMirror
    
    Write-Debug "设置 Electron 镜像源: $selectedMirror"
}

function Set-ElectronDownloadEnvironment {
    Write-Debug "配置 Electron 下载环境..."
    
    # 设置持久化缓存目录，避免每次重新下载
    $electronCacheDir = Join-Path $env:LOCALAPPDATA "electron-cache"
    if (-not (Test-Path $electronCacheDir)) {
        New-Item -Path $electronCacheDir -ItemType Directory -Force | Out-Null
        Write-Debug "创建 Electron 缓存目录: $electronCacheDir"
    }
    $env:ELECTRON_CACHE = $electronCacheDir
    
    # 清理可能冲突的环境变量
    Remove-Item Env:\ELECTRON_MIRROR -ErrorAction SilentlyContinue
    Remove-Item Env:\ELECTRON_CUSTOM_DIR -ErrorAction SilentlyContinue  
    Remove-Item Env:\ELECTRON_CUSTOM_DIST_URL -ErrorAction SilentlyContinue
    Remove-Item Env:\ELECTRON_DOWNLOAD_MIRROR -ErrorAction SilentlyContinue
    
    # 设置超时时间
    $env:ELECTRON_DOWNLOAD_TIMEOUT = "300000"  # 5分钟
    
    # 禁用进度条，减少输出干扰
    $env:ELECTRON_DOWNLOAD_NO_PROGRESS = "1"
    
    # 启用缓存复用
    $env:ELECTRON_ENABLE_CACHE = "1"
    
    Write-Debug "缓存目录: $electronCacheDir"
    Write-Debug "将使用默认官方源下载 Electron，并启用持久化缓存"
}

function Install-Dependencies {
    param([string]$PackageManager)
    
    Write-Info "安装项目依赖..."
    Write-Host "正在安装项目依赖包..." -ForegroundColor Yellow
    
    try {
        Write-Host "┌─ 依赖安装过程 ─┐" -ForegroundColor Cyan
        Write-Host "│ 运行: $PackageManager install │" -ForegroundColor Cyan
        
        # 清理可能残留的进度信息
        Clear-ProgressLine
        
        & $PackageManager install
        $exitCode = $LASTEXITCODE
        
        # 安装完成后清理输出
        Clear-ProgressLine
        Write-Host "└─────────────────┘" -ForegroundColor Cyan
        
        if ($exitCode -ne 0) {
            Write-Error "基础依赖安装失败 (退出代码: $exitCode)"
            return $false
        }
        
        Write-Success "基础依赖安装成功"
        return $true
    } catch {
        Write-Error "依赖安装失败: $_"
        return $false
    }
}

function Install-CapModule {
    param([string]$PackageManager, [string]$VcvarsPath, [string]$DriverPath)
    
    Write-Info "编译 cap 模块..."
    Write-Host "正在使用 Visual Studio 环境编译原生模块..." -ForegroundColor Yellow
    Write-Host "这可能需要几分钟时间，请耐心等待..." -ForegroundColor Yellow
    
    try {
        $env:PATH = $env:PATH + ";$DriverPath"
        
        $originalOutputEncoding = [Console]::OutputEncoding
        
        Write-Host "┌─ 编译 cap 模块 ─┐" -ForegroundColor Cyan
        Write-Host "│ 初始化编译环境...│" -ForegroundColor Cyan
        
        # 创建临时批处理文件
        $tempBat = [System.IO.Path]::GetTempFileName() + ".bat"
        $batContent = @"
@echo off
chcp 65001 >nul 2>&1
echo [编译] 正在初始化 Visual Studio 环境...
call "$VcvarsPath"
if errorlevel 1 (
    echo [错误] Visual Studio 环境初始化失败
    exit /b 1
)
echo [编译] VS 环境初始化完成
echo [编译] 开始编译 cap 模块...
cd /d "$PWD"
$PackageManager rebuild cap
echo [编译] 编译过程完成，退出代码: %errorlevel%
"@
        
        $batContent | Out-File -FilePath $tempBat -Encoding ASCII
        Write-Debug "使用临时批处理: $tempBat"
        
        Write-Host "│ 执行编译命令... │" -ForegroundColor Cyan
        
        # 直接执行批处理文件，捕获输出
        $result = & cmd /c "`"$tempBat`"" 2>&1
        $compileExitCode = $LASTEXITCODE
        
        # 清理临时文件
        Remove-Item $tempBat -ErrorAction SilentlyContinue
        
        # 清理可能残留的进度信息
        Clear-ProgressLine
        Write-Host "└──────────────────┘" -ForegroundColor Cyan
        
        # 恢复控制台设置
        [Console]::OutputEncoding = $originalOutputEncoding
        
        # 显示编译结果
        if ($DebugMode) {
            Write-Debug "编译详细输出:"
            $result | ForEach-Object { Write-Debug "  $_" }
        } else {
            # 显示关键信息
            $result | Where-Object { 
                $_ -match "编译|错误|成功|完成|compile|error|success|completed|gyp|node-gyp" 
            } | ForEach-Object { 
                Write-Host "  $_" -ForegroundColor DarkGray 
            }
        }
        
        if ($compileExitCode -eq 0) {
            Write-Success "cap 模块编译成功"
            return $true
        } else {
            Write-Error "cap 模块编译失败 (退出代码: $compileExitCode)"
            return $false
        }
        
    } catch {
        Write-Error "cap 模块编译异常: $_"
        return $false
    }
}

function Install-Electron {
    Write-Info "安装 Electron..."
    
    # 先检查 Electron 是否已经正确安装
    $electronPaths = Find-ElectronPaths
    if ($electronPaths.Found -and $electronPaths.Executable -and (Test-Path $electronPaths.Executable)) {
        Write-Success "Electron 已正确安装，跳过重新安装"
        return $true
    }
    
    Write-Host "正在安装 Electron..." -ForegroundColor Yellow
    
    try {
        # 先配置环境
        Set-ElectronDownloadEnvironment
        
        Write-Host "┌─ Electron 安装过程 ─┐" -ForegroundColor Cyan
        Write-Host "│ 运行: pnpm install electron │" -ForegroundColor Cyan
        
        # 清理可能残留的进度信息
        Clear-ProgressLine
        
        # 尝试使用 pnpm 安装 electron (不使用 --force，让它利用缓存)
        pnpm install electron
        $exitCode = $LASTEXITCODE
        
        if ($exitCode -eq 0) {
            Write-Host "│ ✓ Electron 安装完成" -ForegroundColor Green
            Write-Host "└─────────────────────┘" -ForegroundColor Cyan
            
            # 验证安装结果
            $electronPaths = Find-ElectronPaths
            if ($electronPaths.Found -and $electronPaths.Executable -and (Test-Path $electronPaths.Executable)) {
                Write-Success "Electron 安装成功并验证通过！"
                return $true
            } else {
                Write-Warning "Electron 安装完成但验证失败，可能需要运行安装脚本"
                
                # 尝试运行 Electron 安装脚本来下载二进制文件
                if ($electronPaths.InstallScript -and (Test-Path $electronPaths.InstallScript)) {
                    Write-Host "│ 运行安装脚本下载二进制文件... │" -ForegroundColor Cyan
                    & node $electronPaths.InstallScript
                    $installScriptExit = $LASTEXITCODE
                    
                    if ($installScriptExit -eq 0) {
                        Write-Success "Electron 二进制文件下载成功！"
                        return $true
                    } else {
                        Write-Warning "Electron 二进制文件下载失败，但基础安装已完成"
                        return $false
                    }
                } else {
                    Write-Warning "找不到 Electron 安装脚本"
                    return $false
                }
            }
        } else {
            Write-Host "│ ✗ pnpm 安装失败，尝试使用 npm..." -ForegroundColor Yellow
            Write-Host "│ 运行: npm install electron │" -ForegroundColor Cyan
            
            # 尝试使用 npm
            npm install electron
            $exitCode = $LASTEXITCODE
            
            if ($exitCode -eq 0) {
                Write-Host "│ ✓ Electron 安装完成 (npm)" -ForegroundColor Green
                Write-Host "└─────────────────────┘" -ForegroundColor Cyan
                Write-Success "Electron 安装成功！"
                return $true
            } else {
                throw "npm 安装也失败，退出代码: $exitCode"
            }
        }
        
    } catch {
        Write-Host "│ ✗ Electron 安装失败: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "└─────────────────────┘" -ForegroundColor Cyan
        Write-Error "Electron 安装失败: $($_.Exception.Message)"
        return $false
    }
}

# ===== 主要模式函数 =====
function Invoke-InstallMode {
    Write-Host @"
+=============================================================+
|     Star Resonance Damage Counter - Installation Mode     |
+================== ===========================================+
"@ -ForegroundColor Magenta

    # 1. 检查项目文件
    if (-not (Test-Path "package.json")) {
        Write-Error "package.json 未找到，请在正确的项目目录中运行此脚本"
        exit 1
    }

    # 2. 检查 Node.js
    if (-not (Test-NodeJS)) {
        Write-Error "Node.js 未找到或版本过低"
        Write-Host "请安装 Node.js >= 18.0.0: https://nodejs.org/" -ForegroundColor Yellow
        exit 1
    }

    # 3. 检查包管理器
    $packageManager = Test-PackageManager
    if (-not $packageManager) {
        Write-Error "未找到包管理器 (需要 pnpm 或 npm)"
        Write-Host "请安装 pnpm: npm install -g pnpm" -ForegroundColor Yellow
        exit 1
    }

    # 4. 查找 Visual Studio
    $vcvarsPath = Find-VisualStudio
    if (-not $vcvarsPath) {
        Write-Error "未找到 Visual Studio!"
        Write-Host "请安装 Visual Studio Build Tools 或 Visual Studio Community" -ForegroundColor Yellow
        exit 1
    }

    # 5. 查找网络驱动
    $driverPath = Find-NetworkDriver
    if (-not $driverPath) {
        Write-Warning "未找到网络抓包驱动"
        Write-Warning "请安装 Npcap: https://nmap.org/npcap/"
        $driverPath = "C:\Windows\System32"
    }

    # 6. 设置代理环境
    Set-ProxyEnvironment

    # 7. 强制重新安装检查
    if ($Force -and (Test-Path "node_modules")) {
        Write-Info "强制模式：删除现有 node_modules..."
        Write-Host "正在清理现有安装..." -ForegroundColor Yellow
        
        try {
            # 使用 PowerShell 的 Remove-Item 而不是依赖 pnpm，避免进度输出干扰
            Remove-Item "node_modules" -Recurse -Force -ErrorAction SilentlyContinue
            
            # 清理残留的进度信息
            Clear-ProgressLine
            Write-Success "现有安装已清理完成"
        } catch {
            Clear-ProgressLine
            Write-Warning "清理现有安装时出现警告，但继续安装过程"
        }
    }

    # 8. 安装步骤
    Write-Info "开始安装过程..."
    
    # 步骤 1: 安装依赖
    if (-not (Install-Dependencies -PackageManager $packageManager)) {
        Write-Error "依赖安装失败"
        exit 1
    }
    
    # 步骤 2: 编译 cap 模块
    if (-not (Install-CapModule -PackageManager $packageManager -VcvarsPath $vcvarsPath -DriverPath $driverPath)) {
        Write-Error "cap 模块安装失败"
        exit 1
    }
    
    # 步骤 3: 安装 Electron (仅在项目需要时)
    $electronRequired = Test-ElectronRequired
    $electronInstalled = $false
    
    if ($electronRequired) {
        Write-Info "项目需要 Electron，开始安装..."
        $electronInstalled = Install-Electron
        if (-not $electronInstalled) {
            Write-Warning "Electron 安装失败，但不影响服务器模式运行"
            Write-Host "桌面模式将不可用，应用将以服务器模式启动" -ForegroundColor Yellow
        }
    } else {
        Write-Info "项目不需要 Electron，跳过 Electron 安装"
        $electronInstalled = $true  # 标记为已完成，因为不需要
    }
    
    Write-Success "安装完成!"
    if ($electronRequired -and $electronInstalled) {
        Write-Host "现在你可以运行: .\start.ps1 -Start 来启动桌面应用" -ForegroundColor Green
    } else {
        Write-Host "现在你可以运行: .\start.ps1 -Start 来启动服务器模式" -ForegroundColor Green
        Write-Host "或者稍后修复 Electron 安装以启用桌面模式" -ForegroundColor Yellow
    }
}

function Invoke-StartMode {
    Write-Host @"
+=============================================================+
|       Star Resonance Damage Counter - Start Mode         |
+=============================================================+
"@ -ForegroundColor Magenta

    # 1. 检查项目文件
    if (-not (Test-Path "package.json")) {
        Write-Error "package.json 未找到，请在正确的项目目录中运行此脚本"
        exit 1
    }

    if (-not (Test-Path "server.js")) {
        Write-Error "server.js 未找到，请在正确的项目目录中运行此脚本"
        exit 1
    }

    # 2. 检查 node_modules
    if (-not (Test-Path "node_modules")) {
        Write-Error "node_modules 目录未找到，请先运行安装模式"
        exit 1
    }

    # 保存原始环境变量
    $originalPath = $env:PATH

    try {
        # 3. 查找网络驱动路径
        $driverPath = Find-NetworkDriver
        Write-Debug "驱动路径: $driverPath"
        
        if (-not $SkipCheck) {
            # 4. 快速环境检查和自动修复
            if (-not (Test-InstallationComplete)) {
                Write-Warning "检测到安装不完整，尝试自动修复..."
                
                # 检查具体缺少什么组件
                $missingComponents = @()
                
                # 检查 cap 模块
                $capModulePath = "node_modules\.pnpm\cap@*\node_modules\cap\build\Release\cap.node"
                $capBuilt = $false
                try {
                    $capBinaryPaths = Get-ChildItem -Path $capModulePath -ErrorAction SilentlyContinue
                    $capBuilt = $capBinaryPaths -and ($capBinaryPaths | Test-Path)
                } catch { }
                
                if (-not $capBuilt) {
                    $missingComponents += "cap"
                }
                
                # 检查 Electron
                if (Test-ElectronRequired) {
                    $electronPaths = Find-ElectronPaths
                    $electronWorking = $electronPaths.Found -and $electronPaths.Executable -and (Test-Path $electronPaths.Executable)
                    if (-not $electronWorking) {
                        $missingComponents += "electron"
                    }
                }
                
                # 只修复缺少的组件
                if ($missingComponents -contains "cap") {
                    Write-Info "修复 cap 模块..."
                    $vcvarsPath = Find-VisualStudio
                    if ($vcvarsPath) {
                        Install-CapModule -PackageManager "pnpm" -VcvarsPath $vcvarsPath -DriverPath $driverPath
                    } else {
                        Write-Warning "无法找到 Visual Studio，跳过 cap 模块修复"
                    }
                }
                
                if ($missingComponents -contains "electron") {
                    Write-Info "修复 Electron 安装..."
                    Install-Electron
                }
                
                if ($missingComponents.Count -eq 0) {
                    Write-Info "所有组件检查通过，但安装完整性检查失败，可能是检查逻辑问题"
                }
            } else {
                Write-Success "环境检查通过"
            }
        }
        
        # 5. 设置环境变量并启动
        Write-Info "配置启动环境..."
        $env:PATH = $env:PATH + ";$driverPath"
        Write-Debug "PATH 已添加驱动路径: $driverPath"
        
        # 6. 智能选择启动方式
        Write-Success "环境配置完成，正在启动应用..."
        Write-Host "`n启动 Star Resonance Damage Counter..." -ForegroundColor Cyan
        
        # 构建启动参数
        $serverArgs = @()
        if (![string]::IsNullOrEmpty($DeviceNumber)) {
            $serverArgs += $DeviceNumber
        }
        if (![string]::IsNullOrEmpty($LogLevel)) {
            $serverArgs += $LogLevel
        }
        
        if ($serverArgs.Count -gt 0) {
            Write-Host "使用参数: 设备号=$($serverArgs[0] ?? '交互选择'), 日志级别=$($serverArgs[1] ?? '交互选择')" -ForegroundColor Yellow
        } else {
            Write-Host "程序启动后，请按照提示选择网络设备和日志级别。" -ForegroundColor Yellow
        }
        
        # 启动 Buff 悬浮窗 (如果指定了 -Overlay)
        if ($Overlay) {
            if (Build-Overlay) {
                Start-Overlay -Port 8989
            }
        }

        # 检查项目是否需要 Electron
        $electronRequired = Test-ElectronRequired
        if ($electronRequired) {
            $electronPaths = Find-ElectronPaths
            $electronExe = $electronPaths.Executable
            
            if ($electronExe -and (Test-Path $electronExe)) {
                Write-Debug "使用 Electron 桌面模式启动"
                Write-Info "启动桌面应用模式..."
                & pnpm start
            } else {
                Write-Debug "项目需要 Electron 但未找到，使用服务器模式"
                Write-Warning "Electron 不可用，启动纯服务器模式"
                Write-Info "你可以在浏览器中访问 http://localhost:8989 使用 Web 界面"
                Write-Host "游戏数据统计将显示在: http://localhost:8989`n" -ForegroundColor Yellow
                if ($serverArgs.Count -gt 0) {
                    & node server.js @serverArgs
                } else {
                    & node server.js
                }
            }
        } else {
            Write-Debug "项目不需要 Electron，直接使用服务器模式"
            Write-Info "启动纯服务器模式..."
            Write-Host "游戏数据统计将显示在: http://localhost:8989`n" -ForegroundColor Yellow
            if ($serverArgs.Count -gt 0) {
                & node server.js @serverArgs
            } else {
                & node server.js
            }
        }
        
    } catch {
        Write-Error "程序启动异常: $_"
        exit 1
    } finally {
        # 恢复原始环境变量
        $env:PATH = $originalPath
        Write-Debug "环境变量已恢复"
    }
    
    Write-Info "程序已退出"
}

# ===== 主逻辑 =====
Write-Debug "脚本参数: Install=$Install, Start=$Start, Force=$Force, DeviceNumber='$DeviceNumber', LogLevel='$LogLevel'"
Write-Debug "未命名参数个数: $($args.Count), 参数: $args"

# 加载配置
$appConfig = Get-AppConfig

# 处理设备号和日志级别参数（从命名参数或位置参数）
$configUpdated = $false
if (![string]::IsNullOrEmpty($DeviceNumber)) {
    $appConfig = Update-AppConfig -DeviceNumber $DeviceNumber
    $configUpdated = $true
    Write-Debug "使用设备号: $DeviceNumber"
}
if (![string]::IsNullOrEmpty($LogLevel)) {
    $appConfig = Update-AppConfig -LogLevel $LogLevel
    $configUpdated = $true
    Write-Debug "使用日志级别: $LogLevel"
}

if ($configUpdated) {
    Write-Info "配置已更新并保存"
}

# 如果没有提供参数，使用保存的配置
if ([string]::IsNullOrEmpty($DeviceNumber) -and $appConfig.deviceNumber -ne $null) {
    $DeviceNumber = $appConfig.deviceNumber
    Write-Debug "使用保存的设备号: $DeviceNumber"
}
if ([string]::IsNullOrEmpty($LogLevel) -and ![string]::IsNullOrEmpty($appConfig.logLevel)) {
    $LogLevel = $appConfig.logLevel
    Write-Debug "使用保存的日志级别: $LogLevel"
}

# 显示配置信息
if (![string]::IsNullOrEmpty($DeviceNumber)) {
    Write-Info "网络设备号: $DeviceNumber"
}
if (![string]::IsNullOrEmpty($LogLevel)) {
    Write-Info "日志级别: $LogLevel"
}

# 显示代理配置信息
if ($NoProxy) {
    Write-Debug "代理配置: 已禁用代理"
} else {
    $systemProxy = Get-SystemProxySettings
    if ($systemProxy -and $Proxy -eq $systemProxy) {
        Write-Debug "代理配置: 自动检测到系统代理 $Proxy"
    } elseif ($systemProxy) {
        Write-Debug "代理配置: 手动指定 $Proxy (系统代理: $systemProxy)"
    } else {
        Write-Debug "代理配置: $Proxy (未检测到系统代理，使用默认/手动指定)"
    }
}

# 决定运行模式
if ($Install) {
    $mode = "install"
} elseif ($Start) {
    $mode = "start"  
} else {
    # 自动判断模式
    if ((Test-InstallationComplete) -and -not $Force) {
        $mode = "start"
        Write-Info "检测到完整安装，进入启动模式"
    } else {
        $mode = "install"
        Write-Info "检测到需要安装，进入安装模式"
    }
}

Write-Debug "运行模式: $mode"

# 执行对应模式
switch ($mode) {
    "install" { Invoke-InstallMode }
    "start"   { Invoke-StartMode }
}