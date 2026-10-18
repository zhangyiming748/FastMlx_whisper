#!/bin/bash

# ============================================================================
# 批量视频字幕脚本 —— 日语电影专项调优版
#
# 针对的两个痛点：
#   1. 语气词多（あいづち / 感動詞：あー、うん、ええと、ん……）
#      → 这些词发音短、置信度低，最容易被模型当"静音/失败段"丢掉。
#      → 对策：--no-speech-threshold 调高、--logprob-threshold 放宽、
#        --initial-prompt 显式要求保留语气词。
#
#   2. 拉长发音（伸ばす音：あーーー、うーん……）
#      → 长音重复会让压缩比升高，反而可能被当成"复读幻觉"。
#      → 对策：保留 --compression-ratio-threshold 2.4（触发自动升温重试，
#        让模型重解码，而不是硬删）；--word-timestamps True 拿到词级时间轴；
#        --suppress-tokens 保持 -1 不动（长音符「ー」是正常假名词，不会被抑制）。
#
# 其他日语电影常见问题：
#   - 沉默长镜头里 Whisper 容易脑补出假字幕（幻觉）
#     → --hallucination-silence-threshold 2.0（必须配合词级时间戳才生效）
#   - 前一段错误文字污染后一段，造成整段复读
#     → --condition-on-previous-text False
#
# 提示：布尔值必须严格写 True / False（首字母大写），写 true/false 会报错。
# ============================================================================

# 指定要处理的目录，默认为当前目录
TARGET_DIR="${1:-.}"

# ============================================================================
# 语言开关 —— 换语言只改这一处（或运行时用第 2 个参数临时指定），无需再动其他地方。
#   de = 德语   es = 西班牙语   en = 英语   ja = 日语
# 例：
#   ./batchWhisper.sh                # 用下面默认语言处理当前目录
#   ./batchWhisper.sh /movies ja     # 临时用日语处理 /movies
#   ./batchWhisper.sh . en           # 临时用英语处理当前目录
LANG_CODE="${2:-de}"
#
# 下面按 LANG_CODE 自动选用"用该语言本身书写"的初始提示词。
# 初始提示词只作用于第一个 30 秒窗口，用来"定调"（文体、标点风格、语气词写法）。
# Whisper 会模仿这段话的语言和标点风格，所以每种语言都用母语书写，
# 并统一要求：电影对白、逐字完整转写、保留填充词/语气词/拉长发音、不省略。
# 若是特定系列电影，可在对应分支里追加人名/专有名词的正确写法。
case "$LANG_CODE" in
    de) # 德语
        INITIAL_PROMPT="Dies ist ein Dialog aus einem deutschen Film. Bitte transkribieren Sie alles wörtlich und vollständig. Lassen Sie keine Füllwörter oder Interjektionen weg (z. B. äh, ähm, na ja, also, hmm) und auch keine gedehnten Laute (z. B. ahhh, oooch). Verwenden Sie natürliche deutsche Satzzeichen."
        ;;
    es) # 西班牙语
        INITIAL_PROMPT="Es un diálogo de una película en español. Transcríbalo todo de forma literal y completa. No omita muletillas ni interjecciones (por ejemplo, este, bueno, o sea, em, eh, mmm) ni sonidos alargados (por ejemplo, ahhh, nooo). Use signos de puntuación naturales del español, incluidos ¿ y ¡."
        ;;
    en) # 英语
        INITIAL_PROMPT="This is dialogue from an English-language film. Please transcribe everything verbatim and completely. Do not omit filler words or interjections (e.g. um, uh, like, you know, hmm) or drawn-out sounds (e.g. ahhh, nooo). Use natural English punctuation."
        ;;
    ja) # 日语
        INITIAL_PROMPT="日本語の映画の会話です。あいづちや感動詞（あー、うーん、ええと、ん等）や、伸ばす発音も省略せずそのまま文字起こししてください。句点や読点など自然な日本語の句読点を使ってください。"
        ;;
    *)
        echo "❌ 不支持的语言代码: '$LANG_CODE'（可选：de 德语 / es 西班牙语 / en 英语 / ja 日语）" >&2
        exit 1
        ;;
