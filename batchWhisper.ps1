#Requires -Version 5.1
# ============================================================================
# 批量视频字幕脚本 —— Windows + NVIDIA CUDA 版
#
# 后端：faster-whisper（通过 whisper-ctranslate2 CLI）
# 依赖：仓库根目录下的 .venv 虚拟环境
#
# 用法：
#   .\batchWhisper.ps1                         # 默认处理当前目录，语言 de
#   .\batchWhisper.ps1 D:\Movies ja            # 处理 D:\Movies，语言日语
#   .\batchWhisper.ps1 . en large-v3-turbo     # 使用 large-v3-turbo 模型
#   .\batchWhisper.ps1 . ja large-v3 cpu       # 强制使用 CPU 推理
#
# 设备（第 4 个参数）：
#   auto = 默认。检测到可用 CUDA 显卡就用 GPU，否则自动退回 CPU
#   cuda = 强制 GPU（float16）
#   cpu  = 强制 CPU（int8）
# ============================================================================

param(
    [string]$TargetDir = ".",
    [string]$LangCode = "de",
    [string]$Model = "large-v3",
    [ValidateSet("auto", "cuda", "cpu")]
    [string]$Device = "auto"
)

# ----------------------------------------------------------------------------
# 定位 whisper-ctranslate2 可执行文件（使用仓库自带 .venv）
# ----------------------------------------------------------------------------
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$whisper = Join-Path $scriptDir ".venv\Scripts\whisper-ctranslate2.exe"

if (-not (Test-Path $whisper)) {
    Write-Error "未找到 $whisper。请先创建 .venv 并安装依赖：py -3.12 -m venv .venv && .venv\Scripts\pip install -r requirements.txt"
    exit 1
}

# ----------------------------------------------------------------------------
# 把 pip 安装的 CUDA runtime DLL 目录加入 PATH，否则 CTranslate2 找不到 cublas64_12.dll
# ----------------------------------------------------------------------------
$sitePackages = Join-Path $scriptDir ".venv\Lib\site-packages"
$cudaBinDirs = @(
    Join-Path $sitePackages "nvidia\cublas\bin"
    Join-Path $sitePackages "nvidia\cudnn\bin"
    Join-Path $sitePackages "nvidia\cuda_nvrtc\bin"
) | Where-Object { Test-Path $_ }

if ($cudaBinDirs) {
    $env:PATH = ($cudaBinDirs -join ";") + ";" + $env:PATH
}

# ----------------------------------------------------------------------------
# 设备自动检测：有可用 CUDA 显卡用 GPU，否则退回 CPU
# ----------------------------------------------------------------------------
$pythonExe = Join-Path $scriptDir ".venv\Scripts\python.exe"

if ($Device -eq "auto") {
    $cudaCount = & $pythonExe -c "import ctranslate2; print(ctranslate2.get_cuda_device_count())" 2>$null
    if ($cudaCount -match '^\d+$' -and [int]$cudaCount -gt 0) {
        $Device = "cuda"
    }
    else {
        $Device = "cpu"
    }
}

if ($Device -eq "cuda") {
    $computeType = "float16"
}
else {
    $computeType = "int8"
}

Write-Host "推理设备: $Device（compute_type=$computeType）"

# ----------------------------------------------------------------------------
# 语言开关 —— 换语言只改运行参数，无需再动其他地方。
#   de = 德语   es = 西班牙语   en = 英语   yue = 粤语   ja = 日语
# ----------------------------------------------------------------------------
switch ($LangCode) {
    "de" {
        $initialPrompt = "Dies ist ein Dialog aus einem deutschen Film. Bitte transkribieren Sie alles wörtlich und vollständig. Lassen Sie keine Füllwörter oder Interjektionen weg (z. B. äh, ähm, na ja, also, hmm) und auch keine gedehnten Laute (z. B. ahhh, oooch). Verwenden Sie natürliche deutsche Satzzeichen."
    }
    "es" {
        $initialPrompt = "Es un diálogo de una película en español. Transcríbalo todo de forma literal y completa. No omita muletillas ni interjecciones (por ejemplo, este, bueno, o sea, em, eh, mmm) ni sonidos alargados (por ejemplo, ahhh, nooo). Use signos de puntuación naturales del español, incluidos ¿ y ¡."
    }
    "en" {
        $initialPrompt = "This is dialogue from an English-language film. Please transcribe everything verbatim and completely. Do not omit filler words or interjections (e.g. um, uh, like, you know, hmm) or drawn-out sounds (e.g. ahhh, nooo). Use natural English punctuation."
    }
    "yue" {
        $initialPrompt = "呢套係粵語電影嘅對白。請逐字完整轉寫，保留粵語口語用字（嘅、咗、喺、唔、嘞、囉等），唔好省略語氣詞同感嘆詞（啊、呀、㗎、咩、喎、啩、吓、嗯、呃），亦都唔好省略拉長嘅發音。請用繁體中文同自然標點符號。"
    }
    "ja" {
        $initialPrompt = "日本語の映画の会話です。あいづちや感動詞（あー、うーん、ええと、ん等）や、伸ばす発音も省略せずそのまま文字起こししてください。句点や読点など自然な日本語の句読点を使ってください。"
    }
    default {
        Write-Error "不支持的语言代码: '$LangCode'（可选：de 德语 / es 西班牙语 / en 英语 / yue 粤语 / ja 日语）"
        exit 1
    }
}

Write-Host "语言开关 LANG_CODE=$LangCode，已自动选用对应初始提示词。"

# ----------------------------------------------------------------------------
# 递归查找 .mp4 / .mkv / .wav
# ----------------------------------------------------------------------------
$mediaFiles = Get-ChildItem -Path $TargetDir -Recurse -File -Include "*.mp4", "*.mkv", "*.wav"

if (-not $mediaFiles) {
    Write-Warning "在 $TargetDir 下未找到 .mp4 / .mkv / .wav 文件"
    exit 0
}

foreach ($fileItem in $mediaFiles) {
    $file = $fileItem.FullName
    $outputDir = $fileItem.DirectoryName

    Write-Host "=========================================="
    Write-Host "正在处理视频: $file"

    # whisper-ctranslate2 会自动以输入文件名为基础生成输出文件，因此不需要 --output_name
    $whisperArgs = @(
        $file
        "--model", $Model
        "--language", $LangCode
        "--task", "transcribe"
        "--output_format", "srt"
        "--output_dir", $outputDir
        "--verbose", "True"
        "--word_timestamps", "True"
        "--max_line_width", "14"
        "--max_line_count", "1"
        "--initial_prompt", $initialPrompt
        "--condition_on_previous_text", "False"
        "--hallucination_silence_threshold", "2.0"
        "--compression_ratio_threshold", "2.4"
        "--logprob_threshold", "-1.0"
        "--no_speech_threshold", "0.7"
        "--temperature", "0"
        "--best_of", "5"
        "--device", $Device
        "--compute_type", $computeType
    )

    & $whisper @whisperArgs

    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ 处理成功: $file"
    }
    else {
        Write-Host "❌ 处理失败: $file"
    }
}
