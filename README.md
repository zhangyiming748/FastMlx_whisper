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

## 7. 完全删除环境（不影响系统）

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