esac
echo "语言开关 LANG_CODE=${LANG_CODE}，已自动选用对应初始提示词。"

# find 查找指定目录及所有子目录下的 .mp4 / .mkv / .wav 文件
# -type f 仅匹配普通文件；-iname 忽略大小写
# while IFS= read -r 可安全处理带空格/特殊字符的文件名
find "$TARGET_DIR" -type f \( -iname "*.mp4" -o -iname "*.mkv" -o -iname "*.wav" \) | while IFS= read -r file; do
    echo "=========================================="
    echo "正在处理视频: $file"

    # 输出文件名：去掉最后一个扩展名（保留文件名中其余的点）
    output_name="$(basename "$file")"
    output_name="${output_name%.*}"

    # 字幕输出到源文件所在目录，与视频同层级
    output_dir="$(dirname "$file")"

    # ------------------------------------------------------------------------
    # 用数组组装参数：数组里每一行后面可以直接写 # 注释。
    # 注意：不要在旧写法的 " \" 续行中间插注释行，# 会把后面整段命令注释掉。
    # ------------------------------------------------------------------------
    WHISPER_ARGS=(
        # 【模型】本地模型目录或 Hugging Face 仓库名。
        # large-v3 是当前精度最高的开源 Whisper 模型，日语语气词/长音识别最稳；
        # 嫌慢可换 mlx-community/whisper-large-v3-turbo（快很多，精度略低）。
        --model mlx-community/whisper-large-v3-mlx

        # 【语言】强制指定源语言，跳过自动检测。这里引用顶部的开关 $LANG_CODE，
        # 与初始提示词自动保持一致，不要再手动改这一行，改顶部 LANG_CODE 即可。
        # 参数值为 ISO-639-1 小写两字母代码；电影背景音复杂时自动检测偶尔会误判，
        # 固定语言可避免整盘字幕语言漂移。
        #
        # 常用语言代码（Whisper 共支持 99 种，这是高频子集）：
        #   de=德语   ja=日语   en=英语   zh=中文   fr=法语   es=西班牙语
        #   ru=俄语   ko=韩语   it=意大利语  pt=葡萄牙语  nl=荷兰语
        #   ar=阿拉伯语  hi=印地语  tr=土耳其语  pl=波兰语   sv=瑞典语
        #   fi=芬兰语  da=丹麦语  no=挪威语(nn=新挪威语) cs=捷克语  el=希腊语
        #   he=希伯来语  hu=匈牙利语  id=印尼语  th=泰语    uk=乌克兰语
        #   vi=越南语  ro=罗马尼亚语 ca=加泰罗尼亚语
        #
        # 全部 99 种语言代码（按代码字母排序，代码 = 英文名称）：
        #   af=afrikaans        am=amharic          ar=arabic
        #   as=assamese         az=azerbaijani      ba=bashkir
        #   be=belarusian       bg=bulgarian        bn=bengali
        #   bo=tibetan          br=breton           bs=bosnian
        #   ca=catalan          cs=czech            cy=welsh
        #   da=danish           de=german           el=greek
        #   en=english          es=spanish          et=estonian
        #   eu=basque           fa=persian          fi=finnish
        #   fo=faroese          fr=french           gl=galician
        #   gu=gujarati         ha=hausa            haw=hawaiian
        #   he=hebrew           hi=hindi            hr=croatian
        #   ht=haitian creole   hu=hungarian        hy=armenian
        #   id=indonesian       is=icelandic        it=italian
        #   ja=japanese         jw=javanese         ka=georgian
        #   kk=kazakh           km=khmer            kn=kannada
        #   ko=korean           la=latin            lb=luxembourgish
        #   ln=lingala          lo=lao              lt=lithuanian
        #   lv=latvian          mg=malagasy         mi=maori
        #   mk=macedonian       ml=malayalam        mn=mongolian
        #   mr=marathi          ms=malay            mt=maltese
        #   my=myanmar          ne=nepali           nl=dutch
        #   nn=nynorsk          no=norwegian        oc=occitan
        #   pa=punjabi          pl=polish           ps=pashto
        #   pt=portuguese       ro=romanian         ru=russian
        #   sa=sanskrit         sd=sindhi           si=sinhala
        #   sk=slovak           sl=slovenian        sn=shona
        #   so=somali           sq=albanian         sr=serbian
        #   su=sundanese        sv=swedish          sw=swahili
        #   ta=tamil            te=telugu           tg=tajik
        #   th=thai             tk=turkmen          tl=tagalog
        #   tr=turkish          tt=tatar            uk=ukrainian
        #   ur=urdu             uz=uzbek            vi=vietnamese
        #   yi=yiddish          yo=yoruba           zh=chinese
        #
        # 提示：这里固定使用顶部 $LANG_CODE 指定的语言；电影背景音复杂，不建议自动检测。
        --language "$LANG_CODE"

        # 【任务】transcribe = 原文转写（日语进日语出）。
        # 另一个值 translate 会把任何语言翻译成英语，且往往丢掉语气词，电影字幕不要用。
        --task transcribe

        # 【输出格式】srt = 标准字幕（序号 + 时间轴 + 文本）。
        # 可选：txt / vtt / tsv / json / all（all = 一次导出全部格式）。
        --output-format srt

        # 【输出目录与文件名（不含扩展名，格式后缀自动追加）】
        --output-dir "$output_dir"
        --output-name "$output_name"

        # 【详细日志】True 时会先打印完整参数 dict，并逐条输出识别到的文本段、
        # 置信度、是否触发升温重试——调优阶段强烈建议开着。
        # 批量稳定运行后嫌刷屏可以改 False。
        --verbose True

        # 【词级时间戳】本脚本最关键的开关之一。
        # ① 长音/语气词能拿到更精确的起止时间；
        # ② 下面的字幕自动断行（max-line-*）和幻觉静音跳过
        #    （hallucination-silence-threshold）全部依赖它，不开则全部不生效；
        # ③ 代价是速度略慢。日语的"词"按短语切分，偶尔偏粗，属正常现象。
        --word-timestamps True

        # 【字幕排版：强制"一个时间轴只有一行"，绝不出现双行/多行】
        # max-line-count 1 是关键：一条字幕最多 1 行。
        #   - 旧写法 count=2 时，超过宽度的内容会被插入换行符 "\n" 挤成同一条
        #     字幕里的第二行 → 表现为"同一时间轴出现双行字幕"。
        #   - 改成 1 之后，超宽内容不会再塞进同一行，而是按词级时间戳拆成
        #     "下一条独立字幕"（拥有自己的起止时间轴），从根上杜绝多行。
        #
        # max-line-width 此时的含义 = 单条字幕的最大字符数（超出就拆成下一条）。
        #   日语可取 12～16；德语复合词长、句子长，14 会切得过碎导致字幕频繁跳动，
        #   建议 30～42（一行能容纳一个较完整的短句）。
        #
        # 前提：必须 word-timestamps=True，否则这两个参数都不生效
        # （不生效时整条 segment 直接输出，可能很长，由播放器自行视觉折行）。
        # 注意：width 只控制"写入的换行/拆条"，某条仍超过屏幕宽度时播放器可能
        # 自行视觉折行，那是播放器行为；想更保险就把这个值再调小。
        # --max-line-width 40
        --max-line-count 1

        # 【初始提示词】见文件顶部 INITIAL_PROMPT 的说明。
        --initial-prompt "$INITIAL_PROMPT"

        # 【是否以上一段输出作为下一段提示】
        # True：跨窗口文本更连贯，但一旦某段识别错（尤其语气词听错），
        #       错误会被带进下一段并可能引发整段"复读机"；
        # False：每段独立解码，不易陷入复读循环。电影对白窗口之间本来就常切换，
        #        连贯性收益小，故关闭（这也是原脚本就有的设置，保留）。
        --condition-on-previous-text False

        # 【幻觉静音阈值 / 秒】检测到疑似幻觉时，跳过长度超过该值的静音段。
        # 电影里沉默、留白、纯配乐镜头很容易被 Whisper 脑补出
        # 「ありがとうございました」「字幕お願いします」之类假字幕，本参数专治这个。
        # 必须 word-timestamps=True 才生效（原脚本写了 30 但当时没开词级时间戳，
        # 实际完全没生效）。推荐值：
        #   2.0 = 积极清除（电影推荐起始值）
        #   1.0 = 更激进，可能误删正常的停顿留白
        #   30  = 几乎只在超长静音才动作，约等于关闭
        --hallucination-silence-threshold 2.0

        # 【压缩比阈值】对识别结果做 gzip，压缩比高于此值就判定为解码失败
        # （典型失败：同一句话/同一个音无限重复）。
        # 拉长音「あーーー」压缩比偏高，触发后模型会自动升高温度重新解码，
        # 通常能把病态重复纠正回来，所以保持默认 2.4 即可。
        # 如果 verbose 日志里正常台词频繁触发重试，可放宽到 2.6～2.8。
        --compression-ratio-threshold 2.4

        # 【平均对数概率阈值】整段的平均 log 概率低于此值 → 判为失败并重试。
        # 数值越负越宽松（保留更多低置信内容），越接近 0 越严格。
        # 小声的语气词置信度天然偏低，保持默认 -1.0；
        # 如果发现「…ん」「…あ」这类轻声语气词仍然丢，可放宽到 -1.5 ~ -2.0，
        # 代价是背景噪声被误识别成文字的概率上升。
        --logprob-threshold -1.0

        # 【无语音阈值】当解码已因 logprob 判失败、且该段"无语音 token"概率
        # 高于此值时，整段按静音丢弃（不出字幕）。
        # 调高 → 更不容易被当成静音 → 更能保住短促、轻声的语气词；
        # 调低 → 更多片段被当静音吞掉。
        # 默认为 0.6，为保语气词这里微调到 0.7；
        # 如果噪声环境误字幕变多，调回 0.6。
        --no-speech-threshold 0.7

        # 【采样温度】0 = 贪婪解码，结果最稳定、可复现，转写首选。
        # 当某段被判失败时，模型内部会自动以 0.2 步长升温重试
        # （0.2 → 0.4 → … → 1.0），无需手动设置，verbose 日志里能看到过程。
        --temperature 0

        # 【候选数】非零温度采样时每步保留的候选数量。
        # temperature=0 的首轮解码用不到它，但自动升温重试时生效，保留默认 5。
        --best-of 5
    )

    # 执行转写（数组展开可安全处理含空格的路径）
    mlx_whisper "$file" "${WHISPER_ARGS[@]}"

    # 检查退出状态：0 = 成功
    if [ $? -eq 0 ]; then
        echo "✅ 处理成功: $file"
    else
        echo "❌ 处理失败: $file"
    fi
