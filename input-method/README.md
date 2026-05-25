# Ubuntu 输入法方案 (fcitx5 + Rime)

> **版本**: v1.0
> **更新时间**: 2026-05-25
> **环境**: Ubuntu 26.04 + GNOME 50.1 (Wayland)
> **结果**: 中英混输流畅、候选窗跟随光标、Rime 词库继承自原 ibus-rime

记录从 Ubuntu 自带的 **iBus + Rime** 迁移到 **fcitx5 + Rime + 中英混输** 的完整方案,以及踩过的所有坑。

---

## 1. 当前架构

```
应用 (GTK / Qt / Electron)
   │
   │ GTK_IM_MODULE / QT_IM_MODULE / XMODIFIERS = fcitx
   │ (~/.config/environment.d/im-fcitx5.conf)
   ▼
fcitx5 (用户进程, 开机自启)
   │
   ├── 输入法组: keyboard-us | rime
   │   (Ctrl+Space 切换)
   │
   ├── Rime 引擎 → luna_pinyin_simp 方案 + easy_en 英文词典
   │   (词库 / 配置在 ~/.local/share/fcitx5/rime/)
   │
   └── 候选窗输出 → kimpanel D-Bus 协议
                      │
                      ▼
              kimpanel GNOME 扩展 (gnome-shell 内绘制候选窗,定位准确)
```

**核心设计**:
- **fcitx5 当 IME 引擎**(取代 iBus,UI 更好/活跃维护)
- **Rime 当输入法方案**(开源、强大、可定制)
- **easy_en 当英文词典**(打拼音时英文词混在候选里,无需切模式)
- **kimpanel GNOME 扩展画候选窗**(GNOME Wayland 下唯一靠谱的候选窗定位方式)

---

## 2. 为什么这样选

### 2.1 为什么换掉 iBus → fcitx5

iBus 是 Ubuntu/GNOME 官方默认,本身没问题。换 fcitx5 的好处:
- 候选窗响应更跟手、延迟低
- 支持云拼音/联想 (`fcitx5-module-cloudpinyin`)
- 主题皮肤丰富 (`fcitx5-material-color` 等)
- 社区主流、维护活跃
- 配置 GUI (`fcitx5-configtool`) 比 ibus 全面

### 2.2 为什么挂 easy_en 词典

Rime 默认把所有字母当拼音解释,打 `github`、`python` 出乱七八糟候选。挂上 easy_en:
- 打字母时,中英文候选**并列出现**
- 不用每次切 Shift 进英文模式
- 词频排序,常用单词排前

### 2.3 为什么用 kimpanel 扩展(不是 fcitx5 自绘)

GNOME Wayland 不给 fcitx5 「窗口定位」协议(既不支持 `layer-shell` 也不给 `input-method-v2`)。fcitx5 自己画候选窗,**只能丢屏幕中央**。

kimpanel 协议把候选词数据交给 gnome-shell,由 gnome-shell 内嵌绘制 —— gnome-shell 知道光标在哪,候选框就跟在光标旁。

---

## 3. 部署详解

### 3.1 装包 (apt)

```bash
sudo apt install -y \
  fcitx5 \
  fcitx5-rime \
  fcitx5-config-qt \
  fcitx5-frontend-all \
  fcitx5-chinese-addons \
  fcitx5-module-cloudpinyin \
  fcitx5-material-color
```

`fcitx5-frontend-all` 是元包,会装齐 gtk3/gtk4/qt5/qt6 的 IM modules,**必须**(没它,某类应用接不到 fcitx5)。

### 3.2 卸载 iBus (关键步骤)

GNOME 内置 iBus 集成,会在运行时硬设 `XMODIFIERS=@im=ibus` 等变量,**压过 environment.d**。彻底解法:卸掉 iBus 二进制 —— GNOME 找不到就不强行接管了。

```bash
sudo apt remove -y ibus ibus-libpinyin ibus-rime ibus-table ibus-table-wubi
sudo apt autoremove -y
```

⚠️ `ibus` 对 `gnome-shell` / `ubuntu-desktop` 只是 **Recommends**(软依赖),卸载不影响桌面。先 `--dry-run` 看一眼连带删什么再动手。

