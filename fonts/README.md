# Ubuntu 字体方案

> **版本**: v1.4
> **更新时间**: 2026-05-30
> **机器**: zhang-Legion-Y9000P-IRX9 (Ubuntu 26.04 + GNOME 50.1)

记录当前系统所有字体设置：GNOME 桌面 + WezTerm + Ptyxis + Cursor + 输入法候选窗。每项都说明**用什么字体、配置在哪、怎么改、怎么还原**。

---

## ⭐ 推荐字体经验(2026-05-30 新增）— 英文比例正文用 **Inter**

本机此前的字体方案只覆盖两类:**等宽**(JetBrains Mono)和**中文**(Sarasa 全家)。缺一类 —— **英文比例正文字体**(网页 UI / 文档正文 / 仪表盘里的非等宽英文)。这部分一直在回退到 Sarasa Gothic 的拉丁字形,而 Sarasa 的拉丁是为「跟中文方块协调」设计的,单独排英文正文偏宽、不够精致。

在做一个 Plotly Dash 仪表盘(Snowpack telemetry 深色风格)时,验证了一套效果很好的**网页字体三件套**,值得推广到系统 / 浏览器:

| 用途 | 字体 | 状态 |
|---|---|---|
| **英文比例正文 / UI** | **Inter** | ⬅ 本次推荐**补装** |
| 中文 | Sarasa Gothic SC | 已装 |
| 数字 / 代码 / 等宽 | JetBrains Mono | 已装 |

**为什么是 Inter**:

- 专为屏幕 UI 设计的中性无衬线,字形开阔、x-height 高,小字号下清晰。
- 内建 `tnum`(等宽数字)、`zero`(斜杠零)等 OpenType 特性,排数字 / KPI 表格整齐,与 JetBrains Mono 同属「工程感」家族,搭配协调。
- 中英混排时浏览器按字符自动切 **Inter(英文)/ Sarasa(中文)**,无需手写每个字符的回退。
- GitHub / Linear / Vercel 等大量现代 web 应用的默认正文字体,辨识度与可读性经过大规模验证。

**安装**(见 §4):

```bash
sudo apt install fonts-inter          # 或 fonts-inter-variable(可变字体版)
fc-cache -f
fc-list | grep -i inter               # 验证装上
```

**怎么用**:

- **网页 / 应用内**(最常见,本经验来源):在 CSS / 配置里把英文正文字体栈设成下面这串,中文自动回退给 Sarasa ——
  ```
  'Inter', 'Sarasa Gothic SC', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif
  ```
- **全局比例正文**(可选):把 GNOME 文档字体设为 `Inter`(`gsettings set org.gnome.desktop.interface document-font-name 'Inter 11'`),中文仍由 fontconfig 回退到 Sarasa。
- **不要**把它设成 monospace —— Inter 是比例字体,终端 / 代码仍用 JetBrains Mono(详见 §7.1 等宽 vs 比例)。

---

## ⭐ 推荐字体经验(2026-05-30 新增) — 代码 / 终端可选用 **Maple Mono NF CN**

§3 / §1 总览里默认代码字体是 JetBrains Mono(方正学院派),功能完备但风格偏严谨。如果想要**更现代、更亲和、连字更丰富**的代码字体,**Maple Mono NF CN** 是 Sarasa Mono SC 之外最值得试的中文等宽字体,目前在年轻程序员社区起势。

跟前面 Inter 那段不同,Maple 不是「补缺」而是「可选替代」 —— 直接顶替 JetBrains Mono 的位置;装上不影响 JetBrains Mono,什么时候想试就改一行配置,不喜欢就一行回退。

| 用途 | 替代关系 | 状态 |
|---|---|---|
| **代码 / 终端等宽字体** | **Maple Mono NF CN** 替代 JetBrains Mono | ⬅ 本次推荐**补装** |
| 中文兜底 | Sarasa Mono SC | 已装(覆盖 Maple 罕用字漏字) |
| Nerd Font 图标 | Maple NF 版**自带**,不需要单独装 Nerd Font | 内置 |

**为什么是 Maple Mono NF CN**:

