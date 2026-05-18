# Remote-SSH 工作流 + Ubuntu 笔记本 7×24 常开

> **版本**: v1.0
> **更新时间**: 2026-05-18
> **场景**: Mac 当编辑器,Ubuntu (Legion Y9000P) 当算力,代码在 Ubuntu 不双端同步;合盖不休眠 24h 运行

---

## Part 1. Remote-SSH 工作流

### 1.1 核心原则

**Mac 写代码 + Ubuntu 跑训练 + 文件只在 Ubuntu + Git 仅做版本备份**。

不要双端同步代码 —— 容易漏 push、环境冲突、训练中改代码版本错乱。

### 1.2 Mac 一次性配置

```bash
# 1. ~/.ssh/config 加别名 (推荐用 mDNS 名)
cat >> ~/.ssh/config <<'EOF'

Host ubuntu
    HostName zhang-Legion-Y9000P-IRX9.local
    User zhang
    ServerAliveInterval 60
    ServerAliveCountMax 3
EOF

# 2. 免密 (如未配)
ssh-copy-id zhang@zhang-Legion-Y9000P-IRX9.local
ssh ubuntu "echo ok"   # 应直接返回 ok

# 3. VS Code 装扩展 "Remote - SSH" (Cursor 同理)
code --install-extension ms-vscode-remote.remote-ssh
```

### 1.3 连接 + 打开项目

VS Code 左下角绿色按钮 `><` → `Connect to Host...` → 选 `ubuntu` → 新窗口 `Open Folder` → 输 `/home/zhang/Projects/quant` → 回车。

之后:
- 文件树 / 编辑 / Git / Terminal / 断点调试 像本地一样
- 文件实际在 Ubuntu,Mac 不存代码
- `python xxx.py` 跑的是 **Ubuntu 的 Python / GPU**

### 1.4 选 Ubuntu 上的 Conda 环境

打开 `.py` → 右下角 Python 解释器 → 选 `~/miniconda3/envs/qlib/bin/python`。

### 1.5 跑长任务: tmux

```bash
# Ubuntu 上 (通过 Remote-SSH 终端或 ssh)
tmux new -s train
python train.py
# Ctrl+B 再按 D 脱离, 任务继续跑

# 回来
tmux attach -t train
```

### 1.6 端口转发: 本地浏览器看 Ubuntu 上的服务

```bash
# Mac 上一条命令, Jupyter
ssh -L 8888:127.0.0.1:8888 ubuntu
# 浏览器开 http://127.0.0.1:8888

# TensorBoard
ssh -L 6006:127.0.0.1:6006 ubuntu
```

或 VS Code Remote-SSH 自带的 Ports 面板,点 `Forward a Port` → 输 8888,更直观。

### 1.7 数据布局

```
~/Projects/quant/              ← 代码 (Remote-SSH 编辑, git 备份)
├── strategies/
├── notebooks/
├── data → /mnt/lotus-products/qlib-data/   ← 软链到 NAS
└── .gitignore                 ← 必须忽略 data/

/mnt/lotus-products/qlib-data/ ← NAS 上的实际大数据
```

```bash
cd ~/Projects/quant
ln -s /mnt/lotus-products/qlib-data data
echo "data" >> .gitignore
echo "*.pkl"   >> .gitignore
echo "*.parquet" >> .gitignore
```

### 1.8 Git 备份策略 (不用于同步)

```bash
cd ~/Projects/quant
git init
git add . && git commit -m "init"
git remote add origin git@github.com:你/quant.git    # 或私有 Gitea
git push -u origin main
```

每天结束 / 重要节点 commit + push,**仅作灾备和版本回溯**。

### 1.9 故障排查

| 症状 | 解决 |
|---|---|
| VS Code 连不上 / 一直 "Connecting" | Mac 终端先 `ssh ubuntu` 测; 不通就修 SSH 不是 VS Code |
| 连上但 Python 解释器找不到 conda | 右下角解释器栏 → "Enter interpreter path" → 输完整路径 |
| 远端扩展装一半卡死 | Ubuntu 端 `rm -rf ~/.vscode-server` 后重连,会重装 |
| 文件保存延迟 / 闪烁 | 网络问题 (无线慢); 关掉 `files.autoSave` 改手动 Ctrl+S |
| Git push 慢 | 大文件没忽略掉, 看 `git status` 检查 |

---

## Part 2. Ubuntu 笔记本合盖不休眠 + 7×24

### 2.1 三层都要改: logind + GNOME + 网络

Ubuntu 上"睡眠"由三层独立控制,**任何一层没改都会触发休眠**:

| 层 | 触发条件 | 配置位置 |
|---|---|---|
| **systemd-logind** | 合盖、按电源键 | `/etc/systemd/logind.conf` |
| **GNOME 电源** | 闲置一定时间 | `gsettings org.gnome.settings-daemon.plugins.power` |
| **Wi-Fi 节能** | 空闲降速断连 | `nmcli` |

### 2.2 第 1 层: systemd-logind 合盖不动作

```bash
# 备份
sudo cp /etc/systemd/logind.conf /etc/systemd/logind.conf.bak

# 用 drop-in 文件配置 (推荐,不污染主配置)
sudo mkdir -p /etc/systemd/logind.conf.d
sudo tee /etc/systemd/logind.conf.d/no-suspend.conf > /dev/null <<'EOF'
[Login]
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
HandlePowerKey=ignore
EOF

# 生效
sudo systemctl restart systemd-logind
```

> ⚠️ `restart systemd-logind` 在某些桌面会自动登出。最好先保存所有工作,或者改完直接 reboot。

### 2.3 第 2 层: 屏蔽所有 sleep target

