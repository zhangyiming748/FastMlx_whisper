# 使用说明（Windows 版）

本工具用于**批量给视频生成字幕（.srt 文件）**。把视频放在一个文件夹里，运行一条命令，
即可在每个视频旁边生成同名的 `.srt` 字幕文件。

支持两种机器，无需任何配置区分：

- 带 NVIDIA 显卡的电脑 → 自动用显卡加速
- 普通电脑（无独立显卡）→ 自动用 CPU 运行

---

## 一、准备条件

| 项目 | 要求 |
|---|---|
| 操作系统 | Windows 10 / 11（64 位） |
| Python | 3.11 / 3.12 / 3.15 任一版本 |
| ffmpeg | 任意近期版本 |
| 显卡 | 可选。有 NVIDIA 显卡更快，没有也能用 |
| 磁盘空间 | 至少 10 GB 空闲 |

检查是否已装好（在 PowerShell 中执行）：

```powershell
python --version
ffmpeg -version
```

两条命令都能输出版本号即可。若提示“无法识别”：

- **没装 Python**：到 <https://www.python.org/downloads/> 下载安装，安装第一屏**务必勾选 “Add python.exe to PATH”**，装完重新打开 PowerShell。
- **没装 ffmpeg**：执行下面这条，装完重新打开 PowerShell。

```powershell
winget install --id Gyan.FFmpeg --exact --accept-package-agreements --accept-source-agreements
```

---

## 二、安装（只需一次）

1. 打开本工具文件夹（能看到 `install-windows.ps1` 的那一层）
2. 点击文件夹窗口顶部的地址栏，输入 `powershell` 后按回车
3. 执行安装命令：

```powershell
.\install-windows.ps1
```

> 无 NVIDIA 显卡的电脑请改用：`.\install-windows.ps1 -CpuOnly`

安装过程会下载约 1.5 GB 依赖，需要几分钟，屏幕滚动大量文字属正常现象。
结尾看到类似下面的输出即为成功：

```
av 17.0.0
CUDA devices 1
```

- `CUDA devices 1`（或更大）→ 将使用显卡加速
- `CUDA devices 0` → 将使用 CPU（无显卡电脑的正常结果）

---

## 三、生成字幕

在同一个 PowerShell 窗口中执行：

```powershell
.\batchWhisper.ps1 "D:\视频文件夹" ja
```

- 把 `"D:\视频文件夹"` 换成你存放视频的实际文件夹路径
- 把 `ja` 换成视频的说话语言（见下方语言代码表）

运行时会显示实际使用的设备（`cuda` = 显卡 / `cpu` = CPU）。想中途停止按 `Ctrl + C`。

**首次使用某个模型时会先自动下载模型**（几百 MB ~ 3 GB，只下载一次），之后不再联网。

### 常用示例

```powershell
# 处理 D:\Movies 下所有视频，日语
.\batchWhisper.ps1 "D:\Movies" ja

# 英语视频，用速度更快的模型
.\batchWhisper.ps1 "D:\Movies" en large-v3-turbo

# 无显卡电脑，建议指定 CPU 和 small 模型
.\batchWhisper.ps1 "D:\Movies" en small cpu
```

### 参数说明

```powershell
.\batchWhisper.ps1 [视频文件夹] [语言] [模型] [设备]
```

| 参数 | 默认值 | 说明 |
|---|---|---|
| 视频文件夹 | 当前目录 | 支持 `.mp4` `.mkv` `.wav`，含子文件夹 |
| 语言 | `de` | 见下方语言代码表 |
| 模型 | `large-v3` | 日常推荐 `large-v3-turbo`（快 2~3 倍，精度略低） |
| 设备 | `auto` | `auto` 自动选择 / `cuda` 强制显卡 / `cpu` 强制 CPU |

**语言代码：**

| 代码 | 语言 |
|---|---|
| `de` | 德语 |
| `es` | 西班牙语 |
| `en` | 英语 |
| `yue` | 粤语 |
| `ja` | 日语 |

---

## 四、输出结果

字幕生成在**视频所在文件夹**，与视频同名：

```
D:\Movies\movie01.mkv
D:\Movies\movie01.srt   ← 生成的字幕
```

> 注意：同名 `.srt` 会被覆盖。如果您手工修改过字幕，重跑前请先备份。

---

## 五、常见问题

### 1. 提示“在此系统上禁止运行脚本”

这是 PowerShell 的安全策略限制，执行下面这条放开（只需一次），然后重试：

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

### 2. 首次下载模型很慢 / 卡住

国内网络可在运行前设置镜像（只对当前窗口有效，重开窗口需重新设置）：

```powershell
$env:HF_ENDPOINT = "https://hf-mirror.com"
.\batchWhisper.ps1 "D:\Movies" ja
```

### 3. 提示显存不足（Out of Memory）

- 换小一点的模型：`.\batchWhisper.ps1 "D:\Movies" ja large-v3-turbo`
- 关闭占用显存的程序（如浏览器、游戏）
- 仍不行则强制用 CPU：`.\batchWhisper.ps1 "D:\Movies" ja large-v3-turbo cpu`

### 4. CPU 电脑跑得太慢

`large-v3` 在 CPU 上非常慢，建议改用 `small` 模型：

```powershell
.\batchWhisper.ps1 "D:\Movies" en small cpu
```

### 5. 安装或运行报错，想彻底重来

```powershell
Remove-Item -Recurse -Force .venv
.\install-windows.ps1
```

这只删除本工具的运行环境，不影响系统里的 Python 和其他软件。

---

## 六、卸载

删除本工具文件夹即可。如需同时清理下载的模型缓存（约数 GB）：

```powershell
Remove-Item -Recurse -Force "$env:USERPROFILE\.cache\huggingface"
```
