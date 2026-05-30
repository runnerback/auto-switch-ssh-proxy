# Ubuntu 输入法方案 (fcitx5 + Rime)

> **版本**: v1.2
> **更新时间**: 2026-05-30
> **环境**: Ubuntu 26.04 + GNOME 50.1 (Wayland)
> **结果**: 中英混输流畅、候选窗跟随光标、Rime 词库继承自原 ibus-rime

记录从 Ubuntu 自带的 **iBus + Rime** 迁移到 **fcitx5 + Rime + 中英混输** 的完整方案,以及踩过的所有坑。

---

## ⭐ 推荐方案 (2026-05-30 新增) — Rime 用 **雾凇拼音 (rime-ice)** 替代 luna_pinyin_simp + easy_en

§3 / §4 里描述的是经典方案 (`luna_pinyin_simp` + 手工挂 `easy_en` + 写 `custom.yaml`),可以工作但配置成本高、词库偏老。**雾凇拼音 (`iDvel/rime-ice`)** 是 Rime 社区近年最火的"开箱即用"配置包,**作为 Rime 方案的第一选择**:

| 特性 | 经典方案 luna_pinyin_simp + easy_en (§4) | **雾凇拼音 rime-ice** |
|---|---|---|
| 中英混输 | 手工挂 easy_en 词典 + 写 patch | **内置**,开箱即用 |
| **Emoji 输入** | ✗ 没有 | ✓ 输 `weixiao` `xiaoku` `daxiao` `aixin` `huo` 等直接出 emoji 候选 |
| 智能识别 (邮箱 / URL / 大写) | 手写 recognizer patterns | **内置**几十条 |
| 词库时效 | luna_pinyin 多年基本停更,新词偏少 | 基于现代语料,新词 / 流行语 / 网络用语齐全 |
| 多方案支持 | 单方案 | 全拼 / 双拼 (小鹤 / 自然码 / 微软等 7 套) / 九键 / 五笔 / 三拼,一份配置全在 |
| 部署成本 | 装词典 + 改 3-4 个 custom.yaml | **一行 plum 命令搞定** |
| 维护状态 | luna_pinyin 上游基本停更 | iDvel/rime-ice 活跃维护 (周级别更新) |

### 安装

用 plum (Rime 官方包管理器) 一行装好,字典 / 方案 / Emoji / 脚本全套自动到位:

```bash
mkdir -p ~/.local/share/fcitx5/rime
cd /tmp
rm -rf plum
git clone --depth 1 https://github.com/rime/plum.git
cd plum
rime_dir="$HOME/.local/share/fcitx5/rime" bash rime-install iDvel/rime-ice:others/recipes/full
```

> `:others/recipes/full` 装**完整方案** (全拼 + 所有双拼 + 九键 + 五笔 + Emoji 等约 70 个文件);若只要全拼,改 `iDvel/rime-ice:others/recipes/full-pinyin`,体积更小。

装完后:

1. 打开 fcitx5 配置工具 (`fcitx5-configtool`) 确认 Rime 已加入输入法
2. `Ctrl+Space` 切到 Rime,按 **F4** 调出方案菜单 → 选 **「雾凇拼音」**
3. 试输入: `weixiao` → 候选出 😊;`Python` → 直接英文上屏 (大写规则);`foo@bar.com` → 邮箱原样;`ni hao shi jie` → "你好世界"

### Emoji 触发词速查 (常用)

雾凇 emoji 是通过给拼音"加 emoji 候选"实现,无需切模式:

| 输入 | Emoji | 输入 | Emoji |
|---|---|---|---|
| `weixiao` | 😊 微笑 | `aixin` | ❤️ 爱心 |
| `xiaoku` | 😂 笑哭 | `huo` | 🔥 火 |
| `daxiao` | 🤣 大笑 | `bizan` / `zan` | 👍 |
| `daku` | 😭 大哭 | `ku` | 😎 酷 |
| `xinsui` | 💔 心碎 | `tianshi` | 😇 天使 |
| `kulian` | 😣 苦脸 | `bishi` | 😒 鄙视 |

完整词库在装完后的 `~/.local/share/fcitx5/rime/cn_dicts/emoji.txt`。

### 跟原 §3 / §4 的关系

