# Ubuntu 截图工具方案 (Flameshot + 剪贴板传图给 Claude)

> **版本**: v1.0
> **更新时间**: 2026-06-13
> **环境**: Ubuntu 26.04 + GNOME 50.1 (Wayland) + NVIDIA RTX 3060 Ti
> **结果**: Flameshot 区域截图+标注正常工作 (Wayland 走 xdg-desktop-portal),快捷键微信/QQ 手感 (Ctrl+Alt+A),截图可一键传给终端里的 Claude Code

记录截图工具选型、Flameshot 安装与 GNOME Wayland 下的配置、快捷键绑定,以及一个实用工作流 —— **把剪贴板里的截图存成文件传给 Claude Code (终端 AI 看不了剪贴板,只能读文件)**。

---

## 1. 当前方案总览

| 项 | 值 |
|---|---|
| **主力截图工具** | Flameshot v13.3.0 (Qt 6.9.2) |
| **触发快捷键** | `Ctrl+Alt+A` (微信/QQ 手感) → `flameshot gui` 区域截图+标注 |
| **系统兜底** | `PrtSc` GNOME 内置截图 UI / `Shift+PrtSc` 全屏 / `Alt+PrtSc` 当前窗口 |
| **Wayland 截图后端** | xdg-desktop-portal + -gnome + -gtk (系统已自带) |
| **传图给 Claude** | `wl-clipboard` 把剪贴板图片 dump 成文件 → 告诉 Claude 路径 |

---

## 2. 工具选型 (GNOME Wayland 视角)

截图工具"好不好用"在 Wayland 下高度取决于**是否支持 Wayland** —— 很多 X11 老牌工具 (Shutter、旧版 Flameshot) 在 Wayland 下截不了图。

| 工具 | Wayland | 标注 | 推荐度 | 一句话 |
|---|---|---|---|---|
| **GNOME 内置截图** | ✅ 原生 | 基础 | ⭐⭐⭐⭐ | 按 PrtSc 就有,零安装最稳,但无标注 |
| **Flameshot** ← 本方案 | ✅ (近版本修好) | ⭐ 强 | ⭐⭐⭐⭐⭐ | 标注最强:箭头/文字/马赛克/序号/模糊 |
| **Ksnip** | ✅ 好 | ⭐ 强 | ⭐⭐⭐⭐ | 类 Flameshot,Qt 系,编辑器更全 |
| **Satty** | ✅ 原生 | 中 | ⭐⭐⭐⭐ | Wayland 原生,配 grim 用,极快 |
| **grim + slurp** | ✅ 原生 | ✗ | ⭐⭐⭐ | 纯 CLI,脚本化截图用 |
| **Spectacle** | ✅ 好 | 中 | ⭐⭐⭐ | KDE 自带,GNOME 上也能装 |
| ~~Shutter~~ | ❌ | 强 | — | X11 老牌,Wayland 下基本废,别装 |

**为什么选 Flameshot**:截完图直接在屏幕上画箭头、加文字、马赛克、序号标记、模糊,一站式完成,适合写文档/报 bug/做教程。本机实测标注功能全部正常 (见 §6 截图传图实测)。

---

## 3. 安装 Flameshot

```bash
sudo apt install -y flameshot
flameshot --version    # 验证: Flameshot v13.3.0, Compiled with Qt 6.9.2
```

### 3.1 Wayland 截图依赖 (系统已自带,确认即可)

Flameshot 在 Wayland 下不直接抓屏,而是走 **xdg-desktop-portal** 的 Screenshot 接口。确认这套在跑:

```bash
pgrep -af 'xdg-desktop-portal'   # 应看到 xdg-desktop-portal / -gnome / -gtk 三个进程
dpkg -l | grep xdg-desktop-portal
```

Ubuntu 26.04 GNOME 默认就装好了 `xdg-desktop-portal-gnome`,提供 Screenshot 接口。**首次按快捷键截图时,GNOME 会弹一个"允许截屏"授权框,点允许即可,之后不再问。**

