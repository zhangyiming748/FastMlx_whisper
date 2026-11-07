```shell
SRC="/path/to/src"; DST="/Users/zen/github/TraditionTranslate/srt"; cd "$SRC" && find . -type d -exec mkdir -p "$DST/{}" \; && find . -name '*.srt' -exec cp {} "$DST/{}" \;
```
# FastMlx_whisper
批量使用针对Apple Silicon优化的 whisper

完整操作手册如下（最终输出为 **SRT 字幕文件**）：

---

# Apple Silicon 本地 Whisper 字幕生成手册（mlx-whisper）

适用环境：macOS + Apple M 系列芯片  
目标：隔离安装 + 生成 `.srt` 字幕文件

---

## 1. 创建隔离环境

```bash
# 创建专用目录(可选)
mkdir -p ~/whisper-isolated && cd ~/whisper-isolated

# 创建虚拟环境
python3 -m venv venv

# 激活虚拟环境
source venv/bin/activate
```

激活成功后，命令行前面会出现 `(venv)`。

---

## 2. 安装依赖

```bash
# 更换pypi
pip config set global.index-url https://mirrors.tuna.tsinghua.edu.cn/pypi/web/simple

# 升级 pip
pip install --upgrade pip mlx-whisper huggingface_hub

# 安装 mlx-whisper 和 huggingface_hub
pip install mlx-whisper huggingface_hub
#或直接
pip install -r requirements.txt

# 安装 ffmpeg（处理音视频必需）
brew install ffmpeg
```

---

## 3. 登录 Hugging Face（下载模型需要）

```bash
python -c "from huggingface_hub import login; login()"
```

1. 浏览器打开：https://huggingface.co/settings/tokens  
2. 新建一个 **Read** 权限的 Token  
3. 复制 Token，粘贴到终端（粘贴时不显示字符，正常）  
4. 按回车完成登录

---

## 4. 生成 SRT 字幕（最终命令）

```bash
mlx_whisper 'video.mp4' \
  --model mlx-community/whisper-medium.en-mlx \
  --language en \
  --output-format srt \
  --output-dir .
```

### 参数说明：
- `--model`：使用 medium.en 模型（英文优化）
可选
mlx-community/whisper-tiny
mlx-community/whisper-base
mlx-community/whisper-small
mlx-community/whisper-medium-mlx
mlx-community/whisper-large-v3-mlx
mlx-community/whisper-large-v3-turbo
mlx-community/distil-whisper-large-v3
mlx-community/whisper-medium.en-mlx
- `--language en`：指定英语
可选
{af,am,ar,as,az,ba,be,bg,bn,bo,br,bs,ca,cs,cy,da,de,el,en,es,et,eu,fa,fi,fo,fr,gl,gu,ha,haw,he,hi,hr,ht,hu,hy,id,is,it,ja,jw,ka,kk,km,kn,ko,la,lb,ln,lo,lt,lv,mg,mi,mk,ml,mn,mr,ms,mt,my,ne,nl,nn,no,oc,pa,pl,ps,pt,ro,ru,sa,sd,si,sk,sl,sn,so,sq,sr,su,sv,sw,ta,te,tg,th,tk,tl,tr,tt,uk,ur,uz,vi,yi,yo,yue,zh,Afrikaans,Albanian,Amharic,Arabic,Armenian,Assamese,Azerbaijani,Bashkir,Basque,Belarusian,Bengali,Bosnian,Breton,Bulgarian,Burmese,Cantonese,Castilian,Catalan,Chinese,Croatian,Czech,Danish,Dutch,English,Estonian,Faroese,Finnish,Flemish,French,Galician,Georgian,German,Greek,Gujarati,Haitian,Haitian Creole,Hausa,Hawaiian,Hebrew,Hindi,Hungarian,Icelandic,Indonesian,Italian,Japanese,Javanese,Kannada,Kazakh,Khmer,Korean,Lao,Latin,Latvian,Letzeburgesch,Lingala,Lithuanian,Luxembourgish,Macedonian,Malagasy,Malay,Malayalam,Maltese,Mandarin,Maori,Marathi,Moldavian,Moldovan,Mongolian,Myanmar,Nepali,Norwegian,Nynorsk,Occitan,Panjabi,Pashto,Persian,Polish,Portuguese,Punjabi,Pushto,Romanian,Russian,Sanskrit,Serbian,Shona,Sindhi,Sinhala,Sinhalese,Slovak,Slovenian,Somali,Spanish,Sundanese,Swahili,Swedish,Tagalog,Tajik,Tamil,Tatar,Telugu,Thai,Tibetan,Turkish,Turkmen,Ukrainian,Urdu,Uzbek,Valencian,Vietnamese,Welsh,Yiddish,Yoruba}
- `--output-format srt`：输出 SRT 字幕文件
- `--output-dir .`：输出到当前目录