- **§3.1 ~ §3.7** (装 fcitx5、卸 ibus、设环境变量、输入法组、自启) **仍然必做** —— 雾凇拼音只替换 §3.9 词库迁移 + §4 Rime 自定义配置那两部分。
- **§3.8 装 kimpanel GNOME 扩展** 仍然必做 —— 它跟选哪个 Rime 方案无关,是 **GNOME Wayland 下候选窗跟随光标的系统级方案**(替代 §8 的 Cursor XWayland 兜底)。
- **§4 的 default.custom.yaml / luna_pinyin_simp.custom.yaml** 用雾凇后**可以不写** —— 雾凇内置都有;若已写好仍兼容 (Rime patch 叠加),不冲突。
- **从 luna_pinyin_simp 升级到雾凇**:不用卸原方案,雾凇是独立 schema (`rime_ice`),可在 F4 菜单切换;但用户词频 (`luna_pinyin.userdb/`) **不会自动迁移**到雾凇 (词库格式不同),想保留输入习惯只能手写或重新积累。

### 取舍

- **新机器 / 第一次装 Rime** → 直接上雾凇,跳过 §4 整章。
- **已有大量 luna_pinyin 深度自定义** (上百自定义短语 / 复杂 patch) → 看你愿不愿迁移;双方案并存也行,F4 切换即可。
- **公司机器 / 写代码为主** → 雾凇内置的智能识别 (`Python` 走英文、URL/邮箱直通、Shift 切英文等) 是大杀器,基本零配置就有 IDE 友好的体验。

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
| 候选窗在屏幕中央 | kimpanel 扩展没启用 → `gnome-extensions info kimpanel@kde.org` 看 State,应为 ACTIVE。若**未装** kimpanel 且仅 Cursor/Chrome/VS Code 等 Chromium 应用居中,见 §8 |
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

## 8. Cursor / Chromium 候选框居中（没装 kimpanel 时的备用方案）

> **适用场景**: 本仓库 §3.8 推荐装 kimpanel 解决候选窗跟随,那是**系统级最优解**(GTK / Qt / Electron 都覆盖)。若由于某些原因不装 kimpanel(GNOME 版本不兼容、扩展无法安装、不想用 GNOME 扩展……),又只有 Cursor / VS Code / Chrome 这类 Chromium 应用候选框居中,用这个备用方案兜底,**仅修 Chromium 系**,其他应用维持原样。

### 8.1 症状

Cursor / VS Code / Chrome 等 Chromium / Electron 应用输入中文,候选词框固定屏幕中央,不跟随编辑光标。同机 Nautilus / Ptyxis / gedit 等 GTK 应用候选窗跟随正常 —— 即 fcitx5 没毛病,**仅 Chromium 家族异常**。

`fcitx5-diagnose` 里能看到 GTK 应用进入 `Group [wayland:]` 的 InputContext 列表(`frontend:dbus`),但**找不到 Cursor**。

### 8.2 根因

GNOME 的 mutter 合成器**不支持** wlroots 风格的 `zwp_input_method_v2` 协议(只有 sway / Hyprland 实现)。Chromium 在 Wayland 下用 `--enable-wayland-ime` 尝试走这条路时握不上手,fallback 到完全不上报光标位置 —— fcitx5 只能把候选框放屏幕中央。mutter 的 `zwp_text_input_v3` → ibus 转发链路对外部 Chromium 客户端也实际不生效(gnome-shell 自己作为 ibus client 直连 fcitx5 是 OK 的,所以 gnome-shell 搜索栏输入中文跟随正常,但外部 wayland 客户端的 text-input 请求转发会丢)。

kimpanel 之所以能绕开这堆问题,是因为它把候选词数据从 fcitx5 通过 D-Bus 转给 gnome-shell,由 gnome-shell 自己绘制 —— 完全绕过 wayland text-input 协议,自然也就没有 mutter 不支持的问题。

### 8.3 修复(XWayland 兜底)

让 Cursor 跑在 **XWayland** 下,由 fcitx5 的 X11 frontend 接管。fcitx5 X11 frontend 实现得不像传统 XIM 那么糟 —— 候选框位置由应用通过 X 协议上报,Chromium XWayland 上报正确。

