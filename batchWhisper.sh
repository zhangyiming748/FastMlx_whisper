#!/bin/bash

# 1. 使用 find 命令查找当前目录及所有子目录下的 .mp4 文件
# -type f: 仅查找普通文件
# -iname "*.mp4": 忽略大小写匹配 .mp4 后缀
# 使用 while read 循环代替 for 循环，以安全处理文件名中包含空格或特殊字符的情况
find . -type f -iname "*.mp4" | while IFS= read -r file; do
    echo "=========================================="
    echo "正在处理视频: $file"
    
    # 2. 执行 mlx_whisper 命令
    # 将当前文件路径作为第一个参数传入
    mlx_whisper "$file" \
      --model mlx-community/whisper-medium.en-mlx \
      --language en \
      --output-format srt \
      --output-dir .
      
    # 可选：检查上一个命令是否执行成功
    if [ $? -eq 0 ]; then
        echo "✅ 处理成功: $file"
    else
        echo "❌ 处理失败: $file"
    fi
done