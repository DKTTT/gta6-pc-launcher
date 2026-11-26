# GTA VI PC 移植 · 自动启动器 v1.0

**作者**: DKTTT  ·  GitHub: https://github.com/DKTTT
**日期**: 2026-11-26
**基于**: VIctory 社区项目（avatarmanz/VIctory-7900XTX、trustno1-coder/VIctory-NVIDIA、fxceless/victory-fork、codec-d/cool_fox）
**仓库**: https://github.com/DKTTT/victory-nvidia-8gb

---自动检测硬件并推荐最合适的构建与画质配置，支持自定义目录、从 GitHub 拉取构建、预热与启动。

## 快速开始

1. 解压本包到任意目录（路径不要有空格/中文问题不大，但建议英文路径）
2. 双击 `GTA6-Launcher.bat`
3. 检查「① 设备与配置」页的自动检测结果
4. 到「② 构建与下载」页选择构建（首次会自动扫描本地构建；没有就下载/编译）
5. 到「③ 预热与启动」页：先点「全部预热」，完成后再点「启动游戏」

## 自动检测与推荐规则

| 检测项 | 方式 | 影响 |
|---|---|---|
| 显卡厂商 | nvidia-smi / Win32_VideoController | NVIDIA → vf-nvidia（构建 1）；AMD → vf-main/上游主线 |
| 显存 | nvidia-smi 精确值，其它卡用 WMI 估算 | 决定渲染分辨率：<7GB→480p；7~9GB→540p；10~12GB→720p；≥12GB→1080p |
| CPU / 内存 | WMI | 显示信息（内存 <16GB 建议关后台程序） |
| 系统 | WMI | 显示信息 |

推荐结果会显示在「推荐配置」框里，可以用页面下方的「主机模式 / 渲染分辨率」手动覆盖。

## 目录设置

| 目录 | 用途 |
|---|---|
| 游戏目录 | 含 `game_scarlett_master.exe` 和 `shaders.rpf` 的目录 |
| 构建根目录 | 存放各个 victory 工程（含 `target/diag/victory.exe` 或 `target/release/victory.exe`）的根目录，启动器会递归扫描 |
| 缓存根目录 | 着色器/管线缓存；已知构建自动映射：vf-nvidia→cache-nvidia、vf-main→cache-upstream、cool_fox→cache-coolfox |
| 存档根目录 | 游戏存档与配置；vf-nvidia→perf-data、vf-main→perf-data-up |

所有路径会保存到 `launcher-config.json`，下次打开自动恢复。

## 从 GitHub 下载构建

「② 构建与下载」页：

- **仓库**：`用户名/仓库名`（默认 `DKTTT/victory-nvidia-8gb`）
- **分支**：默认 `tools-and-patches`
- **下载源码 ZIP**：下载 `codeload.github.com/仓库/zip/refs/heads/分支` 并解压到「下载到」目录
- **下载 Release**：读取 GitHub 最新 Release，选 Windows/x64 附件下载
- **编译选中的源码构建**：调用 `cargo build --profile diag -p victory --features diagnostics`（需要已安装 Rust 工具链）

下载使用系统代理（墙内请先开代理）。下载完成后点「重新扫描本地构建」即可选用。

## 预热与启动

- **预热着色器**：`victory shaders shaders.rpf`（2~5 分钟，可中断续传）
- **预编译管线**：`victory warm --used`（3~10 分钟，可中断续传）
- **全部预热**：先着色器，完成后自动接续管线预编译（进度条 + 实时日志 + 停止按钮）
- **启动游戏**：自动套用渲染缩放（按分辨率换算）、两平面合成修复白屏、纹理等待修复、光追跳过列表等参数

## 常见问题

**Q: 启动后白屏？**
确认构建是 vf-nvidia / vf-main 且 `VICTORY_COMPOSE=1`（启动器自动设置）。

**Q: 预热很慢？**
管线预编译受显卡驱动 PSO 编译速度限制，首次 3~10 分钟属正常；中断后下次继续。

**Q: 提示找不到 victory.exe？**
构建根目录要指向含 `目标工程/target/diag/victory.exe` 的目录；用「重新扫描本地构建」确认。

**Q: 想用自己编译的版本？**
把工程放在构建根目录下，编译出 `target/diag/victory.exe` 或 `target/release/victory.exe` 后重新扫描即可。

## 已知限制

- Intel 核显/其他显卡不在支持范围（会提示）
- 自动检测显存对非 NVIDIA 卡可能不准（WMI 4GB 上限问题），可手动改分辨率
- 从 GitHub 下载源码后需要自备 Rust 工具链才能编译
## 上游更新管理（新增）

