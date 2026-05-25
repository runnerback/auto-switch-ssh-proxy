# Ubuntu 字体方案

> **版本**: v1.0
> **更新时间**: 2026-05-25
> **机器**: zhang-Legion-Y9000P-IRX9 (Ubuntu 26.04 + GNOME 50.1)

记录当前系统所有字体设置：GNOME 桌面 + WezTerm + Ptyxis + Cursor + 输入法候选窗。每项都说明**用什么字体、配置在哪、怎么改、怎么还原**。

---

## 1. 当前方案总览

| 位置 | 英文字体 | 中文字体 | 字号 |
|---|---|---|---|
| GNOME 界面 (Interface) | Sarasa UI SC | Sarasa UI SC | 11 |
| GNOME 文档 (Document) | Sarasa Gothic SC | Sarasa Gothic SC | 11 |
| GNOME 等宽 (Monospace) | JetBrains Mono | Sarasa Mono SC (fontconfig 自动回退) | 11 |
| 标题栏 (titlebar) | Ubuntu Sans Bold | — | 11 |
| **WezTerm** | JetBrains Mono | Sarasa Mono SC | 11 |
| **Ptyxis** (GNOME 默认终端) | JetBrains Mono | Sarasa Mono SC (fontconfig 自动回退) | 11 |
| **Cursor** 编辑器 | JetBrains Mono | Sarasa Mono SC | 12 |
| **Cursor** 终端 | (沿用 editor / 系统等宽) | — | 13 |
| 输入法候选窗 (kimpanel) | Sarasa UI SC | Sarasa UI SC | 13 |

**核心理念**：英文 = JetBrains Mono（代码字体首选）；中文 = Sarasa 家族（更纱黑体，字库全、严格等宽）；两者用 fontconfig 自动衔接，无需在每个 app 单独写回退。

---

## 2. 为什么换默认字体

Ubuntu 出厂默认：
- 界面：Ubuntu Sans 11
- 文档：Sans 11
- 等宽：Ubuntu Sans Mono 11
- 中文：Noto Sans CJK SC（思源黑体）+ Noto Serif CJK SC（思源宋体）

**问题**：Noto CJK 对某些**生僻字、异体字、人名字符**覆盖不全 —— 会出现「方框」或回退到不协调的字体。

**Sarasa 优势**：
1. 字库更全（基于思源 + 扩展）
2. **CJK 严格等宽**（Noto CJK 不是严格 2:1 等宽，终端表格易错位）
3. 视觉风格统一（UI / Gothic / Mono / Fixed / Term 同源）

---

## 3. 各处详细配置

### 3.1 GNOME 系统字体

**配置位置**: `gsettings org.gnome.desktop.interface`

```bash
gsettings set org.gnome.desktop.interface font-name 'Sarasa UI SC 11'
gsettings set org.gnome.desktop.interface document-font-name 'Sarasa Gothic SC 11'
gsettings set org.gnome.desktop.interface monospace-font-name 'JetBrains Mono 11'
```

**GUI 改法**: 装 `gnome-tweaks`，「字体」标签页改三项。

立即生效；Electron 类（Cursor、Chrome）需重启才看到变化。

### 3.2 fontconfig CJK 回退规则

**问题**：JetBrains Mono 不含中文字形。设 monospace = JetBrains Mono 后，中文字符会回退 —— 默认回退到什么由 fontconfig 决定，可能是 Noto 或别的。

**修复**：声明 JetBrains Mono 的中文回退 = Sarasa Mono SC。

**文件**: `~/.config/fontconfig/conf.d/99-jetbrains-cjk-fallback.conf`

```xml
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <match target="pattern">
    <test name="family"><string>JetBrains Mono</string></test>
    <edit name="family" mode="append" binding="strong">
      <string>Sarasa Mono SC</string>
    </edit>
  </match>
</fontconfig>
```

改完执行 `fc-cache -f` 刷新。

**验证回退链**：
```bash
fc-match -s "JetBrains Mono" | head -3
# 期望第二行: Sarasa-Regular.ttc: "Sarasa Mono SC" "Regular"
```

### 3.3 WezTerm

**配置位置**: `~/.config/wezterm/wezterm.lua`

```lua
config.font = wezterm.font_with_fallback {
  'JetBrains Mono',
  'Fira Code',                 -- 备选英文（若没装会跳过）
  'Cascadia Code',
  'DejaVu Sans Mono',          -- Ubuntu 自带等宽，再兜底
  'Sarasa Mono SC',            -- 中文回退
}
config.font_size = 11.0
config.line_height = 1.1
config.harfbuzz_features = { 'calt=1', 'clig=1', 'liga=1' }   -- 连字
```

保存自动热重载，无需重启 WezTerm。

> WezTerm 自带回退链，与 fontconfig 解耦 —— 即使 fontconfig 配置丢了，中文也会回退到 Sarasa Mono SC。

### 3.4 Ptyxis (GNOME 默认终端)

**配置位置**: `gsettings org.gnome.Ptyxis`

```bash
gsettings set org.gnome.Ptyxis use-system-font false
gsettings set org.gnome.Ptyxis font-name 'JetBrains Mono 11'
```

Ptyxis 不像 WezTerm 那样有自带回退链，**完全依赖 fontconfig**。所以 §3.2 的 fontconfig 规则**必须存在**，否则 Ptyxis 里的中文会回退到不合适字体（且非等宽）。

**GUI 改法**: Ptyxis 窗口右上角菜单 → Preferences → 取消「Use system font」→ 选字体。

### 3.5 Cursor

**配置位置**: `~/.config/Cursor/User/settings.json`