> 卸完仍可能残留 `ibus-gtk` / `ibus-gtk3` —— 那是 GTK 的 IBus IM module,无害(我们设 `GTK_IM_MODULE=fcitx`,根本不会加载它),嫌占空间可一并卸。

### 3.3 切换 im-config 到 fcitx5

```bash
im-config -n fcitx5
```

这把 `~/.xinputrc` 改成 `run_im fcitx5`。Ubuntu Wayland 下 im-config 的 profile.d 脚本其实是空操作(逻辑全注释),**主要作用是规避 Ubuntu 的 IM 切换工具检测**。

### 3.4 配置环境变量

写 `~/.config/environment.d/im-fcitx5.conf`:

```ini
GTK_IM_MODULE=fcitx
QT_IM_MODULE=fcitx
QT_IM_MODULES=fcitx
XMODIFIERS=@im=fcitx
SDL_IM_MODULE=fcitx
GLFW_IM_MODULE=ibus
```

- `QT_IM_MODULES`(复数)是 Qt 6.8+ 用的,**优先级高于 QT_IM_MODULE**(单数)。不设的话 Qt 应用会去找 `wayland;ibus`,绕过 fcitx5。
- `GLFW_IM_MODULE=ibus` 是 GLFW 的兼容历史包袱 —— GLFW 只认字符串 `ibus`,但 fcitx5 提供兼容,所以照写。

systemd user manager 在登录时读这个文件,把变量注入用户会话。需**重启系统**一次让它生效。

### 3.5 GNOME 输入源去掉 IBus 项

```bash
gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'us')]"
```

只留 US 键盘,避免 GNOME 试图启动 ibus。

### 3.6 fcitx5 输入法组

`~/.config/fcitx5/profile`:

```ini
[Groups/0]
Name=Default
Default Layout=us
DefaultIM=rime

[Groups/0/Items/0]
Name=keyboard-us
Layout=

[Groups/0/Items/1]
Name=rime
Layout=

[GroupOrder]
0=Default
```

`Ctrl+Space` 在 `keyboard-us`(纯英文键盘) 和 `rime`(中文) 之间切换。

> 直接手写 profile,fcitx5 可能在启动时把 `rime` 项删掉(addon 加载时序问题)。可用 gdbus 强加:
> ```bash
> gdbus call --session --dest org.fcitx.Fcitx5 --object-path /controller \
>   --method org.fcitx.Fcitx.Controller1.SetInputMethodGroupInfo \
>   "Default" "us" "[('keyboard-us', ''), ('rime', '')]"
> ```

### 3.7 fcitx5 自启动

```bash
cp /usr/share/applications/org.fcitx.Fcitx5.desktop ~/.config/autostart/
```

### 3.8 装 kimpanel GNOME 扩展

```bash
# 下载 GNOME 50 版本
curl -fsSL "https://extensions.gnome.org/download-extension/kimpanel@kde.org.shell-extension.zip?shell_version=50" \
  -o /tmp/kimpanel.zip
gnome-extensions install --force /tmp/kimpanel.zip

# 加入开机启用列表(运行中的 gnome-shell 不能热加载,要重登)
gsettings set org.gnome.shell enabled-extensions \
  "$(gsettings get org.gnome.shell enabled-extensions | python3 -c "
import ast,sys
cur=ast.literal_eval(sys.stdin.read())
if 'kimpanel@kde.org' not in cur: cur.append('kimpanel@kde.org')
print(cur)")"

# 候选窗字体(可选,用系统字体)
SD=~/.local/share/gnome-shell/extensions/kimpanel@kde.org/schemas/
gsettings --schemadir "$SD" set org.gnome.shell.extensions.kimpanel font 'Sarasa UI SC 13'
```

### 3.9 迁移 Rime 词库

从原 ibus-rime 路径搬到 fcitx5-rime 路径:

```bash
mkdir -p ~/.local/share/fcitx5/rime
cp -r ~/.config/ibus/rime/installation.yaml \
      ~/.config/ibus/rime/user.yaml \
      ~/.config/ibus/rime/luna_pinyin.userdb \
      ~/.local/share/fcitx5/rime/
```

`luna_pinyin.userdb` 是学习记录(用户词频),搬过来后输入习惯延续。

---

## 4. Rime 自定义配置

### 4.1 default.custom.yaml — 全局规则