启动器能管理构建的上游更新，避免「更新后白屏/变慢」的坑：

| 功能 | 说明 |
|---|---|
| 版本显示 | 选中构建后显示 `分支@commit`、翻译器版本、缓存状态 |
| 缓存状态 | 检测缓存目录里已有的预热结果；**构建比缓存新**或**翻译器版本变化**会提示「建议重新全部预热」|
| 检查上游更新 | 对 git 工程执行 `git fetch`（走代理），显示落后多少个提交、上游最新提交 |
| 更新并编译 | 自动备份当前 exe → `git pull --ff-only` → `cargo build --profile diag` → 标记缓存过期 |
| 回滚上一版本 | 从 `victory.exe.bak-*` 恢复上一个可用的 exe |
| 启动前提醒 | 缓存过期时弹窗确认，避免带着旧缓存启动导致卡顿 |

**建议流程**：检查更新 → 更新并编译 → 全部预热 → 启动。更新前启动器会自动留备份，不满意可回滚。

> 已知问题：上游 2026-11-26 的 93 提交版本在 8GB NVIDIA 上实测白屏/崩溃，暂不建议更新。

## 排行榜与自动推荐（新增）

启动器每次打开都会从 **GTA VI PC Race**（`vuyp.github.io/gta6-pc-race`）拉取最新排名：

- 数据源：`https://vuyp.github.io/gta6-pc-race/src/data.json`（每 15 分钟更新一次，48 个项目）
- 显示：前 25 名的 排名 / 阶段 / 画面分 / 速度分 / 稳定分 / 仓库
- **本机推荐**：按显卡厂商、显存、速度、稳定性、排名综合打分，列出前 3 个最适合你的项目
- **本地构建在榜情况**：每个本地构建对应榜上哪个项目、第几名（含已知问题标注）
- **★ 本地最适合你的构建**：从你已有的构建里挑出最匹配的（自动排除已知白屏的构建）
- 网络失败时自动使用上次缓存（`race-cache.json`）

> 排行榜数据是各项目自报 + 第三方核实，仅供参考；启动器推荐的是"最适合本机硬件"的项目，不代表一定能玩。

## 键盘映射（新增，⑤ 标签页）

自己绑键：每行一条 `源键 = 目标键`，`#` 开头是注释。

```
CapsLock = Escape
F1 = Tab
W = Up
```

- 可用键名：`A-Z 0-9 F1-F12 Space Enter Esc Tab Shift Ctrl Alt CapsLock Backspace Up Down Left Right Home End PgUp PgDn Insert Delete Num0-Num9`，也可以直接写 `0x41` 这样的 VK 值
- **只在游戏窗口聚焦时生效**（不影响打字/浏览器）
- `Ctrl+Alt+M` 随时开/关映射
- 勾选「启动游戏时自动开启映射」→ 启动游戏自动启用；关闭启动器自动卸载
- 实现：系统级低级键盘钩子（`keymap.cs`）；若被杀毒软件拦截会提示安装失败

> 注意：部分游戏用 DirectInput 原始输入时，键盘钩子可能收不到；本游戏（GameInput）实测可用。

## v1.3.1 修复

- **多开检测加强**：以前只检测"有窗口的 victory 进程"，如果另一个实例还在加载（窗口未出现）就拦不住，第二个实例会因缓存/存档文件锁报 `0x80070005（拒绝访问）`。现在检测**任意 victory 进程**，并提示具体 PID。
- 启动游戏前若检测到残留进程，会弹窗提示先关闭，避免 `0x800005`。
- 启动前可用任务管理器或命令行 `taskkill /F /IM victory.exe /T` 清理残留。

## v1.4 更新

- **排版修复**：窗口放大到 1120×900，Tab 区域加高，修复底部文字/按钮被裁切、⑤页控件重叠的问题。
- **排行榜可点击 → 拉取构建**：④ 排行榜列表支持点选（或双击）项目，然后点「拉取选中项目构建」。
- **不适配提醒**：拉取前检查项目测试硬件与你的配置（厂商/显存）；不匹配时弹窗：
  `配置可能不适配 … 是=继续，否=取消`。
- **拉取方式选择**：是=下载源码并编译（自动找默认分支、调 cargo 编译、编译后自动重新扫描构建）；否=只下载源码 ZIP；取消=不拉取。
- 没有公开仓库的项目（如 CGBJ/ztrx）会提示无法拉取。
