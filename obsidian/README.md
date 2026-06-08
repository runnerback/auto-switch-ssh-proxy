# Obsidian 使用方案

> **版本**: v1.0
> **创建时间**: 2026-06-08
> **机器**: zhang-Legion-Y9000P-IRX9 (Ubuntu 26.04 + GNOME 50.1)
> **Obsidian 版本**: 1.12.x+(本文写作时官方 CLI 已 GA)

记录本机 Obsidian 的安装、关键设置、附件管理、官方 CLI、与 Claude Code 协同工作的完整方案。每项都给**直接可复制的命令** + **为什么这么选**。

---

## 1. 安装

走 Flatpak(沙盒隔离,卸载/重装干净;Snap 版本里 Obsidian 沙盒太严,挂载 vault 麻烦)。

```bash
# Flatpak 本体(若已装跳过)
sudo apt install -y flatpak gnome-software-plugin-flatpak
sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

# Obsidian
sudo flatpak install -y flathub md.obsidian.Obsidian

# 权限管理(可选,但推荐 —— Flatpak 默认沙盒,要给 Obsidian 访问 vault 外目录就靠它)
sudo flatpak install -y flathub com.github.tchx84.Flatseal
```

**Flatpak 沙盒注意**:Obsidian 默认能读写 `~/`(除隐藏目录),vault 放家目录无任何配置。如要访问 `/opt/`、外挂硬盘、`~/.config/` 等,用 Flatseal → 选 Obsidian → Filesystem 加路径。

---

## 2. 基础设置 —— 让图片走标准 markdown 语法

**目标**:图片用 `![](path/to/img.png)`,不用 Obsidian 默认的 `![[img.png]]` wiki link。

**为什么**:
- 标准 md 语法在 GitHub / VS Code / Cursor / 任何 md 渲染器都能正确显示
- vault 迁移到别的工具(比如 Logseq、纯文本编辑)无破坏
- Claude Code 读笔记时直接认得图片路径

### 设置入口

`Settings (Ctrl+,) → Files and links`

| 选项 | 设置成 | 作用 |
|---|---|---|
| **Use [[Wikilinks]]** | **关闭** | 关掉后插入/粘贴图片自动用 `![](path)` |
| **New link format** | `Relative path to file` | vault 改路径不会断链 |
| **Default location for new attachments** | `In subfolder under current folder` | 每个笔记旁边一个附件子目录 |
| **Subfolder name** | `attachments` 或 `assets` | 附件子目录的名字 |

### 效果

笔记 `notes/2026-06-08-meeting.md` 里粘贴图片后,Obsidian 自动:
1. 保存到 `notes/attachments/Pasted image 20260608123456.png`
2. 在笔记里插入 `![](attachments/Pasted%20image%2020260608123456.png)`

这种文件名又长又丑,接下来用插件解决。

---

## 3. 附件管理插件:Custom Attachment Location

内置功能只能选「都堆 vault 根」「都堆 `attachments/`」「跟笔记同级」三种。要更细的规则(按笔记名建子目录、附件文件按日期重命名、按附件类型分目录)就要插件。

**社区里两个主流**(选一个用,功能重叠):

| 插件 | 作者 | 特点 |
|---|---|---|
| **Custom Attachment Location** (推荐) | `RainCat1998` | 老牌,文档全,模板变量丰富 |
| Attachment Management | `trganda` | 新一点,UI 更现代 |

### 装法

```
Settings → Community plugins → Browse → 搜 "Custom Attachment Location" → Install → Enable
```

### 推荐配置

| 字段 | 值 | 含义 |
|---|---|---|
| **Location for new attachments** | `./attachments/${filename}` | 附件目录跟笔记同级,且按笔记名分子目录 |
| **Pasted image name** | `${date:YYYYMMDD-HHmmss}` | 时间戳命名,自然有序、不重名 |
| **Automatically rename attachment** | 开 | 拖入文件自动按上面规则改名 |
| **Handle all attachment types** | 开 | 不光图片,pdf/视频/录音都按规则放 |

### 效果对比

| 内容 | 默认 | 配置后 |
|---|---|---|
| 笔记 | `notes/meeting-2026-06-08.md` | (同) |
| 粘贴一张图保存为 | `notes/attachments/Pasted image 20260608123456.png` | `notes/attachments/meeting-2026-06-08/20260608-123456.png` |
| 插入到笔记 | `![](attachments/Pasted%20image%2020260608123456.png)` | `![](attachments/meeting-2026-06-08/20260608-123456.png)` |

**好处**:删笔记时整个附件目录一并删,vault 永远不会有孤儿附件。

---