- **字形圆润亲和** —— Sarasa / JetBrains Mono 是方正直角,Maple 是圆角,代码不那么「工程机器人感」。
- **连字最丰富** —— `=>` `!=` `>=` `<=` `===` `|>` `->` `<-` `::` `??` 等 70+ 种,JS / TS / Rust / Haskell 颜值显著提升。
- **NF 版自带 Nerd Font 图标** —— starship / oh-my-zsh powerline / lvim / lazyvim 的图标直接能用,不必再装 Symbols Nerd Font。
- **CN 版自带中文字形** —— 基于 ResourceHanRoundedCN(圆角思源),代码注释中文够用,无需 fontconfig 回退;罕用字仍挂 Sarasa Mono SC 兜底。
- **斜体是 cursive 风格** —— 跟 JetBrains Mono 的硬直斜体完全不同,有手写感(看个人喜好)。

**安装**(用 GitHub API 拿 latest 资产,跟 §4 Sarasa 同套路):

```bash
DL_URL=$(curl -fsSL https://api.github.com/repos/subframe7536/maple-font/releases/latest \
  | grep -oE '"browser_download_url"[^"]*"[^"]*MapleMono-NF-CN\.zip"' \
  | head -1 | sed 's/.*"\(http[^"]*\)"/\1/')

TMP=$(mktemp -d); cd "$TMP"
curl -fL -o maple.zip "$DL_URL"
unzip -oq maple.zip
mkdir -p ~/.local/share/fonts/Maple-Mono-NF-CN
mv *.ttf ~/.local/share/fonts/Maple-Mono-NF-CN/
fc-cache -f
cd / && rm -rf "$TMP"
fc-match 'Maple Mono NF CN'   # 验证命中
```

资产名约定(maple-font 仓库 release 列出十几个,别拿错):
- `MapleMono-NF-CN.zip` ← **就用这个**(NF Nerd Font + CN 中文,~150MB,16 个 ttf)
- `MapleMono-CN.zip` 不带 NF 图标
- `MapleMonoNL-*.zip` NL = **No Ligature** 无连字版
- `*-unhinted.zip` 不带 hinting,Linux 渲染会发糊,**不要拿**

**怎么用**(三场景):

1. **Cursor 编辑器 + 终端**(强烈推荐⭐⭐⭐⭐⭐):改 `~/.config/Cursor/User/settings.json`
   ```json
   "editor.fontFamily": "Maple Mono NF CN, Sarasa Mono SC, monospace",
   "editor.fontLigatures": true,
   "terminal.integrated.fontFamily": "Maple Mono NF CN, Sarasa Mono SC, monospace"
   ```
   **必须开 `editor.fontLigatures: true`**,否则 `=>` 这些连字不渲染连字字形,等于浪费 Maple 的招牌特性。Cursor 改完要**完全退出重启**(Electron 字体缓存)。

2. **WezTerm**(推荐⭐⭐⭐⭐):`~/.config/wezterm/wezterm.lua` 的 `config.font` 把 `'Maple Mono NF CN'` 放第一项,`'Sarasa Mono SC'` 兜底中文;保存自动热重载。

3. **GNOME monospace**(看口味⭐⭐⭐):`gsettings set org.gnome.desktop.interface monospace-font-name 'Maple Mono NF CN 11'`,影响 gnome-text-editor、Ptyxis 默认 use-system-font 等。

**不要用作 UI 字体** —— Maple 是 mono,GNOME 界面 / 文档 / 浏览器正文用 mono 会显得稀疏死板(详见 §7.1 等宽 vs 比例)。