done

# ============================================================================
# 未在上面显式写出的参数（全部使用默认值，需要时按说明自行加入数组）：
#
# --fp16 True
#   是否半精度推理。MLX 后端会自行管理精度，保持 True 即可。
#
# --suppress-tokens -1
#   解码时抑制的 token id（逗号分隔）。-1 = 抑制除常见标点外的特殊符号，
#   防止输出乱码符号。日语长音符「ー」、句号「。」、顿号「、」都不受影响，
#   不要随意改，改了容易出 @#$% 之类乱码。
#
# --patience None（等价 1.0）
#   beam search 耐心值。当前解码路径基本不受益，保持默认。
#
# --length-penalty None
#   长度惩罚系数 α。None = 使用简单长度归一化，默认即可。
#
# --highlight-words False
#   卡拉OK效果：srt/vtt 中给当前正在念的词加下划线，需要 word-timestamps。
#   做普通电影字幕保持 False。
#
# --max-words-per-line None
#   每行最大"词数"。注意：它与 --max-line-width 互斥（设了 width 它就失效），
#   日语按"字数"排版比按词数合理，故不使用。
#
# --prepend-punctuations / --append-punctuations
#   词级时间戳下，标点向前/向后吸附的符号表，默认值已包含
#   。、！？：「」（）等日文标点，日语无需修改。
#
# --clip-timestamps 0
#   只转写指定片段，格式 起,止,起,止,...（秒），最后一个止可省略（到文件结尾）。
#   默认 "0" = 整片。只想测试某一段时非常好用，例如：
#   --clip-timestamps 600,720        只转第 10～12 分钟
#
# --output-format all
#   想要 srt 之外再同时拿到 txt/json 时，把上面的 srt 换成 all。
# ============================================================================