## 4. 官方 CLI(Obsidian 1.12.4+,2026-02 GA)

> 心智模型:不是「obsidian 命令操作 vault 文件」,是「obsidian 命令**遥控运行中的 Obsidian 进程**」。所以链接自动跟着改、属性即时索引、不会把 vault 搞坏。

### 4.1 Flatpak 环境下让 CLI 进 PATH

```bash
# 加 alias 到 ~/.bashrc
echo 'alias obsidian="flatpak run --command=obsidian md.obsidian.Obsidian"' >> ~/.bashrc
source ~/.bashrc

# 验证
obsidian --version
obsidian vaults     # 列出所有 vault
```

**前提**:Obsidian GUI 必须在跑(CLI 是 thin client,通过 IPC 控制运行中的进程)。

### 4.2 高频命令清单

#### 笔记 CRUD

```bash
# 创建笔记
obsidian create name=Note content="# Title\n\nBody"  # \n 表示换行

# 读笔记内容到 stdout
obsidian read file="项目X设计"

# 追加/前置到笔记
obsidian append file="待办" content="- 新任务"
obsidian prepend file="待办" content="- 紧急: 修 bug"

# 重命名/移动(链接自动跟着改 —— CLI 的杀手锏)
obsidian rename file="老名" name="新名"
obsidian move file="某笔记" to="归档/"

# 删除(进回收站,加 permanent 才永久删)
obsidian delete file="某笔记"
```

#### Daily Notes 速记(我认为最常用)

```bash
obsidian daily                                    # 打开今日笔记
obsidian daily:append content="- 想法: 改 whisper-srv 加流式输出"
obsidian daily:append content="- $(date +%H:%M) 跟 X 对完会议要点"

# 从管道追加(把命令输出留底)
journalctl -u whisper-srv -n 20 | \
  xargs -I{} obsidian daily:append content="{}"
```

#### 搜索

```bash
# 简单搜索(text 输出)
obsidian search query="whisper"

# grep 风格(路径:行号:文本)
obsidian search:context query="TODO"

# JSON 输出给 jq
obsidian search query="待办" format=json | jq '.files[].path'

# 只数命中数(脚本判断用)
obsidian search query="meeting" total
```

#### 属性 / 任务 / 链接关系

```bash
obsidian property:set file="某笔记" key=status value=done
obsidian tasks todo                              # 跨 vault 所有未完成 task
obsidian orphans                                 # 找孤儿笔记(没人链接的)
obsidian unresolved                              # 找断链
obsidian backlinks file="某笔记"                 # 谁链接到这篇
```

### 4.3 TUI 交互模式(最被低估)

```bash
obsidian       # 不带子命令 → 进 TUI
```

TUI 内:
- 不用每次重打 `obsidian` 前缀
- `Ctrl+R` 反向历史搜索(像 bash)
- `Tab` 补全笔记名 / vault 名 / 子命令
- `Ctrl+D` 退出

**用法场景**:连续整理 inbox、批量改 tag、清理 vault —— 比每次起 process 快很多倍。

### 4.4 参数语法(常踩坑)

- **正确**:`key=value`,空格加引号 → `obsidian create name=Note content="hello world"`
- **错误**:`--key value` 或 `--key=value`(这是 GNU getopt 风格,Obsidian CLI 不认)
- 多行用 `\n` 转义,制表符用 `\t`
- 布尔标志直接给 key,如 `open`、`overwrite`(不用 `=true`)

---

## 5. 跟 Claude Code 配合的玩法

Claude Code CLI(`claude -p` print mode)+ Obsidian CLI 一拍即合 —— 都吃 stdin、都吐 stdout、都不需要 GUI。

### 5.1 整理今天随手记 → 结构化日报

```bash
obsidian daily:read | claude -p "把这些零散记录整理成: 1. 完成的事 2. 在跟进的事 3. 明日待办。Markdown 列表格式输出。"
```

把输出再写回笔记:

```bash
obsidian daily:read | \
  claude -p "整理成日报 markdown" | \
  xargs -I{} obsidian append file="$(date +%Y-%m-%d)-日报" content="{}"
```

### 5.2 跨笔记找共同主题 / 矛盾

```bash
# 找所有提到 "whisper-srv" 的笔记,让 Claude 总结决策时间线
obsidian search query="whisper-srv" format=json | \
  jq -r '.files[].path' | \
  xargs -I{} sh -c 'echo "=== {} ==="; obsidian read file="{}"' | \
  claude -p "按时间顺序梳理这些笔记里关于 whisper-srv 的关键决策"
```

### 5.3 用 Claude 写新笔记 → 直接落入 vault