**一键回退到 JetBrains Mono**(不喜欢):
```bash
# Cursor
sed -i 's|"editor.fontFamily": "[^"]*"|"editor.fontFamily": "JetBrains Mono, Sarasa Mono SC, Droid Sans Mono, monospace"|' ~/.config/Cursor/User/settings.json
sed -i 's|"terminal.integrated.fontFamily": "[^"]*"|"terminal.integrated.fontFamily": "JetBrains Mono, Sarasa Mono SC, Droid Sans Mono, monospace"|' ~/.config/Cursor/User/settings.json
# GNOME
gsettings set org.gnome.desktop.interface monospace-font-name 'JetBrains Mono 11'
# WezTerm: 手动改 ~/.config/wezterm/wezterm.lua 把 'Maple Mono NF CN' 行删掉,保存即生效
```

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
  "editor.fontFamily": "JetBrains Mono, Sarasa Mono SC, Droid Sans Mono, monospace",
  "editor.fontSize": 12,
  "terminal.integrated.fontSize": 13,
  "terminal.integrated.fontFamily": "JetBrains Mono, Sarasa Mono SC, Droid Sans Mono, monospace"
}
```

> **写法注意**:Linux 下 VS Code / Cursor 推荐字体名**不加引号**,逗号分隔(与 WezTerm 的 Lua 数组不同)。最后兜底用 `monospace` 关键字也**不要**加引号 —— 那是 CSS 通用字体关键字,加引号会被当成查找名为 `monospace` 的字体(可能找不到),导致回退链断裂。

**为何 `terminal.integrated.fontFamily` 也要显式设**:Cursor / VS Code 的内置终端如果不显式指定,沿用 Cursor 默认值(`monospace`),不沿用 `editor.fontFamily`。所以**编辑器和终端的字体设置是独立的两个 key**,改字体方案时两个都要写。

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
| **Inter**(英文比例正文,⭐ 推荐补装) | `fonts-inter`(或 `fonts-inter-variable`);非默认安装,见开头「推荐字体经验」 |

### 手动装的字体

| 字体 | 安装位置 | 来源 |
|---|---|---|
| **JetBrains Mono** | `/usr/share/fonts/truetype/jetbrains-mono/` | apt `fonts-jetbrains-mono` |
| **JetBrainsMono Nerd Font** | `~/.local/share/fonts/JetBrainsMono/` | https://github.com/ryanoasis/nerd-fonts releases |
| **Sarasa Gothic**（含 UI/Gothic/Mono/Fixed/Term SC/TC/J/K 全套） | `~/.local/share/fonts/Sarasa-Gothic/` | https://github.com/be5invis/Sarasa-Gothic releases (v1.0.37) |
| **Inter**（英文比例正文，⭐ 推荐） | apt 装在 `/usr/share/fonts/`；或手动 `~/.local/share/fonts/Inter/` | 优先 apt `fonts-inter`；离线/要新版用 https://github.com/rsms/inter releases |
| **Maple Mono NF CN**（圆角现代代码字体 + Nerd Font 图标 + 中文，⭐ 推荐作 JetBrains Mono 的替代） | `~/.local/share/fonts/Maple-Mono-NF-CN/` | https://github.com/subframe7536/maple-font releases，资产名 `MapleMono-NF-CN.zip`（见开头「推荐字体经验」）|

### Sarasa 重装

Sarasa 的 release 资产文件名带版本号（如 `Sarasa-TTC-1.0.39.zip`），无法用 `/releases/latest/download/<静态名>` 模式跟随 latest。下面用 GitHub API 动态拿 latest 资产 URL，省去每次改版本号：

```bash
DL_URL=$(curl -fsSL https://api.github.com/repos/be5invis/Sarasa-Gothic/releases/latest \
  | grep -oE '"browser_download_url"[^"]*"[^"]*Sarasa-TTC-[^"]+\.zip"' \
  | head -1 | sed 's/.*"\(http[^"]*\)"/\1/')
echo "$DL_URL"   # 应该形如 https://github.com/.../Sarasa-TTC-1.0.39.zip