```json
{
  "editor.fontFamily": "'JetBrains Mono', 'Sarasa Mono SC', 'Droid Sans Mono', 'monospace', monospace",
  "editor.fontSize": 12,
  "terminal.integrated.fontSize": 13
}
```

Cursor 的 `fontFamily` 是逗号分隔字符串（与 WezTerm 的 Lua 数组不同），自带回退链。

**Cursor 终端**没显式设 `terminal.integrated.fontFamily` —— 沿用 `editor.fontFamily` 或 Cursor 默认。若想给终端单独指定（如更大字号）：

```json
"terminal.integrated.fontFamily": "'JetBrains Mono', 'Sarasa Mono SC'"
```

**GUI 改法**: `Ctrl+,` 打开设置，搜 `font family` / `terminal font`。

### 3.6 输入法候选窗 (fcitx5 + kimpanel)

候选词窗口由 **kimpanel GNOME 扩展**绘制（gnome-shell 代画）。

**配置位置**: kimpanel 扩展的 gsettings。

```bash
SD=~/.local/share/gnome-shell/extensions/kimpanel@kde.org/schemas/
gsettings --schemadir "$SD" set org.gnome.shell.extensions.kimpanel font 'Sarasa UI SC 13'
```

**GUI 改法**: `gnome-extensions prefs kimpanel@kde.org`

> 候选窗用 UI 字体（Sarasa UI SC）而不是等宽 —— 候选词不需要对齐，UI 字体更紧凑、字号略大（13）便于阅读。

---

## 4. 字体安装位置 & 来源

### Ubuntu 自带（apt 系统包）

| 字体 | 包 |
|---|---|
| Ubuntu Sans / Ubuntu Sans Mono | `fonts-ubuntu` |
| Noto Sans CJK SC / Noto Serif CJK SC | `fonts-noto-cjk` |
| DejaVu Sans Mono | `fonts-dejavu` |

### 手动装的字体

| 字体 | 安装位置 | 来源 |
|---|---|---|
| **JetBrains Mono** | `/usr/share/fonts/truetype/jetbrains-mono/` | apt `fonts-jetbrains-mono` |
| **JetBrainsMono Nerd Font** | `~/.local/share/fonts/JetBrainsMono/` | https://github.com/ryanoasis/nerd-fonts releases |
| **Sarasa Gothic**（含 UI/Gothic/Mono/Fixed/Term SC/TC/J/K 全套） | `~/.local/share/fonts/Sarasa-Gothic/` | https://github.com/be5invis/Sarasa-Gothic releases (v1.0.37) |

### Sarasa 重装

```bash
TMP=$(mktemp -d); cd "$TMP"
curl -fL -o sarasa.zip \
  https://github.com/be5invis/Sarasa-Gothic/releases/latest/download/Sarasa-TTC-1.0.37.zip
unzip -oq sarasa.zip
mkdir -p ~/.local/share/fonts/Sarasa-Gothic
mv *.ttc ~/.local/share/fonts/Sarasa-Gothic/
fc-cache -f
cd / && rm -rf "$TMP"
```

> 版本号 `1.0.37` 是当前装的，可换成 latest 拿最新。

---

## 5. 一键还原 Ubuntu 默认

```bash
# GNOME 系统字体
gsettings reset org.gnome.desktop.interface font-name
gsettings reset org.gnome.desktop.interface document-font-name
gsettings reset org.gnome.desktop.interface monospace-font-name

# Ptyxis
gsettings reset org.gnome.Ptyxis use-system-font
gsettings reset org.gnome.Ptyxis font-name

# 删 fontconfig 回退规则
rm -f ~/.config/fontconfig/conf.d/99-jetbrains-cjk-fallback.conf
fc-cache -f

# WezTerm: 手动改 ~/.config/wezterm/wezterm.lua 的 font 块
# Cursor:  手动改 ~/.config/Cursor/User/settings.json
# kimpanel: gsettings --schemadir <SD> reset org.gnome.shell.extensions.kimpanel font
```

> 字体文件本身（Sarasa / JetBrains Mono）**不用删** —— 它们只是装着备用，不被引用就不影响系统。要彻底清：删 `~/.local/share/fonts/Sarasa-Gothic/` 和 `sudo apt remove fonts-jetbrains-mono`，再 `fc-cache -f`。

---

## 6. 故障排查

| 症状 | 检查 |
|---|---|
| 终端中文跟英文宽度对不上 | `fc-list \| grep Sarasa` 确认 Sarasa Mono SC 装了；检查 §3.2 fontconfig 规则在不在 |
| 字体设了但 Cursor / Chrome 没变 | 这些是 Electron，需**完全退出**重启才生效（关进程不是关窗口） |
| 候选窗字体不对 | 候选窗是 kimpanel 扩展画的，改 `org.gnome.shell.extensions.kimpanel font`，不是改 fcitx5 |
| 改了 monospace 但 Ptyxis 没变 | Ptyxis 的 `use-system-font` 设了 `false`，它用自己的 `font-name` 而不是系统等宽。改 Ptyxis 自己的设置 |
| 某汉字仍显示方框 | 该字超出 Sarasa 字库覆盖。装更大字库 `fonts-noto-cjk-extra` 或 `fonts-noto-color-emoji` 补 |
| 终端连字 (ligature) 没生效 | WezTerm: 检查 `harfbuzz_features = { 'calt=1','clig=1','liga=1' }`；Cursor: `"editor.fontLigatures": true` |

---

## 7. 变更记录

| 版本 | 日期 | 变更 |
|---|---|---|
| v1.0 | 2026-05-25 | 初版：记录当前完整字体方案 |