`~/.local/share/fcitx5/rime/default.custom.yaml`:

```yaml
patch:
  # 1) Shift = 中/英切换
  "ascii_composer/switch_key":
    Caps_Lock: commit_code      # Caps Lock 上屏原文并切英文
    Shift_L: commit_text         # 左 Shift 上屏候选并切英文
    Shift_R: commit_text         # 右 Shift 同上
    Control_L: noop
    Control_R: noop
    Eisu_toggle: clear

  # 2) 大写字母开头 → 当作英文原样输入
  "recognizer/patterns/uppercase": "[A-Z][-_+.'0-9A-Za-z]*$"

  # 3) 邮箱直接走英文
  "recognizer/patterns/email": "^[A-Za-z][-_.0-9A-Za-z]*@.*$"

  # 4) URL 直接走英文
  "recognizer/patterns/url": "^(www[.]|https?:|ftp[.:]|mailto:|file:).*$|^[a-z]+[.].+$"
```

### 4.2 luna_pinyin_simp.custom.yaml — 挂 easy_en 词典

`~/.local/share/fcitx5/rime/luna_pinyin_simp.custom.yaml`:

```yaml
# 把 easy_en 字典挂到 luna_pinyin_simp，实现中英混输
patch:
  __include: easy_en:/patch
```

`__include` 直接把 `easy_en.yaml` 里的 `patch` 块整段合并 —— 自动添加 translator、依赖、字母表。

### 4.3 easy_en 词典安装

从 GitHub `BlindingDark/rime-easy-en` 下载:

```bash
cd ~/.local/share/fcitx5/rime
for f in easy_en.schema.yaml easy_en.dict.yaml easy_en.yaml; do
  curl -fsSL "https://raw.githubusercontent.com/BlindingDark/rime-easy-en/master/$f" -o "$f"
done
```

`easy_en.dict.yaml` 约 14MB,涵盖几万英文词,词频排序。

### 4.4 重新部署 Rime

任一方式:
```bash
pkill -x fcitx5 && setsid fcitx5 -d   # 重启 fcitx5,部署最干净
# 或托盘图标 → 右键 → "Deploy" / 重新部署
```

---

## 5. 日常使用

### 5.1 常用快捷键

| 快捷键 | 作用 |
|---|---|
| `Ctrl+Space` | 在 keyboard-us / rime 间切换 |
| `Shift` | Rime 内部切中英模式 |
| `Caps Lock` | 同 Shift |
| `Ctrl+\`` (反引号) | Rime 方案选单(切 luna_pinyin / luna_pinyin_simp / luna_pinyin_fluency 等) |
| `Esc` | 取消当前编码 |
| `Ctrl+;` | 半角/全角切换 |
| `F4` (默认) | 配置工具入口 |
| `Ctrl+,` (in Rime menu) | 打开 fcitx5 设置 |

### 5.2 中英混输示例

| 你打 | 候选 |
|---|---|
| `github` | github (英文词典) + 各种"格"开头拼音候选 |
| `Python` | Python (大写规则直接走英文) |
| `ni` | 你、妮、泥 (中文照常) |
| `foo@bar.com` | foo@bar.com (邮箱规则) |
| `https://example.com` | URL 原样 |
| `wo zai xie daima` | 我在写代码 (整句拼音) |

### 5.3 切换 Rime 方案

`Ctrl+\`` 弹出方案菜单,可选:
- `luna_pinyin` — 朙月拼音(繁体倾向)
- `luna_pinyin_simp` — 朙月拼音简体(默认)
- `luna_pinyin_fluency` — 朙月拼音(语句优先)

---

## 6. 关键文件清单

| 路径 | 作用 |
|---|---|
| `~/.xinputrc` | im-config 选定的 IM (fcitx5) |
| `~/.config/environment.d/im-fcitx5.conf` | IM 环境变量 |
| `~/.config/autostart/org.fcitx.Fcitx5.desktop` | fcitx5 开机自启 |
| `~/.config/fcitx5/profile` | 输入法组定义 |
| `~/.local/share/fcitx5/rime/default.custom.yaml` | Rime 全局规则 (Shift/recognizer) |
| `~/.local/share/fcitx5/rime/luna_pinyin_simp.custom.yaml` | 给方案挂 easy_en |
| `~/.local/share/fcitx5/rime/easy_en.{schema,dict,yaml}.yaml` | easy_en 英文词典 |
| `~/.local/share/fcitx5/rime/luna_pinyin.userdb/` | 用户学习记录 (词频) |
| `~/.local/share/fcitx5/rime/build/` | Rime 部署产物 (会自动重建,不用手动管) |
| `~/.local/share/gnome-shell/extensions/kimpanel@kde.org/` | kimpanel 扩展 |

