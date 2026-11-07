#Requires -Version 5.1
<#
    Install the faster-whisper stack on Windows.

    Works with the system Python 3.15 (which has no wheels for
    onnxruntime and pyyaml) and also with Python 3.11/3.12.

    Usage:
        .\install-windows.ps1            # install with NVIDIA CUDA runtime
        .\install-windows.ps1 -CpuOnly   # CPU-only machine, skip NVIDIA libs
#>
param(
    [switch]$CpuOnly
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

function Step([string]$text) {
    Write-Host "==> $text" -ForegroundColor Cyan
}

Step "Python version"
python --version

$py = Join-Path $root ".venv\Scripts\python.exe"
if (-not (Test-Path $py)) {
    Step "Creating virtual environment .venv"
    python -m venv .venv
}

Step "Upgrading pip"
& $py -m pip install --upgrade pip

# onnxruntime is only needed by the VAD filter (off by default), and has
# no wheel for Python 3.15. Install the two entry packages without deps.
Step "Installing whisper-ctranslate2 / faster-whisper (no onnxruntime)"
& $py -m pip install --no-deps whisper-ctranslate2==0.5.8 faster-whisper==1.2.1

# av 18/19 dropped the `metadata_errors` argument used by faster-whisper 1.2.1,
# so av must stay on 17.x.
Step "Installing pinned runtime packages"
& $py -m pip install --no-deps av==17.0.0 ctranslate2==4.8.5 numpy==2.5.4 tokenizers==0.23.3 tqdm sounddevice huggingface_hub==0.36.0

Step "Installing pure-python dependencies"
& $py -m pip install requests urllib3 certifi charset-normalizer idna filelock fsspec packaging typing-extensions

if ($CpuOnly) {
    Write-Host "==> Skipping NVIDIA CUDA runtime (-CpuOnly)" -ForegroundColor Yellow
} else {
    Step "Installing NVIDIA CUDA runtime"
    & $py -m pip install nvidia-cublas-cu12 nvidia-cudnn-cu12
}

# pyyaml has no wheel for Python 3.15 and its sdist needs MSVC. The sdist
# ships a complete pure-python implementation under lib/yaml; copy it in.
Step "Installing pure-python pyyaml"
$yamlDir = Join-Path $root ".venv\Lib\site-packages\yaml"
if (-not (Test-Path (Join-Path $yamlDir "__init__.py"))) {
    $meta = Invoke-RestMethod "https://pypi.org/pypi/pyyaml/6.0.3/json"
    $sdist = ($meta.urls | Where-Object { $_.packagetype -eq "sdist" }).url
    $tarball = Join-Path $env:TEMP "pyyaml-6.0.3.tar.gz"
    Invoke-WebRequest $sdist -OutFile $tarball
    tar -xzf $tarball -C $env:TEMP
    Copy-Item (Join-Path $env:TEMP "pyyaml-6.0.3\lib\yaml") $yamlDir -Recurse -Force
}

Step "Verifying installation"
& $py -c "import av, ctranslate2, faster_whisper, whisper_ctranslate2; print('av', av.__version__); print('CUDA devices', ctranslate2.get_cuda_device_count())"

Write-Host ""
Write-Host "Done. Next: .\batchWhisper.ps1 . en tiny" -ForegroundColor Green