---

## 4. 配置快捷键

GNOME 默认 `PrtSc` 系列已占用 (内置截图)。本方案把 Flameshot 绑到 **`Ctrl+Alt+A`** (微信/QQ 截图的肌肉记忆),`PrtSc` 系列原样保留作兜底。

### 4.1 创建自定义快捷键 (gsettings)

```bash
KEYPATH="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/flameshot/"

# 注册到自定义快捷键列表
gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "['$KEYPATH']"

# 设置三要素:名称 / 命令 / 按键
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$KEYPATH name 'Flameshot'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$KEYPATH command 'flameshot gui'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$KEYPATH binding '<Control><Alt>a'
```

> 已有其他自定义快捷键时,`custom-keybindings` 列表要**追加**而不是覆盖 —— 先 `gsettings get` 看现有值,把新 KEYPATH 加进数组。

### 4.2 验证

```bash
KEYPATH="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/flameshot/"
gsettings get org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$KEYPATH binding
# 期望: '<Control><Alt>a'
```

### 4.3 最终快捷键全景

| 按键 | 功能 |
|---|---|
| **`Ctrl+Alt+A`** | **Flameshot 区域截图 + 标注** (微信/QQ 手感) ⭐ |
| `PrtSc` | GNOME 内置截图 UI |
| `Shift+PrtSc` | GNOME 全屏截图 |
| `Alt+PrtSc` | GNOME 当前窗口截图 |

### 4.4 GUI 改法

`设置 → 键盘 → 键盘快捷键 → 查看及自定义快捷键 → 自定义快捷键`,也能图形化加/改。

> gsettings 改完后,GNOME 快捷键守护进程偶尔需要刷新。若按 `Ctrl+Alt+A` 没反应,**注销重登一次**必定生效。

### 4.5 Flameshot 标注工具栏操作 (截图框选后)

| 操作 | 键 |
|---|---|
| 复制到剪贴板 | `Ctrl+C` |
| 保存到文件 | `Ctrl+S` |
| 撤销标注 | `Ctrl+Z` |
| 退出截图 | `Esc` |
| 箭头 / 方框 / 文字 / 马赛克 | 工具栏点选,右键调色板 |

### 4.6 (可选) 开机常驻托盘

```bash
cp /usr/share/applications/org.flameshot.Flameshot.desktop ~/.config/autostart/
```

常驻后截图更快,且能在托盘配置默认保存路径等。也可 `flameshot config` 开图形配置面板。

---

## 5. 把截图传给 Claude Code (终端 AI 看图工作流)

**核心限制**:Claude Code 跑在终端里,**读不了系统剪贴板,只能读文件**。所以传图给 Claude = 把截图变成一个文件,再告诉 Claude 路径,它用 Read 工具读图 (Claude 能识别图片内容)。

三条路,从最方便到最省事:

### 5.1 方式 A:Flameshot 直接存文件 (最简单)

截图标注完,按 **`Ctrl+S`** (而非 Ctrl+C) → 弹保存框 → 存到 `~/Pictures/` 等 → 告诉 Claude:

> 看一下 `~/Pictures/Screenshot_xxx.png`

### 5.2 方式 B:剪贴板 → 文件 (习惯按 Ctrl+C 的话)

装 `wl-clipboard` (Wayland 剪贴板工具),把剪贴板图片 dump 成文件:

```bash
sudo apt install -y wl-clipboard

# 确认剪贴板里是图片
wl-paste --list-types     # 应看到 image/png

# dump 成文件
wl-paste --type image/png > ~/Pictures/clip_latest.png
```

然后告诉 Claude 这个路径即可。

### 5.3 一键命令 `clip` (推荐,已写入 ~/.bashrc)

把下面这段加进 `~/.bashrc`,以后截图 `Ctrl+C` 后,终端跑一个 `clip` 就把图存好并打印路径 (路径也复制回剪贴板,方便粘给 Claude):