彻底禁掉系统进入挂起 / 休眠的能力:

```bash
sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target

# 验证 (应都显示 masked)
systemctl status sleep.target | head -3
```

恢复用 `sudo systemctl unmask ...`。

### 2.4 第 3 层: GNOME 关闭闲置挂起 + 屏幕黑屏 (可选)

```bash
# 接电源时不挂起
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing'
# 用电池时也不挂起 (但建议 24h 一定接电源)
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type 'nothing'

# 闲置时间 0 = 永不
gsettings set org.gnome.desktop.session idle-delay 0

# 验证
gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type
gsettings get org.gnome.desktop.session idle-delay
```

如果想合盖时**屏幕黑屏省电但系统继续运行**(推荐):

```bash
# 5 分钟无操作关屏 (系统不睡, GPU/CPU 照常)
gsettings set org.gnome.settings-daemon.plugins.power power-saver-profile-on-low-battery false
# 上面这条只是避免低电池自动省电; 真正关屏看下方
xset s 300              # 5min 后启动屏保 (黑屏)
xset dpms 0 0 300       # DPMS 关屏
```

### 2.5 第 4 层: Wi-Fi 永不省电断连

```bash
# 看当前活动连接名
nmcli -t -f NAME,DEVICE,STATE c show --active

# 假设连接名是 "公司WiFi", 关掉它的省电
sudo nmcli connection modify "公司WiFi" 802-11-wireless.powersave 2
#   2 = disable (永不省电), 3 = enable

# 立即重连生效
sudo nmcli connection down "公司WiFi" && sudo nmcli connection up "公司WiFi"
```

### 2.6 ⚠️ 散热和电池寿命的现实问题

笔记本合盖 7×24 跑是**反设计**的,会有:

| 问题 | 严重性 | 建议 |
|---|---|---|
| 合盖散热口被压 → CPU 降频 / 烧坏 | 高 | **抬起底部**(笔记本支架)或**斜放保留进风口** |
| 电池长期满电 → 鼓包寿命缩短 | 中 | Lenovo 一般有"养护充电"功能(在 BIOS / Lenovo Vantage),设上限 80% |
| 风扇噪音 / 灰尘累积 | 中 | 定期(3-6 月)清理散热 |
| 显示器一直亮 → 烧屏 + 耗能 | 低 | 用 §2.4 的 xset 关屏 |

### 2.7 推荐: 装个散热监控

```bash
sudo apt install -y lm-sensors htop
sudo sensors-detect --auto

# 看 CPU 温度
sensors | grep -E "Tctl|Core"
# 90°C+ 就要赶紧改善散热
```

### 2.8 验证: 合盖 + SSH 还能连

```bash
# Mac 上
ssh ubuntu "uptime && date"
# 然后物理合盖 Ubuntu (保持抬起或留缝)
# 30 秒后再:
ssh ubuntu "uptime && date"
# uptime 应递增, 说明 Ubuntu 还活着
```

### 2.9 极端备选: 直接拔掉 GNOME

如果你 24×7 跑训练根本不需要图形界面,可以切到 multi-user.target (无 GUI),省 GPU / 内存,且消除所有 GNOME 触发的休眠隐患:

```bash
# 切到无 GUI 模式 (重启生效)
sudo systemctl set-default multi-user.target

# 想图形界面时
sudo systemctl set-default graphical.target
```

无 GUI 后,所有 §2.4 都不用做,只剩 logind + Wi-Fi 两层。

---

## Part 3. 速查命令

```bash
# === Remote-SSH ===
ssh ubuntu                              # 连
ssh -L 8888:127.0.0.1:8888 ubuntu       # 转发 Jupyter
tmux new -s X / Ctrl+B D / tmux attach -t X    # 后台跑

# === 合盖不睡 ===
sudo systemctl status systemd-logind    # 看 logind 状态
systemctl status sleep.target           # 应显示 masked
gsettings get org.gnome.desktop.session idle-delay   # 应是 0
nmcli c show "<wifi名>" | grep powersave             # 应是 2

# === 健康监控 ===
uptime                                  # 看在线时长
sensors | grep -E "Tctl|Core"           # CPU 温度
nvidia-smi                              # GPU 温度 / 利用率
free -h                                 # 内存
df -h                                   # 磁盘
```

---

## Part 4. 一次性脚本

把 Part 2 的所有改动打包,一行执行:

```bash
sudo bash <<'EOF'
# logind 不响应合盖/电源键
mkdir -p /etc/systemd/logind.conf.d
cat > /etc/systemd/logind.conf.d/no-suspend.conf <<'CONF'
[Login]
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
HandlePowerKey=ignore
CONF

# 屏蔽所有 sleep target
systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target

# 重启 logind 生效
systemctl restart systemd-logind

echo "✅ logind + sleep target 已配置"
EOF

# 用户态: GNOME + Wi-Fi (不能用 sudo)
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing'
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type 'nothing'
gsettings set org.gnome.desktop.session idle-delay 0

WIFI=$(nmcli -t -f NAME,DEVICE,STATE c show --active | awk -F: '$2~/wl/ {print $1; exit}')
[ -n "$WIFI" ] && sudo nmcli connection modify "$WIFI" 802-11-wireless.powersave 2 && echo "✅ Wi-Fi 省电已关"

echo "✅ 全部生效, 建议 reboot 一次确认; 物理放置时记得抬起底部留散热"
```

---

## 变更记录

| 版本 | 日期 | 变更 |
|---|---|---|
| v1.0 | 2026-05-18 | 初版: Remote-SSH 工作流 (VS Code/Cursor) + Ubuntu 笔记本合盖不睡 4 层配置 + 散热提醒 + 一次性脚本 |