**操作**: 覆盖 system 的 `.desktop`,给 `Exec=` 加 `--ozone-platform=x11`。用户目录优先级高于 `/usr/share/applications`,apt 升级 Cursor 不会冲掉这份。

```bash
cp /usr/share/applications/cursor.desktop ~/.local/share/applications/cursor.desktop
sed -i 's|Exec=/usr/share/cursor/cursor|Exec=/usr/share/cursor/cursor --ozone-platform=x11|g' \
  ~/.local/share/applications/cursor.desktop
update-desktop-database ~/.local/share/applications
```

VS Code / Chrome 同理,把对应 `.desktop` 文件搬到 `~/.local/share/applications/` 改 `Exec=` 即可。

**重启 Cursor**(必须**完全退出进程**,关窗口不够;建议在 GNOME 自带终端里操作,避免把 Cursor 内嵌终端一起干掉):

```bash
pkill -f /usr/share/cursor/cursor
sleep 2
gtk-launch cursor
```

**验证**:

```bash
xlsclients | grep -i cursor       # 应能看到 cursor(之前 wayland-native 时看不到 → 现已走 XWayland)
ps -eo cmd | grep cursor | grep -- --ozone-platform=x11
```

试输入中文,候选框应贴着光标了。

### 8.4 已踩过的坑(别再试)

| 试过的方案 | 为什么没用 |
|---|---|
| `--enable-wayland-ime --wayland-text-input-version=3` | 在 sway / Hyprland 上有效;GNOME mutter 不实现 `input-method-v2`,反而让 Cursor 完全不报光标 |
| `--gtk-version=4` | Chromium 里这个 flag 只控制窗口装饰,不影响 IME 路径 |
| `~/.config/cursor-flags.conf` | Cursor 的 `.desktop` 直接调 Electron binary,不经过会读 flags.conf 的 wrapper 脚本(VS Code 同样问题) |
| 只写 `~/.config/environment.d/im-fcitx5.conf` 不卸 ibus | GNOME 自启的 ibus user service (`org.freedesktop.IBus.session.GNOME.service`) 会覆盖环境变量。要么按 §3.2 彻底卸 ibus,要么至少 `systemctl --user disable --now org.freedesktop.IBus.session.GNOME.service` |

### 8.5 副作用

- XWayland 下 HiDPI 缩放、触屏手势比 wayland-native 略差。
- 仅 Chromium / Electron 应用需要这条;GTK4 应用(Nautilus 等)继续用 wayland-native。

### 8.6 与 kimpanel 方案的取舍

| 维度 | kimpanel (§3.8) | XWayland (本节) |
|---|---|---|
| 覆盖应用 | 全部(GTK / Qt / Electron / Java) | 仅 Chromium / Electron |
| 候选窗绘制 | gnome-shell 内嵌绘制,样式跟系统主题 | 各应用自绘 / fcitx5 X11 frontend |
| 部署成本 | 装 GNOME 扩展,要跟 gnome-shell 版本 | 改一个 `.desktop` 文件 |
| 副作用 | 几乎无 | Chromium 退出 wayland-native,HiDPI 略差 |
| 推荐度 | ★★★★★ 首选 | ★★★ 兜底 |

新机器部署优先走 kimpanel;只有装不上 kimpanel 时才退到 XWayland。

---

## 9. 一键还原回 iBus + Rime

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

## 10. 变更记录

| 版本 | 日期 | 变更 |
|---|---|---|
| v1.0 | 2026-05-25 | 初版:记录从 iBus → fcitx5 + Rime + easy_en + kimpanel 的完整方案、踩过的所有坑、还原方法 |
| v1.1 | 2026-05-30 | 加 §8:Cursor / Chromium 候选框居中(没装 kimpanel 时的备用方案,XWayland 兜底);§7 故障排查表加索引指向 §8 |
| v1.2 | 2026-05-30 | 开头加「⭐ 推荐方案」:Rime 方案的**第一选择**改为 **雾凇拼音 (rime-ice)**,替代 §4 的 luna_pinyin_simp + easy_en + 手写 custom.yaml 路线 —— 内置中英混输 / Emoji 输入 / 智能识别 / 多双拼方案,一行 plum 命令装好,词库活跃维护;含安装命令、Emoji 触发词速查、跟原 §3 / §4 的兼容关系说明 |