TMP=$(mktemp -d); cd "$TMP"
curl -fL -o sarasa.zip "$DL_URL"
unzip -oq sarasa.zip
mkdir -p ~/.local/share/fonts/Sarasa-Gothic
mv *.ttc ~/.local/share/fonts/Sarasa-Gothic/
fc-cache -f
cd / && rm -rf "$TMP"
```

> ZIP 包含 10 个 ttc(Regular / Bold / Italic / ExtraLight 等共 ~400MB),涵盖 UI / Gothic / Mono / Fixed / Term 全套 SC/TC/J/K 变体。

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
| Files / Settings 等 GTK 应用里中英文宽度不 2:1 | **预期行为**，UI 字体故意不等宽，详见 §7.1 |

---

## 7. 字体选型参考

### 7.1 等宽 vs 比例：UI 字体不该追求 2:1

Sarasa 五个变体常被误解。**严格等宽（中英 2:1）只是 Mono / Fixed / Term 的特性**，UI 和 Gothic 是**比例字体**：中文方块 1em、英文按字形宽度（`i` 窄、`m` 宽），中英文混排时**不会**也**不该** 2:1。

| 字体设计 | 中文宽度 | 英文宽度 | 中英比例 | 例子 |
|---|---|---|---|---|
| **比例字体**（UI / Gothic） | 1em 方块（中文之间等宽） | 按字形（不等宽） | 不固定 | Sarasa UI SC、Sarasa Gothic SC |
| **严格等宽**（Mono / Fixed / Term） | 1em 方块 | 0.5em（每字等宽） | **2:1** | Sarasa Mono SC |

**为什么 UI 字体故意不等宽**：

- UI 控件追求**紧凑可读**，等宽字体在按钮/菜单/对话框里显得稀疏死板。
- macOS Finder（PingFang）、Windows Explorer（微软雅黑）同样用比例字体，中英也不 2:1。
- 等宽是**功能性需求**（终端表格、代码缩进、ASCII art），不是审美需求。

**什么场景应该追求 2:1**：

| 场景 | 用 | 已配置位置 |
|---|---|---|
| 终端（WezTerm、Cursor 终端、Ptyxis） | `Sarasa Mono SC` | §3.3 / §3.4 / §3.5 |
| 代码编辑器（Cursor 编辑区、gnome-text-editor）| monospace + Sarasa Mono SC 回退 | §3.2 + §3.5 |
| 文件管理器、系统设置、菜单 | `Sarasa UI SC`（**保持比例**） | §3.1 |
| 文档正文、Markdown 渲染 | `Sarasa Gothic SC`（**保持比例**） | §3.1 |

**别折腾的修法**：把 GTK 应用界面字体改成 Mono 来追求 Files 中英 2:1 —— 整个系统菜单、按钮都会变等宽，看起来非常奇怪。这是为了一个不该等宽的场景牺牲所有 UI 体验，不值得。

### 7.2 Ubuntu 上其他常用中文字体（按场景选）

Sarasa 是程序员场景的事实标准，但分用途有别的强力选项。下表按场景列出，**不重复 Sarasa**：

| 字体 | 类型 | 适合场景 | 相比 Sarasa | 安装方式 |
|---|---|---|---|---|
| **Noto Sans CJK SC** | 比例（半宽等宽） | 系统默认兼容、跨语言一致 | 字库最广（含罕用字），但等宽不严格 | `sudo apt install fonts-noto-cjk` (Ubuntu 默认已装) |
| **Noto Serif CJK SC** | 衬线（宋体） | 正式文档、印刷模拟 | Sarasa 无衬线版 | `sudo apt install fonts-noto-cjk-extra` |
| **Maple Mono CN** | 等宽 + 现代连字 | 代码（喜欢华丽连字 / 现代英文）| 英文更精致 + 连字更多，但中文字库偏小 | GitHub `subframe7536/maple-font` releases |
| **LXGW WenKai（霞鹜文楷）** | 楷体比例 | 长文阅读、电子书、博客正文 | 楷体阅读体验远超黑体 | GitHub `lxgw/LxgwWenKai` releases |
| **LXGW Neo XiHei（霞鹜新晰黑）** | 黑体比例 | 系统 UI 替代（比 Noto 更细、更现代）| 笔画更细，视觉更轻 | GitHub `lxgw/LxgwNeoXiHei` releases |
| **HarmonyOS Sans SC** | 黑体比例 | 系统 UI（华为开源） | 现代感强、字重齐全 | GitHub `openharmony` 镜像或 `harmonyos-fonts` |
| **OPPO Sans** | 黑体比例 | UI 替代 | 圆润亲和 | OPPO 官网或社区镜像 |
| **文泉驿（WenQuanYi）** | 黑体比例 | — | **历史遗物，新装不推荐** | `sudo apt install fonts-wqy-*`（已被 Noto CJK 取代） |

**不要装的**：

- **PingFang SC（苹方）** —— Apple 商业字体，版权敏感，社区不流通。
- **微软雅黑 / Microsoft YaHei** —— 微软商业字体，同上。
- **思源黑体（Source Han Sans）** —— 与 Noto Sans CJK 同源（Adobe + Google 联合开发，Noto 是 Google 发行名），**不要重复装**，否则 fontconfig 优先级会乱。

**按场景的推荐组合**：

| 你的需求 | 推荐方案 |
|---|---|
| **纯程序员，只在乎代码/终端** | Sarasa Mono SC（已装），别的不用碰 |
| **同时想要好看的 UI 字体** | 系统 UI 用 LXGW Neo XiHei 或 HarmonyOS Sans SC 替代 Sarasa UI SC |
| **常读中文长文/写博客** | 加装 LXGW WenKai，VS Code Markdown 预览 + 浏览器自定义 CSS 指向它 |
| **代码喜欢华丽英文连字** | 把 JetBrains Mono 换成 Maple Mono（保留 Sarasa Mono SC 做中文回退）|

**通用安装套路（GitHub release ZIP）**：

```bash
# 模板，把 OWNER/REPO 和 ASSET_NAME_PATTERN 换成对应字体
DL_URL=$(curl -fsSL https://api.github.com/repos/OWNER/REPO/releases/latest \
  | grep -oE '"browser_download_url"[^"]*"[^"]*ASSET_NAME_PATTERN[^"]+\.(zip|tar\.gz)"' \
  | head -1 | sed 's/.*"\(http[^"]*\)"/\1/')

