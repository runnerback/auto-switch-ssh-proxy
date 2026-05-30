# Ubuntu 终端工具方案

> **版本**: v1.0
> **更新时间**: 2026-05-25
> **环境**: Ubuntu 26.04 + GNOME 50.1 (Wayland) + NVIDIA RTX 4070
> **当前主力**: WezTerm nightly (`20260331-040028-577474d8`)

记录终端工具选择、WezTerm 完整配置、默认终端设置(两套机制)、踩过的所有坑。

---

## 1. 当前方案总览

| 项 | 值 |
|---|---|
| **主力终端** | WezTerm nightly (GPU 加速、可编程、跨平台一致) |
| **备用终端** | Ptyxis (GNOME 默认,GTK 原生体验) |
| **已卸载** | Terminator (老 x-terminal-emulator,被 WezTerm 取代) |
| **`x-terminal-emulator` 指向** | `/usr/bin/open-wezterm-here` |
| **`xdg-terminal-exec` 指向** | `org.wezfurlong.wezterm.desktop` (via `~/.config/xdg-terminals.list`) |
| **快捷键 `Ctrl+Alt+T`** | → WezTerm |
| **Nautilus 右键「在终端打开」** | → WezTerm,且在当前目录 |

---

## 2. 工具选择

### 2.1 为什么 WezTerm

- **GPU 加速**: 大量输出、长滚动也不卡
- **Lua 配置**: 可编程,远比 INI / JSON 灵活
- **跨平台一致**: 同一份 lua 配置在 Linux/macOS/Windows 通用
- **窗格 / 标签**: 自带 tmux 风格,不用每个项目都装 tmux
- **复制模式 (vim 风格选取)**: 不依赖鼠标
- **连字 (ligatures)**: 默认开,JetBrains Mono `=>`、`!=` 等显示更好看
- **OSC 8 超链接**、**图片协议** 等现代特性

### 2.2 为什么留着 Ptyxis 当备用

- GNOME 50 的官方默认终端,**纯 GTK 原生**
- WezTerm 出问题时(罕见)有兜底
- 集成 GNOME 通知、剪贴板等更"自然"
- 占空间小,留着无害

### 2.3 为什么删 Terminator

老牌 Python+GTK 终端,Ubuntu 默认装了它(并把它设成 `x-terminal-emulator`)。WezTerm 完全覆盖它的功能 + 性能更好,占着默认终端反而碍事。

---

## 3. 安装 WezTerm

### 3.1 ⚠️ 不要用 `sudo apt install wezterm`

Ubuntu apt 仓库里的版本是 `20240203`(2024-02-03),**两年没更新**,且在 GNOME Wayland + NVIDIA 下**直接闪退**:

```
wp_linux_drm_syncobj_surface_v1#100: error 2: Explicit Sync only supported on dmabuf buffers
```

这是 WezTerm 旧版的 Wayland `explicit sync` 协议 bug,nightly 已修复。

WezTerm 上游 2024 年起停止 stable release,**只发 nightly**。

### 3.2 装 nightly 二进制

```bash
TMP=$(mktemp -d); cd "$TMP"
curl -fL --progress-bar -o wezterm-nightly.deb \
  https://github.com/wezterm/wezterm/releases/download/nightly/wezterm-nightly.Ubuntu24.04.deb
sudo apt remove -y wezterm 2>/dev/null   # 如果之前装过 apt 稳定版,先卸
sudo apt install -y ./wezterm-nightly.deb
cd / && rm -rf "$TMP"
wezterm --version
```

> Ubuntu 26.04 没专门的 nightly 包,**用 Ubuntu24.04 的 .deb 即可**(向前兼容)。

### 3.3 升级

重跑上面那段下载安装命令即可。

---

## 4. WezTerm 完整配置

配置文件: `~/.config/wezterm/wezterm.lua`

保存即热重载,无需重启。

### 4.1 渲染后端 (NVIDIA Wayland 关键)

```lua
config.front_end = 'WebGpu'           -- 必须设! NVIDIA + Wayland 默认 OpenGL 后端会闪退
config.webgpu_power_preference = 'HighPerformance'
-- config.enable_wayland = false      -- 若 WebGpu 仍有花屏,取消注释强制走 X11/XWayland
```

NVIDIA 显卡 + Wayland + WezTerm 默认 OpenGL 后端有兼容问题。`WebGpu` 后端调用 Vulkan,稳定。

### 4.2 字体