```bash
# Claude 起草设计文档
claude -p "给一个 Python 异步爬虫的设计文档框架,含 章节标题 + 每节要点" | \
  xargs -0 -I{} obsidian create name="爬虫设计-$(date +%Y%m%d)" content="{}" open
```

### 5.4 提交日志自动归档

```bash
# 把 git log 让 Claude 归类成「feat / fix / chore」三类,写入今日日记
git log --oneline -20 | \
  claude -p "归类成 feat/fix/chore,markdown 列表" | \
  xargs -0 -I{} obsidian daily:append content="### 今日提交\n{}"
```

### 5.5 让 Claude Code 在写代码时主动查 vault

```bash
# 写到项目 CLAUDE.md 里(告诉 Claude Code 它可以 grep vault)
cat >> CLAUDE.md << 'EOF'
## 笔记参考

需要查项目历史决策、踩坑记录时,可以用 Obsidian CLI:

- `obsidian search query="<关键词>" format=json | jq` 找笔记
- `obsidian read file="<笔记名>"` 读内容
- 笔记 vault 路径: `~/Documents/ObsidianVault/`(或实际路径)

主要参考目录: `decisions/`、`postmortems/`、`learnings/`
EOF
```

Claude Code 看到这段就会在合适时机自己跑 obsidian 命令查笔记,**真正把笔记当外部记忆用**。

---

## 6. Vault 目录布局建议

不要陷入"完美组织"的兔子洞 —— 大部分用户的 vault 在用 1 年后都会变成扁平结构 + 大量 tag。建议初始就这样:

```
ObsidianVault/
├── inbox/              # 随手记速记,定期清理(每周/每月)
├── notes/              # 主笔记区,扁平存放 + 按 tag 组织
├── decisions/          # 项目决策记录(每决策一篇)
├── postmortems/        # 复盘 / 事故分析
├── learnings/          # 学习笔记(每主题一篇)
├── people/             # 跟人相关的笔记(per-person)
├── daily/              # Daily notes(插件自动)
├── templates/          # 模板
└── attachments/        # 附件(若用 vault-wide 配置)
```

**注**:配合 §3 的 Custom Attachment Location,`attachments/` 实际会按笔记位置分散到各处,根目录这个 `attachments/` 可以不存在。

---

## 7. 同步与备份

Obsidian Sync 是付费服务(8 美元/月)。免费方案:

```bash
# vault 当 git 仓库
cd ~/Documents/ObsidianVault
git init
echo ".obsidian/workspace*" > .gitignore     # 工作区状态本机化,不进 git
git add . && git commit -m "init vault"

# 推送到 GitHub / GitLab / 自建 Gitea
git remote add origin git@github.com:zhang/obsidian-vault.git
git push -u origin main
```

**社区插件 Obsidian Git** 帮你自动 commit/push:
```
Settings → Community plugins → Browse → "Obsidian Git" → Install → Enable
```

配置:
- Vault backup interval: `10`(分钟)
- Auto pull on startup: `on`
- Commit message: `vault backup: {{date}}`

mac / 手机 / 这台 Ubuntu 之间靠 git 仓库同步。**注意**:多设备并发编辑会产生 merge conflict,养成「用前 pull、用完 commit」习惯。

---

## 8. 推荐社区插件 Top 5

按使用频率排:

| 插件 | 作用 | 装 |
|---|---|---|
| **Obsidian Git** | 自动 commit/push,同步必备 | 同上 |
| **Custom Attachment Location** | 附件管理(见 §3) | 同上 |
| **Templater** | 模板自动化(动态变量、JS 脚本) | 同上 |
| **Dataview** | 笔记当数据库查询(列出所有 status=todo 的笔记...) | 同上 |
| **Excalidraw** | 画图(手写 / 流程图 / 思维导图) | 同上 |

每个插件第一次开启都会再问一次 "Trust this vault?"(因为社区插件能跑 JS)—— 信任即可。

---

## 9. 还原 / 卸载

```bash
# 卸 Obsidian (vault 数据完整保留,只是 app 删掉)
sudo flatpak uninstall md.obsidian.Obsidian

# 彻底清理(含 vault 配置缓存)
rm -rf ~/.var/app/md.obsidian.Obsidian/
# vault 本身在 ~/Documents/ObsidianVault/(或你的实际路径),不会被上面命令删
```

---

## Sources

- [Obsidian CLI 官方帮助](https://obsidian.md/help/cli)
- [Obsidian CLI 产品页](https://obsidian.md/cli)
- [Custom Attachment Location GitHub](https://github.com/RainCat1998/obsidian-custom-attachment-location)
- [Obsidian Git plugin](https://github.com/denolehov/obsidian-git)