运行成功后，会在当前目录生成：

```
Fucking The Police!The Best Of Hot Cops.srt
```

---

## 5. 常用可选参数

```bash
# 同时输出多种格式（txt + srt + json）
--output-format all

# 指定输出文件名（不带扩展名）
--output-name my_subtitle

# 开启词级时间戳（更精确的字幕时间）
--word-timestamps True

# 翻译成英文（非英语音频时用）
--task translate
```

---

## 6. 以后再次使用

```bash
cd ~/whisper-isolated
source venv/bin/activate

mlx_whisper '你的视频或音频路径' \
  --model mlx-community/whisper-medium.en-mlx \
  --language en \
  --output-format srt
```

---

## 7. 防重复幻觉参数（batchWhisper.sh 已启用）

Whisper 模型在遇到静音、背景噪音或低音量段落时，容易产生**重复幻觉**（repetition hallucination），
表现为字幕中连续出现多行完全相同的内容，例如：

```
[44:01.080 --> 44:02.080]  Mmm.
[44:02.080 --> 44:03.080]  Mmm.
[44:03.080 --> 44:04.080]  Mmm.
```

`batchWhisper.sh` 中已启用以下三个参数来抑制此问题：

| 参数 | 当前值 | 作用 |
|---|---|---|
| `--condition-on-previous-text` | `False` | **最关键**。关闭后，模型在解码下一个时间窗口时不再依赖上一窗口的输出，直接切断重复循环的根源。副作用：可能导致相邻窗口之间的文本衔接不够连贯，但不会丢失内容。 |
| `--compression-ratio-threshold` | `2.4` | Whisper 会计算每段输出的 gzip 压缩比，如果内容高度重复（如连续相同的词），压缩比会异常低，触发此阈值后该段结果会被丢弃。正常语音内容不受影响。 |
| `--hallucination-silence-threshold` | `30` | 当静音段超过 30 秒时，模型不再为其生成字幕内容，避免在长静音段产生幻觉。正常对话中的短暂停顿不受影响。 |

### 未启用的参数及原因

| 参数 | 说明 |
|---|---|
| `--no-speech-threshold` | 控制“无语音”判定阈值（默认 0.6）。提高该值可过滤更多静音段，但**可能误伤轻声细语**，因此当前未启用。如需进一步抑制重复，可手动添加 `--no-speech-threshold 0.6`；若发现轻声内容被漏掉，可降低至 `0.4`。 |

### 如何完全关闭防重复参数

如果某些视频内容特殊（如诗歌朗诵、歌词等），重复内容本身是合理的，可以在 `batchWhisper.sh` 中删除或注释掉对应的参数行即可。

---

## 8. 完全删除环境（不影响系统）

```bash
rm -rf ~/whisper-isolated
```

模型缓存默认在 `~/.cache/huggingface`，如需一并清理可执行：

```bash
rm -rf ~/.cache/huggingface
```

---

**当前正在运行的命令如果没有加 `--output-format srt`，生成的是 txt。**  
等它跑完后，直接用上面第 4 步的完整命令重新跑一次即可得到 SRT 文件。

---

# Windows 迁移可行性调研

> 本节内容写于 `Windows` 分支，供评估是否把整套功能迁移到 Windows 平台。当前 `master` 分支没有改动。
> **实际安装与使用步骤见 [README-Windows.md](README-Windows.md)**（面向不熟悉 Python 的读者）。

## 1. 核心结论

**原生 Windows 无法直接运行当前基于 `mlx-whisper` 的实现**，因为 `mlx` / `mlx-metal` 是 Apple Silicon + Metal 专用框架，PyPI 上没有 Windows wheel。但迁移本身是可行的——只要**把后端从 MLX 换成支持 Windows 的 Whisper 推理引擎**，并配套改写 `batchWhisper.sh`。