```lua
config.font = wezterm.font_with_fallback {
  'JetBrains Mono',           -- 英文首选(代码字体)
  'Fira Code',                -- 没装会自动跳过
  'Cascadia Code',
  'DejaVu Sans Mono',         -- Ubuntu 自带兜底
  'Sarasa Mono SC',           -- 中文回退(严格等宽 CJK)
}
config.font_size = 11.0
config.line_height = 1.1
config.harfbuzz_features = { 'calt=1', 'clig=1', 'liga=1' }   -- 连字
```

> WezTerm 自带回退链,与系统 fontconfig 解耦 —— 即使 fontconfig 配置丢了,中文照常落到 Sarasa Mono SC。详见姐妹文档 [`../fonts/README.md`](../fonts/README.md)。

### 4.3 配色与窗口

```lua
config.color_scheme = 'Tokyo Night'
config.window_background_opacity = 0.95
config.window_decorations = 'RESIZE'           -- 无标题栏,保留拖拽边
config.window_padding = { left = 8, right = 8, top = 6, bottom = 6 }
```

WezTerm 内置 700+ 配色方案,完整列表: https://wezfurlong.org/wezterm/colorschemes/

常用替换:
- `'Catppuccin Mocha'` — 暖色调暗主题
- `'Gruvbox Dark'` — 经典低饱和
- `'Dracula'` — 紫黑高对比
- `'OneHalfDark'` — Atom 风格

### 4.4 标签栏 / 滚动

```lua
config.use_fancy_tab_bar = false               -- 简洁标签栏
config.hide_tab_bar_if_only_one_tab = true     -- 单标签自动隐藏标签栏
config.tab_max_width = 32
config.scrollback_lines = 10000
config.enable_scroll_bar = false
config.default_cursor_style = 'BlinkingBar'
config.cursor_blink_rate = 600
```

### 4.5 行为

```lua
config.audible_bell = 'Disabled'                       -- 静音
config.window_close_confirmation = 'NeverPrompt'       -- 关窗不二次确认
config.warn_about_missing_glyphs = false               -- 缺字符不弹警告
-- config.default_prog = { '/usr/bin/zsh', '-l' }      -- 想换默认 shell 取消注释
```

### 4.6 完整快捷键定义

见 §6。

---

## 5. 设为系统默认终端

Ubuntu 有**两套并行的「默认终端」机制**,要同时设两套:

### 5.1 机制 A — `x-terminal-emulator` (Debian 风格)

```bash
sudo update-alternatives --config x-terminal-emulator
# 选 /usr/bin/open-wezterm-here
```

`open-wezterm-here` 是 WezTerm 装包自带的脚本:`exec wezterm start --cwd "$PWD"` —— 等价于「在当前目录开 WezTerm」。

适用场景:老式程序 / Debian 风脚本调"默认终端"。

### 5.2 机制 B — `xdg-terminal-exec` (现代 GNOME)

```bash
echo "org.wezfurlong.wezterm.desktop" > ~/.config/xdg-terminals.list
```

适用场景:
- Nautilus 右键 → 「在终端打开」
- GNOME `Ctrl+Alt+T` 快捷键
- 任何用 `xdg-terminal-exec` 协议的现代 GNOME app

### 5.3 验证

```bash
# 机制 A
readlink /etc/alternatives/x-terminal-emulator
# 期望: /usr/bin/open-wezterm-here

# 机制 B
xdg-terminal-exec true 2>&1 | head -2
# 看到 wezterm_gui Spawned 之类 → 成功
```

两套都对了,WezTerm 才是**真正的全局默认**。只设一套会出现「`Ctrl+Alt+T` 开的还是 Ptyxis」之类的诡异现象。

---

## 6. 快捷键速查

### 6.1 自定义部分 (见 wezterm.lua)

| 快捷键 | 作用 |
|---|---|
| `Ctrl+Shift+T` | 新建标签页 |
| `Ctrl+Shift+W` | 关闭当前标签(无确认) |
| `Ctrl+Tab` / `Ctrl+Shift+Tab` | 切换下一个 / 上一个标签 |
| **`Ctrl+Shift+d|`** (即 Ctrl+Shift+d) | **左右分屏** |
| **`Ctrl+Shift+_`** (即 Ctrl+Shift+-) | **上下分屏** |
| `Ctrl+Shift+方向键` | 切换相邻窗格 |
| **`Alt+H/J/K/L`** | 调整窗格大小(vim 风格,每次 5 格) |
| `Ctrl+Shift+X` | 关闭当前窗格(带确认) |
| **`Ctrl+Shift+A`** | **全选并复制整个滚动缓冲** (含 toast 提示) |
| `Ctrl+Insert` / `Shift+Insert` | 复制 / 粘贴(备用快捷键) |
| `Ctrl+=` / `Ctrl+-` / `Ctrl+0` | 字号放大 / 缩小 / 重置 |
| `F11` | 全屏切换 |
| `Ctrl+Shift+Space` | 进入复制模式 |