---

## 7. 故障排查

| 症状 | 原因 / 修复 |
|---|---|
| 切到 Rime 但打字没反应 | fcitx5 没起 → `pgrep -x fcitx5`;没跑则 `setsid fcitx5 -d` |
| 环境变量还是 ibus | iBus 没卸干净 (见 §3.2),或环境变量被 GNOME 覆盖。重启系统 |
| 候选窗在屏幕中央 | kimpanel 扩展没启用 → `gnome-extensions info kimpanel@kde.org` 看 State,应为 ACTIVE |
| 候选窗字体不对 | 改 kimpanel 的 `font` 设置,不是 fcitx5 (见 §3.8) |
| 部分应用 (如 IDEA / Electron) 接不到输入 | 重启那个应用;Electron 应用要彻底退出后台进程 |
| Rime 改了 custom.yaml 没生效 | 重新部署 → 重启 fcitx5,或托盘菜单 Deploy |
| 打英文词没出英文候选 | easy_en 没部署成功 → 看 `~/.local/share/fcitx5/rime/build/easy_en.table.bin` 在不在;不在则重启 fcitx5 |
| 候选窗弹出来后挡视线 | 鼠标拖动它?不能拖。或改成竖排:`gsettings --schemadir ... set ... vertical true` |
| 中文输入很慢 | 看 `journalctl --user -u fcitx5` 有没有错误;Rime 词库太大可能首次部署慢 |

### 7.1 GNOME Wayland 下 fcitx5 不工作的「调试金句」

按这个顺序排查:

```bash
# 1. ibus 真的没了吗
which ibus ibus-daemon || echo "✓ ibus 已无"

# 2. fcitx5 在跑吗
pgrep -ax fcitx5

# 3. 环境变量对吗
echo "GTK=$GTK_IM_MODULE QT=$QT_IM_MODULE X=$XMODIFIERS"
# 期望: GTK=fcitx QT=fcitx X=@im=fcitx

# 4. fcitx5 自检
fcitx5-diagnose | grep -iE "error|warning" | head -10

# 5. kimpanel 扩展活吗
gnome-extensions info kimpanel@kde.org | grep State
```

---

## 8. 一键还原回 iBus + Rime

如果想退回原方案:

```bash
# 1. 装回 ibus
sudo apt install -y ibus ibus-rime ibus-libpinyin ibus-table-wubi

# 2. im-config 切回 ibus
im-config -n ibus

# 3. 删 fcitx5 的 IM 环境变量
rm ~/.config/environment.d/im-fcitx5.conf

# 4. 删 fcitx5 自启动
rm ~/.config/autostart/org.fcitx.Fcitx5.desktop

# 5. (可选) 卸 fcitx5
sudo apt remove -y fcitx5 fcitx5-rime fcitx5-frontend-all \
  fcitx5-chinese-addons fcitx5-config-qt fcitx5-material-color

# 6. GNOME 输入源加回 ibus-rime
gsettings set org.gnome.desktop.input-sources sources \
  "[('xkb', 'us'), ('ibus', 'rime')]"

# 7. 关 kimpanel 扩展(可保留,无害)
gnome-extensions disable kimpanel@kde.org

# 8. 把 Rime 词库搬回 ibus-rime
mkdir -p ~/.config/ibus/rime
cp -r ~/.local/share/fcitx5/rime/luna_pinyin.userdb \
      ~/.local/share/fcitx5/rime/user.yaml \
      ~/.local/share/fcitx5/rime/installation.yaml \
      ~/.config/ibus/rime/

# 9. 重启
reboot
```

---

## 9. 变更记录

| 版本 | 日期 | 变更 |
|---|---|---|
| v1.0 | 2026-05-25 | 初版:记录从 iBus → fcitx5 + Rime + easy_en + kimpanel 的完整方案、踩过的所有坑、还原方法 |
