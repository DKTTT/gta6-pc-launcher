# GTA6 自动进游戏（回车/A）— 只在游戏窗口上按键，绝不瞎按
# 1) 游戏窗口是前台 → SendInput（真实按键）
# 2) 不是前台 → 只对游戏窗口 PostMessage（定向发送，绝不发到别的窗口）
param(
    [string]$ProcessName = 'victory',
    [int]$TimeoutMinutes = 15,
    [int]$PressEverySeconds = 6
)
Add-Type -TypeDefinition @'
using System;using System.Runtime.InteropServices;
public class AutoKey {
    [StructLayout(LayoutKind.Sequential)] public struct KI { public ushort wVk; public ushort wScan; public uint dwFlags; public uint time; public IntPtr dwExtraInfo; }
    [StructLayout(LayoutKind.Sequential)] public struct IN { public uint type; public KI ki; }
    [DllImport("user32.dll")] public static extern uint SendInput(uint n, IN[] p, int s);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
    [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint msg, IntPtr w, IntPtr l);
    public const uint WM_KEYDOWN = 0x0100, WM_KEYUP = 0x0101;
    public const int SW_RESTORE = 9;
    public static bool IsForeground(IntPtr h) { return h != IntPtr.Zero && GetForegroundWindow() == h; }
    public static void Key(ushort vk) {
        IN[] a = new IN[2];
        a[0].type = 1; a[0].ki.wVk = vk;
        a[1].type = 1; a[1].ki.wVk = vk; a[1].ki.dwFlags = 2;
        SendInput(2, a, Marshal.SizeOf(typeof(IN)));
    }
    public static void KeyToWindow(IntPtr h, ushort vk) {
        PostMessage(h, WM_KEYDOWN, (IntPtr)vk, IntPtr.Zero);
        System.Threading.Thread.Sleep(60);
        PostMessage(h, WM_KEYUP, (IntPtr)vk, IntPtr.Zero);
    }
}
'@ -EA SilentlyContinue

$logDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$log = Join-Path $logDir 'auto-enter.log'
function Log([string]$m) { try { Add-Content -Path $log -Value ("{0:HH:mm:ss} {1}" -f (Get-Date), $m) -Encoding UTF8 } catch { } }
Log "=== 自动进游戏启动（进程 $ProcessName，每 ${PressEverySeconds}s，最长 ${TimeoutMinutes} 分钟）==="

$deadline = (Get-Date).AddMinutes($TimeoutMinutes)
$lastPress = Get-Date
$lastState = ''
$misses = 0
while ((Get-Date) -lt $deadline) {
    Start-Sleep -Seconds 1
    $p = Get-Process -Name $ProcessName -EA SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
    if (-not $p) {
        $misses++
        if ($misses -gt 120) { Log '2 分钟内没等到游戏窗口，退出'; break }
        continue
    }
    $misses = 0
    $title = ''
    try { $title = $p.MainWindowTitle } catch { }
    $draws = 0
    if ($title -match '(\d+)\s+draws/frame') { $draws = [int]$matches[1] }
    $state = if ($draws -ge 1500) { 'world' } elseif ($draws -gt 0) { 'loading' } else { 'starting' }
    if ($state -ne $lastState) { Log ("窗口: '{0}' 状态: {1} draws={2}" -f $title, $state, $draws); $lastState = $state }
    if ($state -eq 'world') { Log '已进入世界，停止按键'; break }
    if (((Get-Date) - $lastPress).TotalSeconds -lt $PressEverySeconds) { continue }

    $hwnd = $p.MainWindowHandle
    $fg = [AutoKey]::IsForeground($hwnd)
    if (-not $fg) {
        # 尝试切到前台；失败则只定向发消息给游戏窗口
        [void][AutoKey]::ShowWindow($hwnd, [AutoKey]::SW_RESTORE)
        [void][AutoKey]::SetForegroundWindow($hwnd)
        Start-Sleep -Milliseconds 400
        $fg = [AutoKey]::IsForeground($hwnd)
    }
    if ($fg) {
        [AutoKey]::Key(0x0D); Start-Sleep -Milliseconds 250; [AutoKey]::Key(0x41)
        Log ("前台按键 Enter+A（状态 {0}，draws {1}）" -f $state, $draws)
    } else {
        [AutoKey]::KeyToWindow($hwnd, 0x0D); [AutoKey]::KeyToWindow($hwnd, 0x41)
        Log ("定向发送 Enter+A 到游戏窗口（非前台，状态 {0}，draws {1}）" -f $state, $draws)
    }
    $lastPress = Get-Date
}
Log '=== 自动进游戏结束 ==='