### 6.2 默认快捷键 (WezTerm 内置)

| 快捷键 | 作用 |
|---|---|
| `Ctrl+Shift+C` / `Ctrl+Shift+V` | 复制 / 粘贴 |
| `Ctrl+Shift+1` … `9` | 跳到第 N 个标签 |
| `Ctrl+Shift+F` | 在滚动缓冲里搜索 |
| `Shift+PageUp/Down` | 翻页滚动 |
| `Ctrl+Shift+K` | 清屏 + 清滚动缓冲 |
| `Ctrl+Shift+R` | 重载配置 |
| `Ctrl+Shift+P` | **命令面板**(列出所有动作)⭐ |
| `Ctrl+Shift+U` | 字符选择器(emoji / unicode) |
| `Ctrl+Shift+,` | 重命名当前标签 |
| `Ctrl+Shift+Z` | 窗格全屏 / 还原(zoom) |
| 鼠标拖选 | 自动复制到 selection 缓冲 |
| `Shift+鼠标拖选` | 矩形 / 列选区 |

### 6.3 复制模式 (按 Ctrl+Shift+Space 进入)

vim 风格:`hjkl` 移动 / `w b` 跳词 / `0 $` 行首尾 / `g G` 顶底 / `v` 开始选区 / `y` 复制 / `Esc` 退出 / `/` 搜索 / `n N` 下一个上一个匹配。

---

## 7. Ptyxis 备用终端

GNOME 自带,无需安装。

**配置**(gsettings):

```bash
gsettings set org.gnome.Ptyxis use-system-font false
gsettings set org.gnome.Ptyxis font-name 'JetBrains Mono 11'
```

> Ptyxis **没有自带字体回退链**,完全依赖 fontconfig 处理 CJK。所以 [`../fonts/README.md`](../fonts/README.md) 里的 `99-jetbrains-cjk-fallback.conf` 对 Ptyxis 必不可少。

GUI 调整: Ptyxis 窗口右上角菜单 → Preferences。

---

## 8. 故障排查

| 症状 | 原因 / 修复 |
|---|---|
| WezTerm 双击图标闪退 | NVIDIA + Wayland + OpenGL 冲突。确认 `config.front_end = 'WebGpu'` 已设(§4.1)。仍崩则 `'Software'` 或加 `config.enable_wayland = false` |
| WezTerm 启动卡几秒 | 通常是字体扫描慢。临时禁用 `wezterm --skip-config` 看是否快 |
| `Ctrl+Shift+\` 不分屏 | `key = '\\'` 错的(`Ctrl+Shift+\` 实际产生 `\|`)。正确写 `key = '\|', mods = 'CTRL\|SHIFT'`(§6.1 已是) |
| `Alt+Shift+方向键`不调整窗格 | GNOME 抢了这个组合做工作区切换。改用 `Alt+H/J/K/L`(§6.1 已是) |
| 中文宽度对不上英文 | 缺 Sarasa Mono SC,装见 `../fonts/README.md` |
| `Ctrl+Alt+T` 还是开 Ptyxis | `xdg-terminals.list` 没设(§5.2) |
| Nautilus「在终端打开」是 Ptyxis | 同上 |
| 升级后配置语法错 | 看 `~/.local/share/wezterm/` 下日志,常见是 Lua API 变更。比对 GitHub release notes |

### 8.1 检查 WezTerm 配置语法

```bash
wezterm --config-file ~/.config/wezterm/wezterm.lua show-keys 2>&1 | head -5
# 没报错 = 配置语法 OK
```

---

## 9. 一键还原 (回 Ptyxis / 卸 WezTerm)

```bash
# 1. x-terminal-emulator 切回 ptyxis
sudo update-alternatives --config x-terminal-emulator   # 选 ptyxis

# 2. 删 xdg-terminals.list
rm ~/.config/xdg-terminals.list

# 3. (可选) 卸 WezTerm
sudo apt remove -y wezterm-nightly

# 4. (可选) 删配置
rm -rf ~/.config/wezterm
```

> 字体不用动 —— JetBrains Mono / Sarasa 留着对 Ptyxis 也有用。

---

## 10. 变更记录

| 版本 | 日期 | 变更 |
|---|---|---|
| v1.0 | 2026-05-25 | 初版:记录 WezTerm nightly 安装、Lua 配置、两套默认终端机制、快捷键、踩过的所有坑 |