## 2. 按硬件场景的方案

### 场景 A：Windows + NVIDIA 显卡 + CUDA

| 方案 | 优势 | 劣势 | 推荐度 |
|---|---|---|---|
| **`faster-whisper` / `whisper-ctranslate2`** | 原生支持 Windows CUDA/CPU；比 OpenAI Whisper 快约 4 倍；显存占用更低 | 需要 CUDA 12 + cuBLAS/cuDNN 9；部分参数与 `mlx_whisper` 不完全一致 | ⭐⭐⭐ 首选 |
| **`openai-whisper` + PyTorch CUDA** | 命令行参数最接近 `mlx_whisper` | Windows 没有 `triton` 加速，速度慢、显存占用高 | ⭐⭐ 次选 |

- `whisper-ctranslate2` 是基于 `faster-whisper` 的 CLI 封装，接口刻意兼容 OpenAI Whisper，是替换 `mlx_whisper` 的较平滑选择。

### 场景 B：Windows 只有 CPU

| 方案 | 优势 | 劣势 | 推荐度 |
|---|---|---|---|
| **`faster-whisper` CPU（INT8）** | 原生 Windows；CPU 上明显快于 OpenAI Whisper | 大模型在 CPU 上仍较慢 | ⭐⭐⭐ 首选 |
| **`whisper.cpp` 独立可执行文件** | CPU 上速度最快、资源占用最低；已有 Windows 二进制 | CLI 参数差异大，脚本需重写 | ⭐⭐ 高性能首选 |
| **`openai-whisper` CPU** | 改动最小 | 纯 CPU 非常慢，不适合批量 | ⭐ 保底 |

## 3. 如果继续迁移，需要改动的地方

1. **`requirements.txt`**
   - 删除：`mlx`、`mlx-metal`、`mlx-whisper`
   - 新增：根据方案选择 `faster-whisper` / `whisper-ctranslate2` / `openai-whisper` + 对应 `torch`

2. **`batchWhisper.sh` → `batchWhisper.ps1` 或 `.bat`**
   - 替换 `find`、`basename`、`dirname`、`case` 等 bash 语法
   - 处理 Windows 路径和带空格文件名

3. **CLI 命令**
   - `mlx_whisper` 改成 `whisper` 或 `whisper-ctranslate2`
   - 模型名从 `mlx-community/whisper-*.mlx` 改成原始模型名，例如 `large-v3`、`distil-large-v3`

4. **参数差异**
   - 大部分参数（`--language`、`--output-format`、`--word-timestamps`、`--condition-on-previous-text`、`--compression-ratio-threshold` 等）通用。
   - `mlx_whisper` 的 `--output-name` 在 OpenAI / `whisper-ctranslate2` 中**不存在**，需要脚本输出到临时目录后再重命名。
   - 布尔值写法可能不同（`True/False` vs `true/false` 或无需值）。

5. **`ffmpeg`**
   - Windows 下用 winget、choco 或静态二进制安装，并加入 PATH，替代 `brew install ffmpeg`。

6. **模型下载**
   - `openai-whisper` 默认从 OpenAI CDN 下载，可能不再需要 HuggingFace Token。
   - `faster-whisper` 可用 HuggingFace 模型名或本地路径。

## 4. 备选：WSL2 保留 MLX

如果坚持保留 `mlx-whisper`，理论上可以在 **WSL2** 里通过 Linux 版 MLX（CUDA 或 CPU 后端）运行。但这不属于原生 Windows，会引入文件路径、GPU 透传和性能额外复杂度，**不建议作为主力方案**。

## 5. 推荐路径

- **最小改动 + NVIDIA/CPU 都覆盖**：用 `whisper-ctranslate2` 替换 `mlx-whisper`。
- **CPU 极限性能**：考虑 `whisper.cpp` 的 Windows 二进制，但脚本要重写。
- **保留 MLX 生态**：只能走 WSL2，不推荐。

## 6. 已实现的 Windows 版本

方案已落地并实测通过（GPU / CPU 两种模式），安装与使用步骤见：

👉 **[Windows 使用手册（README-Windows.md）](README-Windows.md)**

对应脚本为 [batchWhisper.ps1](batchWhisper.ps1)。