```bash
# 把剪贴板里的图片存成文件并打印路径（截图 Ctrl+C 后用）
clip() {
  local dir=~/Pictures/clipboard
  mkdir -p "$dir"
  local out="$dir/clip_$(date +%H%M%S).png"
  if wl-paste --type image/png > "$out" 2>/dev/null && [ -s "$out" ]; then
    echo "$out"
    command -v wl-copy >/dev/null && printf '%s' "$out" | wl-copy 2>/dev/null  # 路径也放剪贴板
  else
    rm -f "$out"
    echo "剪贴板里没有图片"
  fi
}
```

**完整工作流**:

1. `Ctrl+Alt+A` 截图 → 标注 → `Ctrl+C` 复制
2. 终端跑 `clip` → 打印出 `/home/maxzzsny/Pictures/clipboard/clip_212100.png`
3. 把路径发给 Claude → Claude 读图

---

## 6. 实测验证 (本次安装记录)

2026-06-13 安装后实测,**剪贴板传图工作流全程跑通**:

1. `Ctrl+Alt+A` 触发 Flameshot,框选一段终端区域 (certbot/nginx 证书命令)
2. 用 Flameshot 标注:红色序号 ①②③④、红框、红色箭头、马赛克涂抹敏感信息 (域名/邮箱)、红色填充块
3. `Ctrl+C` 复制到剪贴板
4. `wl-paste --type image/png` 确认剪贴板类型 = `image/png` ✓
5. dump 成文件:`PNG image data, 680 x 335, 8-bit/color RGB` ✓
6. Claude 用 Read 工具读取该 PNG,**成功识别出截图内容和所有标注** ✓

→ 证明 Flameshot 标注 + Wayland portal 截图 + 剪贴板传图给 Claude 三段链路全部正常。

---

## 7. 故障排查

| 症状 | 原因 / 修复 |
|---|---|
| 按 `Ctrl+Alt+A` 没反应 | gsettings 守护进程没刷新 → **注销重登一次**;或确认 binding 是 `'<Control><Alt>a'` |
| 首次截图弹"允许截屏"框 | 正常,xdg-desktop-portal 的权限确认,点允许,之后不再问 |
| Flameshot 截图全黑 / 截不到 | xdg-desktop-portal-gnome 没跑 → `pgrep -af xdg-desktop-portal` 确认;缺则 `sudo apt install xdg-desktop-portal-gnome` |
| `clip` 提示"剪贴板里没有图片" | 截图后没按 Ctrl+C,或复制的是文字而非图;`wl-paste --list-types` 看实际类型 |
| Claude 说读不到图 | 确认路径是**绝对路径**且文件存在 (`ls -lh <路径>`);Claude 只能读本地文件系统里的文件 |
| 标注的文字是方框/乱码 | Flameshot 字体缺失,装中文字体 (见 `../fonts/README.md`) |
| Wayland 下 Flameshot 多屏定位错乱 | 已知 Wayland 多屏限制,可改用 GNOME 内置 (PrtSc) 或 grim+slurp 兜底 |

---

## 8. 一键还原 (卸 Flameshot)

```bash
# 1. 删自定义快捷键
gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "[]"

# 2. (可选) 删 ~/.bashrc 里的 clip 函数 — 手动编辑删掉那段

# 3. 删开机自启 (若配过)
rm -f ~/.config/autostart/org.flameshot.Flameshot.desktop

# 4. 卸 Flameshot
sudo apt remove -y flameshot

# 5. wl-clipboard 可保留 (通用工具,无害);要卸:
# sudo apt remove -y wl-clipboard
```

> GNOME 内置截图 (PrtSc 系列) 始终在,卸了 Flameshot 也能截图。

---

## 9. 变更记录

| 版本 | 日期 | 变更 |
|---|---|---|
| v1.0 | 2026-06-13 | 初版:Flameshot 安装 + GNOME Wayland 配置 (xdg-desktop-portal 依赖)、`Ctrl+Alt+A` 微信手感快捷键、`clip` 剪贴板传图给 Claude 工作流、实测验证记录、故障排查、还原方法 |
