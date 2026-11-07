# Windows 使用手册（faster-whisper 版）

本手册面向 **Windows** 平台，支持两种机器：

- 带 **NVIDIA 显卡 + CUDA** 的机器（自动使用 GPU 加速）
- **只有 CPU** 的机器（自动退回 CPU 推理）

最终产物：与视频同目录、同文件名的 **`.srt` 字幕文件**。

> **不想看长文档？** 只需两步：
> 1. 在本文件夹打开 PowerShell，执行 `.\install-windows.ps1`（纯 CPU 机器加 `-CpuOnly`）
> 2. 执行 `.\batchWhisper.ps1 "D:\视频目录" ja`
>
> 其余章节是给第一次接触 Python 的人准备的排错与背景说明。也可以直接翻到
> [第 14 章 一页操作清单](#14-一页操作清单)。

---

## 1. 环境要求

| 项目 | 要求 | 说明 |
|---|---|---|
| 操作系统 | Windows 10 / 11 64 位 | |
| Python | **3.11 / 3.12 / 3.15** | 3.15 缺少 `onnxruntime`、`pyyaml` 的 wheel，**必须用 `install-windows.ps1` 安装**；3.11/3.12 可直接 `pip install -r requirements.txt` |
| ffmpeg | 任意近期版本 | 必需，用于解码 mp4/mkv；需在 `PATH` 中 |
| 显卡（可选） | NVIDIA，支持 CUDA 12 | 无显卡也能跑，只是慢 |
| 磁盘 | 至少 10 GB 空闲 | `.venv` 约 1.5 GB，模型 75 MB ~ 3 GB |

检查是否已安装：

```powershell
python --version
ffmpeg -version
nvidia-smi
```

- `python --version` 输出 `Python 3.11.x` / `3.12.x` / `3.15.x` 都算通过
- `ffmpeg -version` 输出一串版本信息即通过
- `nvidia-smi` 能输出显卡表格说明有 NVIDIA 显卡；报错也无妨，会走 CPU

---

## 2. 安装（照着做即可）

> 本章写给不熟悉 Python 的读者。每条命令都可以直接复制粘贴到 PowerShell。
> **所有命令都要在仓库根目录执行**（即能看到 `batchWhisper.ps1` 的那个文件夹）。

### 2.0 先认识三样东西

| 名称 | 它是什么 | 你需要做什么 |
|---|---|---|
| Python | 运行程序的引擎 | 电脑里**已经装了就用它**，不要再装第二个 |
| `.venv` | 这个项目的“独立工具箱” | 安装脚本会自动创建，你不需要手动激活 |
| ffmpeg | 读取视频/音频的工具 | 需要单独安装一次 |

### 2.1 打开 PowerShell 并进入仓库目录

最简单的方法：

1. 用文件资源管理器打开仓库文件夹（能看到 `batchWhisper.ps1` 的那一层）
2. 点击窗口顶部的地址栏，输入 `powershell`，按回车
3. 弹出的窗口里执行 `pwd`，确认输出的路径就是仓库目录

### 2.2 检查 Python

```powershell
python --version
```

| 看到的结果 | 说明 | 下一步 |
|---|---|---|
| `Python 3.11.x` / `3.12.x` / `3.15.x` | 已有可用的 Python | 继续 2.3 |
| `不是内部或外部命令` / `无法将“python”项识别为...` | Python 没装，或没加入 PATH | 去 <https://www.python.org/downloads/> 下载安装，**安装第一屏务必勾选 “Add python.exe to PATH”**，装完重开 PowerShell |

> 3.11 / 3.12 / 3.15 都能用，不需要为了本项目额外安装别的版本。

### 2.3 检查并安装 ffmpeg

```powershell
ffmpeg -version
```

- 能输出 `ffmpeg version ...` → 已就绪，继续 2.4
- 提示找不到命令 → 执行下面这条，装完**关掉 PowerShell 重新打开**再检查

```powershell
winget install --id Gyan.FFmpeg --exact --accept-package-agreements --accept-source-agreements
```

### 2.4 一条命令安装依赖

有 NVIDIA 显卡：

```powershell
.\install-windows.ps1
```

纯 CPU 机器：

```powershell
.\install-windows.ps1 -CpuOnly
```

执行时会发生什么：

- 会自动创建 `.venv` 文件夹，**不会另外安装 Python**
- 会下载约 1.5 GB 的依赖，第一次需要几分钟，屏幕滚动大量文字是正常的
- 中途出现一条 `huggingface-hub requires pyyaml` 的黄色警告，**可以忽略**（纯 Python 版 yaml 是直接复制进去的）
- 脚本可以重复运行，不会破坏已有环境

脚本内部处理了三个 3.15 特有的坑：

1. 以 `--no-deps` 安装，跳过 3.15 没有 wheel 的 `onnxruntime`（它只用于默认关闭的 VAD 过滤）
2. 锁定 `av==17.0.0`（`av 18/19` 与 `faster-whisper 1.2.1` 不兼容）
3. 从 PyPI 源码包复制纯 Python 版 `pyyaml`，绕开 3.15 缺少 wheel、需要 MSVC 编译的问题

> **千万不要**在 Python 3.15 下直接执行 `pip install -r requirements.txt`。
> 那个文件是给 Python 3.11/3.12 的标准安装用的；在 3.15 上会卡在
> `onnxruntime` / `pyyaml` / `av` 的编译错误上。请统一用上面的脚本。

### 2.5 确认安装成功

脚本最后会打印类似内容：

```
==> Verifying installation
av 17.0.0
CUDA devices 1

Done. Next: .\batchWhisper.ps1 . en tiny
```

| 输出 | 含义 |
|---|---|
| `CUDA devices 1`（或更大） | GPU 可用，转写会自动用显卡 |
| `CUDA devices 0` | 将使用 CPU；纯 CPU 机器这是正常结果 |
| 出现红色 `ERROR` | 未成功，请看第 10 章对应报错 |

### 2.6 装错了想重来

```powershell
Remove-Item -Recurse -Force .venv
.\install-windows.ps1
```

`Remove-Item` 只是删除本项目的工具箱文件夹，不会影响系统里的 Python，也不会影响其他软件。

---

## 3. 快速开始

在仓库根目录打开 PowerShell：

```powershell
# 处理当前目录下所有 mp4/mkv/wav，德语，large-v3 模型
.\batchWhisper.ps1

# 处理指定文件夹，日语
.\batchWhisper.ps1 "D:\Movies\Japanese" ja

# 英语 + 更快的模型
.\batchWhisper.ps1 "D:\Movies" en large-v3-turbo

# 强制使用 CPU（int8）
.\batchWhisper.ps1 "D:\Movies" ja large-v3 cpu
```

**不需要**手动 `activate` 虚拟环境。脚本内部用绝对路径直接调用
`.venv\Scripts\whisper-ctranslate2.exe`，并自动补齐 CUDA 的 `PATH`。

运行时你会看到：

```
推理设备: cuda（compute_type=float16）
语言开关 LANG_CODE=ja，已自动选用对应初始提示词。
正在处理视频: D:\Movies\Japanese\movie01.mkv
...
✅ 处理成功: D:\Movies\Japanese\movie01.mkv
```

- 第一行显示 `cuda` 或 `cpu`，就是实际使用的设备
- 想中途停止，按 `Ctrl + C`
- 第一次使用某个模型时会先下载（见第 5 章），之后不再联网

---

## 4. 参数说明

```powershell
.\batchWhisper.ps1 [目录] [语言] [模型] [设备]
```

| 位置 | 名称 | 默认值 | 可选值 |
|---|---|---|---|
| 第 1 个 | 目标目录 | `.`（当前目录） | 任意目录路径 |
| 第 2 个 | 语言 | `de` | `de` `es` `en` `yue` `ja` |
| 第 3 个 | 模型 | `large-v3` | 见下表 |
| 第 4 个 | 设备 | `auto` | `auto` `cuda` `cpu` |

### 语言代码

| 代码 | 语言 |
|---|---|
| `de` | 德语 |
| `es` | 西班牙语 |
| `en` | 英语 |
| `yue` | 粤语（用繁体粤语书写提示词，避免被转成书面普通话） |
| `ja` | 日语 |

每种语言都自带一段母语书写的 `initial_prompt`，用于定调文体、标点、保留语气词和拉长发音。

### 模型选择

| 模型 | 大小（约） | 速度 | 说明 |
|---|---|---|---|
| `tiny` | 75 MB | 最快 | 测试用，精度低 |
| `base` | 140 MB | 很快 | 精度一般 |
| `small` | 460 MB | 快 | CPU 机器的实用下限 |
| `medium` | 1.5 GB | 中 | GPU 显存紧张时的折中 |
| `large-v3` | 3 GB | 慢 | **默认**，精度最高 |
| `large-v3-turbo` | 1.6 GB | 较快 | **日常推荐**，精度略低但快 2~3 倍 |

### 设备

| 值 | 行为 |
|---|---|
| `auto` | 检测到可用 CUDA 用 GPU（`float16`），否则 CPU（`int8`） |
| `cuda` | 强制 GPU，`compute_type=float16` |
| `cpu` | 强制 CPU，`compute_type=int8` |

---

## 5. 首次运行会下载模型

- 缓存位置：`C:\Users\<用户名>\.cache\huggingface\hub`
- 不需要 HuggingFace Token（模型都是公开的）
- 第二次运行直接读缓存，不再联网
- 国内网络下载慢时，可在运行前设置镜像：

```powershell
$env:HF_ENDPOINT = "https://hf-mirror.com"
.\batchWhisper.ps1 "D:\Movies" ja
```

注意：`$env:HF_ENDPOINT` 只在**当前 PowerShell 窗口**有效，关掉窗口就失效，下次需要重新设置。

如果模型已经下载过、但运行时仍卡在联网检查，可以临时强制离线：

```powershell
$env:HF_HUB_OFFLINE = "1"
.\batchWhisper.ps1 "D:\Movies" ja
```

---

## 6. 输出文件

字幕写入**源视频所在目录**，文件名与视频一致：

```
D:\Movies\Japanese\movie01.mkv
D:\Movies\Japanese\movie01.srt   ← 生成这个
```

- 已存在的同名 `.srt` 会被**覆盖**，重跑前请备份手工修改过的字幕
- 扫描的扩展名：`.mp4`、`.mkv`、`.wav`（不区分大小写，含子目录）

---

## 7. 执行策略问题

如果提示“无法加载文件……因为在此系统上禁止运行脚本”，这是 PowerShell 的安全策略，不是脚本错误。
`install-windows.ps1` 和 `batchWhisper.ps1` 都可能触发。

一次性放开当前用户（推荐，只需执行一次）：

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

或临时绕过（只对这一次命令有效）：

```powershell
powershell -ExecutionPolicy Bypass -File .\install-windows.ps1
powershell -ExecutionPolicy Bypass -File .\batchWhisper.ps1 "D:\Movies" ja
```

---

## 8. 在任意目录运行

脚本会自己定位仓库内的 `.venv`，因此不必先 `cd` 进仓库；但**目标目录是相对你当前所在位置**的，建议直接给绝对路径：

```powershell
cd D:\
C:\Users\zen\Github\FastMlx_whisper\batchWhisper.ps1 "D:\Movies" ja
```

---

## 9. 只处理单个文件

脚本按“目录”扫描。单个文件最简单的做法是放进单独文件夹再跑；也可以直接调用命令行：

```powershell
$env:PATH = "$PWD\.venv\Lib\site-packages\nvidia\cublas\bin;$PWD\.venv\Lib\site-packages\nvidia\cudnn\bin;$env:PATH"
.venv\Scripts\whisper-ctranslate2.exe "D:\a.mp4" --model large-v3 --language ja --output_format srt --output_dir "D:\" --device cuda --compute_type float16
```

---

## 10. 常见问题

### Q1. 报错 `Library cublas64_12.dll is not found or cannot be loaded`

CTranslate2 不会自动加载 pip 安装的 CUDA 库。`batchWhisper.ps1` 已自动把以下目录加入 `PATH`：

```
.venv\Lib\site-packages\nvidia\cublas\bin
.venv\Lib\site-packages\nvidia\cudnn\bin
.venv\Lib\site-packages\nvidia\cuda_nvrtc\bin
```

如果你是自己手敲 `whisper-ctranslate2` 命令，需要先手动设置 `PATH`（见第 9 节）。

### Q2. 脚本中文乱码 / 报 `Unexpected token`

PowerShell 5.1 读取 UTF-8 文件需要 **BOM**。请用编辑器把 `batchWhisper.ps1` 另存为
“UTF-8 with BOM”。仓库里的这份文件已带 BOM，改写时注意不要丢失。

### Q3. 显存不足（RTX 4060 8 GB 等）

- 换 `large-v3-turbo` 或 `medium`
- 关掉浏览器等占用显存的程序
- 仍不够时改用 `cpu` 参数

### Q4. CPU 上太慢

`large-v3` 在 CPU 上会非常慢，建议：

```powershell
.\batchWhisper.ps1 "D:\Movies" en small cpu
```

### Q5. 安装时反复报 `Failed to build 'av'` / `No matching distribution found for onnxruntime` / `Microsoft Visual C++ 14.0 is required`

说明你直接跑了 `pip install -r requirements.txt`，而当前 Python（多半是 3.15）没有这些包的 wheel。
请改用安装脚本，它会绕过这些编译/缺 wheel 的问题：

```powershell
Remove-Item -Recurse -Force .venv
.\install-windows.ps1
```

### Q6. 报 `open() got an unexpected keyword argument 'metadata_errors'`

`av` 装成了 18/19，与 `faster-whisper 1.2.1` 不兼容。重跑安装脚本会锁定 `av==17.0.0`：

```powershell
.\install-windows.ps1
```

---

## 11. 卸载 / 清理

```powershell
# 删除虚拟环境
Remove-Item -Recurse -Force .venv

# 删除模型缓存（可选，会删掉所有 HF 模型）
Remove-Item -Recurse -Force "$env:USERPROFILE\.cache\huggingface"
```

---

## 12. 与 macOS 版的对应关系

| macOS（master 分支） | Windows（本分支） |
|---|---|
| `mlx-whisper` | `whisper-ctranslate2`（底层 `faster-whisper` / CTranslate2） |
| `mlx_whisper` 命令 | `whisper-ctranslate2` 命令 |
| `batchWhisper.sh` | `batchWhisper.ps1` |
| `brew install ffmpeg` | `winget install Gyan.FFmpeg` |
| `mlx-community/whisper-large-v3-mlx` | `large-v3` |

字幕质量相关参数（`word_timestamps`、`max_line_width`、`max_line_count`、
`condition_on_previous_text`、`compression_ratio_threshold`、
`hallucination_silence_threshold`、`no_speech_threshold`、`initial_prompt`）在两边是一一对应的。

---

## 13. Python 名词解释（不需要会编程也能看懂）

| 名词 | 通俗解释 |
|---|---|
| `python` 命令 | 运行 Python 程序的“引擎” |
| `pip` | Python 的应用商店，负责下载、安装第三方库 |
| 库 / 包 | 别人写好的现成功能模块；本项目用的是 `whisper-ctranslate2` |
| wheel（`.whl`） | 打包好的“成品安装包”，下载后可直接使用 |
| 源码包（`.tar.gz`） | 需要在本机现场编译的原始代码；编译通常需要微软 C++ 编译器（MSVC），最容易失败 |
| `.venv`（虚拟环境） | 本项目专用的“工具箱”，依赖只装在这里，不污染系统 |
| `PATH` | 系统查找命令的目录列表；`ffmpeg` 找不到，基本都是 PATH 没配好 |
| `requirements.txt` | 依赖清单；在 Python 3.15 上不能直接用它安装（见 2.4 的警告） |
| `--no-deps` | “只装这个包本身，不要自动装它的依赖” |
| CUDA / cublas / cuDNN | NVIDIA 的显卡运算库，让模型跑在 GPU 上 |
| `float16` / `int8` | 数值精度；GPU 用 `float16`，CPU 用 `int8`，更省内存 |

---

## 14. 一页操作清单

### 首次部署

1. 在仓库目录打开 PowerShell（2.1）
2. `python --version` → 有版本号（2.2）
3. `ffmpeg -version` → 有版本号；没有就 `winget install Gyan.FFmpeg`（2.3）
4. `.\install-windows.ps1`（纯 CPU 机器加 `-CpuOnly`）（2.4）
5. 结尾出现 `av 17.0.0` + `CUDA devices 1` → 成功（2.5）

### 日常使用

```powershell
.\batchWhisper.ps1 "D:\Movies" ja
```

产物：源视频同目录、同名的 `.srt`（第 6 章）

### 出问题时按顺序排查

1. 红色 `ERROR` → 第 10 章按关键词搜索
2. 提示“禁止运行脚本” → 第 7 章
3. 提示找不到 `ffmpeg` → 2.3
4. 环境装乱了想重来 → 2.6

### 不要做的事

- 不要为了本项目再装第二个 Python
- 在 Python 3.15 下不要执行 `pip install -r requirements.txt`
- 不要手动 `activate` 虚拟环境，脚本会自己处理
- 不要删除 `.venv` 以外的任何文件（`.venv` 删了重跑安装脚本即可恢复）