TMP=$(mktemp -d); cd "$TMP"
curl -fL -o font.zip "$DL_URL"
unzip -oq font.zip   # 或 tar xzf 看格式
mkdir -p ~/.local/share/fonts/<FontName>/
mv *.ttf *.ttc *.otf ~/.local/share/fonts/<FontName>/ 2>/dev/null
fc-cache -f
cd / && rm -rf "$TMP"
```

具体仓库速查：
- Maple Mono CN: `subframe7536/maple-font`，资产名 `MapleMono-CN-*.zip`
- LXGW WenKai: `lxgw/LxgwWenKai`，资产名 `LXGWWenKai-*.ttf`
- LXGW Neo XiHei: `lxgw/LxgwNeoXiHei`，资产名 `LXGWNeoXiHei*.ttf`
- HarmonyOS Sans: 在 GitHub 搜 `harmonyos-fonts` 取镜像（华为官方分发渠道散乱）

---

## 8. 变更记录

| 版本 | 日期 | 变更 |
|---|---|---|
| v1.0 | 2026-05-25 | 初版：记录当前完整字体方案 |
| v1.2 | 2026-05-30 | 加 §7 字体选型参考：§7.1 等宽 vs 比例的常见误区（UI 字体故意不等宽）、§7.2 Ubuntu 上其他常用中文字体（Maple Mono CN / LXGW WenKai / LXGW Neo XiHei / HarmonyOS Sans SC 等的按场景对比）；§6 故障排查表加索引指向 §7.1 |
| v1.3 | 2026-05-30 | 开头加「⭐ 推荐字体经验」：英文比例正文补装 **Inter**（来自 Plotly Dash 仪表盘的网页字体三件套 Inter + Sarasa + JetBrains Mono），含安装与字体栈用法；§4 安装表加 Inter（apt `fonts-inter` / GitHub `rsms/inter`）；头部版本对齐 v1.3 |
| v1.4 | 2026-05-30 | 开头再加一段「⭐ 推荐字体经验」：代码 / 终端可选 **Maple Mono NF CN** 替代 JetBrains Mono（圆角字形 / 70+ 连字 / 内置 Nerd Font 图标 + 中文圆角字形 / cursive 斜体），含 GitHub API 动态拿 latest 资产的安装脚本、三场景用法（Cursor / WezTerm / GNOME monospace）、一键回退；§3.5 Cursor JSON 示例改成 Linux 推荐的**无引号**写法（修正原写法把 CSS 通用关键字 `monospace` 加引号导致回退链断裂的隐患），加 `terminal.integrated.fontFamily` 必须显式设的提醒；§4 安装表加 Maple Mono NF CN |
