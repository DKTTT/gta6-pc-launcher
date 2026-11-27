# GTA6 存档设置查看/编辑工具（实测：修改会被游戏读取并在退出后保留）
# 用法：
#   .\settings-editor.ps1                         # 列出所有设置（已知名字 + 哈希键）
#   .\settings-editor.ps1 -DataDir "E:\gta6\work\perf-data"
#   .\settings-editor.ps1 -Set subtitles=1        # 改已知设置（自动备份）
#   .\settings-editor.ps1 -SetRaw c89952df=1      # 改未知键（哈希，8 位小写 hex）
# 注意：游戏必须完全关闭（否则会被游戏覆盖）。
param(
    [string]$DataDir = 'E:\gta6\work\perf-data',
    [string[]]$Set = @(),
    [string[]]$SetRaw = @()
)
$ErrorActionPreference = 'Stop'

# joaat（RAGE 字符串哈希）与 FNV1a64（文件名哈希）只用于对照说明
$KnownNames = @{
    'b80c6ae8' = 'Audio 音频组'; '25584db6' = 'Camera 相机组'; '23683a0d' = 'Controls 控制组'
    '17d82a47' = 'Display 显示组'; '6b34fe60' = 'Profile/其他组（含语言）'
    '944fa9d9' = 'HUD 界面'; 'c89952df' = 'Subtitles 字幕'; 'cb20b040' = 'Accessibility 辅助'
    '6a510681' = 'FOV 视野'; '9c7d4584' = 'VehicleFOV 载具视野'; '4b62d3b2' = 'Language 语言'
    '1141d443' = '版本/格式字段'; '112b5803' = '类型标记'
}

function Find-SettingsFile([string]$root) {
    if (-not (Test-Path $root)) { throw "存档目录不存在: $root" }
    $f = Get-ChildItem $root -Recurse -File -EA SilentlyContinue |
        Where-Object { $_.DirectoryName -match 'SettingsProfileSettings~' -and $_.Name -eq '0' } |
        Select-Object -First 1
    if (-not $f) { throw "没找到 SettingsProfileSettings（这个存档还没有设置数据）" }
    return $f.FullName
}

function Read-Json([string]$path) {
    $b = [System.IO.File]::ReadAllBytes($path)
    $s = [System.Text.Encoding]::ASCII.GetString($b)
    $fb = $s.IndexOf('{'); $lb = $s.LastIndexOf('}')
    if ($fb -lt 0) { throw "设置文件不是 ASAV+JSON 结构" }
    return @{ Head = $s.Substring(0, $fb); Json = $s.Substring($fb, $lb - $fb + 1); Tail = $s.Substring($lb + 1) }
}

function Save-Json([string]$path, $parts, [string]$json) {
    $bytes = [System.Text.Encoding]::ASCII.GetBytes($parts.Head + $json + $parts.Tail)
    [System.IO.File]::WriteAllBytes($path, $bytes)
}

$file = Find-SettingsFile $DataDir
"设置文件: $file"
$parts = Read-Json $file
$obj = $parts.Json | ConvertFrom-Json

# 收集叶子
$leaf = @{}
function Walk($node, [string]$path) {
    if ($null -eq $node) { return }
    if ($node -is [System.Management.Automation.PSCustomObject]) {
        foreach ($p in $node.PSObject.Properties) { Walk $p.Value ($path + '/' + $p.Name) }
    } elseif ($node -is [System.Collections.IEnumerable] -and $node -isnot [string]) {
        $i = 0; foreach ($v in $node) { Walk $v ("$path[$i]"); $i++ }
    } else { $script:leaf[$path] = $node }
}
Walk $obj ''

if ($Set.Count -eq 0 -and $SetRaw.Count -eq 0) {
    "`n=== 已知名字的设置 ==="
    foreach ($p in ($leaf.Keys | Sort-Object)) {
        $ms = [regex]::Matches($p, '\$0x([0-9a-f]{8})')
        if ($ms.Count -eq 0) { continue }
        $last = $ms[$ms.Count - 1].Groups[1].Value
        $name = $KnownNames[$last]
        if ($name) { "  {0,-16} = {1}   ({2})" -f $name, $leaf[$p], $p }
    }
    "`n=== 全部叶子（$($leaf.Count) 个）==="
    foreach ($p in ($leaf.Keys | Sort-Object)) { "  {0} = {1}" -f $p, $leaf[$p] }
    exit 0
}

# 备份
$backup = "$file.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
Copy-Item $file $backup -Force
"已备份: $backup"

$json = $parts.Json
$changed = 0
foreach ($item in $Set) {
    if ($item -notmatch '^\s*([A-Za-z]+)\s*=\s*(.+?)\s*$') { "跳过（格式应为 name=value）: $item"; continue }
    $name = $matches[1].ToLower(); $val = $matches[2]
    $h = ''
    foreach ($k in $KnownNames.Keys) { if ($KnownNames[$k].ToLower().StartsWith($name)) { $h = $k; break } }
    if (-not $h) { "找不到设置名: $name（用 -SetRaw 哈希=值）"; continue }
    $json = [regex]::Replace($json, ('("' + [regex]::Escape('$0x' + $h) + '":\s*)[^,}\r\n]+'), ('${1}' + $val))
    $changed++
    "设置 $name (0x$h) = $val"
}
foreach ($item in $SetRaw) {
    if ($item -notmatch '^\s*([0-9a-fA-F]{8})\s*=\s*(.+?)\s*$') { "跳过（格式应为 8位hex=value）: $item"; continue }
    $h = $matches[1].ToLower(); $val = $matches[2]
    $json = [regex]::Replace($json, ('("' + [regex]::Escape('$0x' + $h) + '":\s*)[^,}\r\n]+'), ('${1}' + $val))
    $changed++
    "设置 0x$h = $val"
}
Save-Json $file $parts $json
"完成：改了 $changed 项。若游戏正在运行请关闭后再改，否则可能被游戏覆盖。"