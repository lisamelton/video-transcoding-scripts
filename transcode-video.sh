#!/bin/bash
#
# transcode-video.sh
#
# Copyright (c) 2013-2014 Don Melton
#

about() {
    cat <<EOF
$program 4.0 of October 23, 2014
Copyright (c) 2013-2014 Don Melton
EOF
    exit 0
}

usage_prologue() {
    cat <<EOF
Transcode video file or disc image directory into format and size similar to
popular online downloads. Works best with Blu-ray or DVD rip.

Automatically determines target video bitrate, number of audio tracks, etc.
WITHOUT ANY command line options.

Usage: $program [OPTION]... [FILE|DIRECTORY]

    --help          display basic options and exit
    --fullhelp      display ALL options and exit

EOF
}

usage() {
    usage_prologue
    cat <<EOF
    --title NUMBER  select numbered title in video media (default: 1)
                        (\`0\` to scan media, list title numbers and exit)
    --mkv           output Matroska format instead of MP4
    --big           raise default limits for both video and AC-3 audio bitrates
                        (always increases output size)
    --fast, --faster, --veryfast
                    use x264 encoder preset to trade quality for speed
                        (mitigate quality loss by combining with \`--big\`)
    --slow, --slower, --veryslow
                    use x264 encoder preset to trade speed for compression
                        (can also improve quality)
    --crop T:B:L:R  set video croping bounds (default: 0:0:0:0)
                        (use \`detect-crop.sh\` script for optimal bounds)
                        (use \`--crop auto\` for \`HandBrakeCLI\` behavior)
    --720p          constrain video to fit within 1280x720 pixel bounds
    --audio TRACK   select audio track identified by number (default: 1)
    --burn TRACK    burn subtitle track identified by number
                        (default: first forced subtitle, if any)

    --version       output version information and exit

Requires \`HandBrakeCLI\` executable in \$PATH.
Output and log file are written to current working directory.
EOF
    exit 0
}

usage_full() {
    usage_prologue
    cat <<EOF
Input options:
    --title NUMBER  select numbered title in video media (default: 1)
                        (\`0\` to scan media, list title numbers and exit)
    --chapters NUMBER[-NUMBER]
                    select chapters, single or range (default: all)

Output options:
    --mkv           output Matroska format instead of MP4
    --m4v           output MP4 with \`.m4v\` extension instead of \`.mp4\`

Quality options:
    --big           raise default limits for both video and AC-3 audio bitrates
                        (always increases output size)
    --fast, --faster, --veryfast
                    use x264 encoder preset to trade quality for speed
                        (mitigate quality loss by combining with \`--big\`)
    --slow, --slower, --veryslow
                    use x264 encoder preset to trade speed for compression
                        (can also improve quality)

Video options:
    --crop T:B:L:R  set video croping bounds (default: 0:0:0:0)
                        (use \`detect-crop.sh\` script for optimal bounds)
                        (use \`--crop auto\` for \`HandBrakeCLI\` behavior)
    --720p          constrain video to fit within 1280x720 pixel bounds
    --rate FPS      force video frame rate (default: based on input)

Audio options:
    --audio TRACK   select audio track identified by number (default: 1)
    --add-audio TRACK[,NAME]
                    add audio track in AAC format with optional name
                        (can be used multiple times)
    --ac3 BITRATE   set AC-3 audio bitrate to 384|448|640 kbps (default: 384)
    --pass-ac3 BITRATE
                    set passthru AC-3 audio <= 384|448|640 kbps (default: 448)
    --no-ac3        don't output multi-channel AC-3 audio

Subtitle options:
    --burn TRACK    burn subtitle track identified by number
                        (default: first forced subtitle, if any)
    --srt [ENCODING,][OFFSET,][LANGUAGE,][forced,]FILENAME
                    add subtitle track from SubRip-format \`.srt\` text file
                        with optional character set encoding (default: latin1)
                        with optional +/- offset in milliseconds (default: 0)
                        with optional ISO 639-2 language code (default: und)
                        with optional forced playback flag
                        (values before filename can appear in any order)
                        (can be used multiple times)

Advanced options:
    --preset NAME   use x264 ...|fast|medium|slow|... preset (default: medium)
                        (refer to \`HandBrakeCLI --help\` for complete list)
    --tune NAME     use x264 film|animation|grain|... tune
                        (refer to \`HandBrakeCLI --help\` for complete list)
    --max BITRATE   set maximum video bitrate (default: based on input)
                        (can be exceeded to maintain video quality)
    --vbv-bufsize SIZE
                    set video buffer size (default: 50% of maximum bitrate)
    --add-encopts OPTION=VALUE[:OPTION=VALUE...]
                    specify additional x264 encoder options
    --crf FACTOR    set constant rate factor (default: 16)
    --crf-max FACTOR
                    set maximum constant rate factor (default: 25)
                        (use \`--crf-max none\` to disable)
    --filter NAME[=SETTINGS]
                    apply \`HandBrakeCLI\` video filter with optional settings
                        (refer to \`HandBrakeCLI --help\` for more information)
                        (can be used multiple times)
    --no-auto-detelecine
                    don't automatically apply \`detelecine\` filter
                        to 29.97 fps video
    --no-auto-burn  don't automatically burn first forced subtitle

Passthru options:
    --angle, --start-at, --stop-at, --normalize-mix, --drc, --gain,
    --no-opencl, --optimize, --use-opencl, --use-hwd, --srt-burn
                    all passed through to \`HandBrakeCLI\` unchanged 
                        (refer to \`HandBrakeCLI --help\` for more information)

Other options:
    --version       output version information and exit

Requires \`HandBrakeCLI\` executable in \$PATH.
May require \`mkvpropedit\` executable in \$PATH for \`--srt\` option.
Output and log file are written to current working directory.
EOF
    exit 0
}

syntax_error() {
    echo "$program: $1" >&2
    echo "Try \`$program --help\` for more information." >&2
    exit 1
}

die() {
    echo "$program: $1" >&2
    exit ${2:-1}
}

deprecated() {
    echo "$program: deprecated option: $1" >&2
}

deprecated_and_replaced() {
    deprecated $1
    echo "$program: use this option instead: $2" >&2
}

readonly program="$(basename "$0")"

case $1 in
    --help)
        usage
        ;;
    --fullhelp)
        usage_full
        ;;
    --version)
        about
        ;;
esac

debug=''
title='1'
chapters_options=''
container_format='mp4'
container_format_options='--large-file'
preset='medium'
tune_options=''
max_bitrate=''
vbv_bufsize=''
extra_encoder_options=''
rate_factor='16'
max_rate_factor='25'
constrain_to_1280x720=''
frame_rate_options=''
audio_track='1'
extra_audio_track_list=''
extra_audio_track_name_list=''
ac3_bitrate='384'
pass_ac3_bitrate='448'
crop_options='--crop 0:0:0:0'
filter_options=''
auto_detelecine='yes'
subtitle_track=''
auto_burn='yes'
srt_count='0'
srt_forced_index='0'
srt_file_list=''
srt_codeset_list=''
srt_offset_list=''
srt_lang_list=''
tmp=''
default_max_bitrate_1080p='5000'
default_max_bitrate_720p='4000'
default_max_bitrate_480p='2000'
passthru_options=''

while [ "$1" ]; do
    case $1 in
        --debug)
            debug='yes'
            ;;
        --title)
            title="$(printf '%.0f' "$2")"
            shift

            if (($title < 0)); then
                die "invalid title number: $title"
            fi
            ;;
        --chapters)
            chapters_options="--chapters $2"
            shift
            ;;
        --mkv)
            container_format='mkv'
            container_format_options=''
            ;;
        --m4v)
            container_format='m4v'
            container_format_options='--large-file'
            ;;
        --preset|--veryfast|--faster|--fast|--slow|--slower|--veryslow)

            if [ "$1" == '--preset' ]; then
                preset="$2"
                shift
            else
                preset="${1:2}"
            fi
            ;;
        --tune)
            tune_options="$(echo "$tune_options --x264-tune $2" | sed 's/^ *//')"
            shift
            ;;
        --max|--vbv-maxrate|--abr)
            [ "$1" == '--abr' ] && deprecated_and_replaced "$1" '--max'
            max_bitrate="$(printf '%.0f' "$2")"
            shift

            if (($max_bitrate < 1)); then
                die "invalid maximum video bitrate: $max_bitrate"
            fi
            ;;
        --vbv-bufsize)
            vbv_bufsize="$(printf '%.0f' "$2")"
            shift

            if (($vbv_bufsize < 1)); then
                die "invalid video buffer size: $vbv_bufsize"
            fi
            ;;
        --add-encopts)
            extra_encoder_options="$2"
            shift
            ;;
        --crf)
            rate_factor="$(printf '%.2f' "$2" | sed 's/0*$//;s/\.$//')"
            shift

            if (($rate_factor < 0)); then
                die "invalid constant rate factor: $rate_factor"
            fi
            ;;
        --crf-max)
            max_rate_factor="$2"
            shift

            case $max_rate_factor in
                none)
                    max_rate_factor=''
                    ;;
                *)
                    max_rate_factor="$(printf '%.2f' "$max_rate_factor" | sed 's/0*$//;s/\.$//')"

                    if (($max_rate_factor < 0)); then
                        die "invalid maximum constant rate factor: $max_rate_factor"
                    fi
                    ;;
            esac
            ;;
        --hq)
            deprecated "$1"
            ;;
        --720p|--resize)
            [ "$1" == '--resize' ] && deprecated_and_replaced "$1" '--720p'
            constrain_to_1280x720='yes'
            ;;
        --rate)
            frame_rate_options="--rate $(printf '%.3f' "$2" | sed 's/0*$//;s/\.$//')"
            shift
            ;;
        --audio)
            audio_track="$(printf '%.0f' "$2")"
            shift

            if (($audio_track < 1)); then
                die "invalid audio track: $audio_track"
            fi
            ;;
        --add-audio)
            extra_audio_track="$(printf '%.0f' "$(echo "$2" | sed 's/,.*$//')")"

            if [[ "$2" =~ ',' ]]; then
                extra_audio_track_name="$(echo "$2" | sed 's/^[^,]*,//')"
            else
                extra_audio_track_name=''
            fi
            shift

            if (($extra_audio_track < 1)); then
                die "invalid additional audio track: $extra_audio_track"
            fi

            extra_audio_track_list="${extra_audio_track_list},$extra_audio_track"
            extra_audio_track_name_list="${extra_audio_track_name_list},$extra_audio_track_name"
            ;;
        --ac3)
            ac3_bitrate="$2"
            shift

            case $ac3_bitrate in
                384|448|640)
                    ;;
                *)
                    syntax_error "unsupported AC-3 audio bitrate: $ac3_bitrate"
                    ;;
            esac
            ;;
        --pass-ac3)
            pass_ac3_bitrate="$2"
            shift

            case $pass_ac3_bitrate in
                384|448|640)
                    ;;
                *)
                    syntax_error "unsupported AC-3 audio passthru bitrate: $pass_ac3_bitrate"
                    ;;
            esac
            ;;
        --no-ac3|--no-surround)
            [ "$1" == '--no-surround' ] && deprecated_and_replaced "$1" '--no-ac3'
            ac3_bitrate=''
            ;;
        --crop)
            crop="$2"
            shift

            if [ "$crop" == 'auto' ]; then
                crop_options=''
            else
                crop_options="--crop $crop"
            fi
            ;;
        --filter)
            filter="$2"
            shift

            filter_name="$(echo "$filter" | sed 's/=.*$//')"

            case $filter_name in
                deinterlace|decomb|denoise|nlmeans|nlmeans-tune|deblock|rotate|grayscale)
                    ;;
                detelecine)
                    auto_detelecine=''
                    ;;
                *)
                    syntax_error "unsupported video filter: $filter_name"
                    ;;
            esac

            filter_options="$filter_options --$filter"
            ;;
        --detelecine)
            deprecated_and_replaced "$1" '--filter detelecine'
            filter_options="$filter_options --detelecine"
            auto_detelecine=''
            ;;
        --no-auto-detelecine)
            auto_detelecine=''
            ;;
        --burn)
            subtitle_track="$(printf '%.0f' "$2")"
            shift

            if (($subtitle_track < 1)); then
                die "invalid subtitle track: $subtitle_track"
            fi

            auto_burn=''
            ;;
        --no-auto-burn)
            auto_burn=''
            ;;
        --srt)
            srt_file="$2"
            shift

            srt_count="$((srt_count + 1))"
            srt_lang=''
            srt_offset=''
            srt_codeset=''

            while [[ "$srt_file" =~ ',' ]]; do
                srt_prefix="$(echo "$srt_file" | sed 's/,.*$//')"

                if (($srt_forced_index < $srt_count )) &&  [ "$srt_prefix" == 'forced' ]; then
                    srt_forced_index="$srt_count"
                    srt_file="$(echo "$srt_file" | sed 's/^[^,]*,//')"

                elif [ ! "$srt_lang" ] && [[ "$srt_prefix" =~ ^[a-z][a-z][a-z]$ ]]; then
                    srt_lang="$srt_prefix"
                    srt_file="$(echo "$srt_file" | sed 's/^[^,]*,//')"

                elif [ ! "$srt_offset" ] && [[ "$srt_prefix" =~ ^[+-]?[0-9][0-9]*$ ]]; then
                    srt_offset="$(echo "$srt_prefix" | sed 's/^+//')"
                    srt_file="$(echo "$srt_file" | sed 's/^[^,]*,//')"

                elif [ ! "$srt_codeset" ] && [[ "$srt_prefix" =~ ^[0-9A-Za-z] ]] && [[ ! "$srt_prefix" =~ [\ /\\] ]] && [ ! -f "$srt_file" ]; then
                    srt_codeset="$srt_prefix"
                    srt_file="$(echo "$srt_file" | sed 's/^[^,]*,//')"
                else
                    break
                fi
            done

            # Force filename expansion with `eval` but first escape the string
            # to hide ", $, &, ', (, ), ;, <, >, \, ` and |.
            srt_file="$(eval echo "$(echo "$srt_file" | sed 's/\(["$&'\''();<>\\`|]\)/\\\1/g')")"

            if [ ! "$srt_file" ]; then
                syntax_error "missing subtitle filename"
            fi

            if [ ! -f "$srt_file" ]; then
                die "subtitle not found: $srt_file"
            fi

            if [ ! "$tmp" ]; then
                trap '[ "$tmp" ] && rm -rf "$tmp"' 0
                trap '[ "$tmp" ] && rm -rf "$tmp"; exit 1' SIGHUP SIGINT SIGQUIT SIGTERM

                tmp="/tmp/${program}.$$"
                mkdir -m 700 "$tmp" || exit 1
            fi

            tmp_srt_file_link="$tmp/subtitle-$srt_count.srt"
            ln -s "$(cd "$(dirname "$srt_file")" 2>/dev/null && echo "$(pwd)/$(basename "$srt_file")")" "$tmp_srt_file_link"

            srt_file_list="$srt_file_list,$tmp_srt_file_link"
            srt_codeset_list="$srt_codeset_list,$srt_codeset"
            srt_offset_list="$srt_offset_list,$srt_offset"
            srt_lang_list="$srt_lang_list,$srt_lang"
            ;;
        --big|--better)
            [ "$1" == '--better' ] && deprecated_and_replaced "$1" '--big'
            default_max_bitrate_1080p='8000'
            default_max_bitrate_720p='6000'
            default_max_bitrate_480p='3000'
            ac3_bitrate='640'
            ;;
        --angle|--start-at|--stop-at|--normalize-mix|--drc|--gain)
            passthru_options="$(echo "$passthru_options $1 $2" | sed 's/^ *//')"
            shift
            ;;
        --no-opencl|--optimize|--use-opencl|--use-hwd)
            passthru_options="$(echo "$passthru_options $1" | sed 's/^ *//')"
            ;;
        --srt-burn)
            srt_number="$(printf '%.0f' "$2" 2>/dev/null)"

            if (($srt_number < 1)); then
                passthru_options="$(echo "$passthru_options $1" | sed 's/^ *//')"
            else
                passthru_options="$(echo "$passthru_options $1 $2" | sed 's/^ *//')"
                shift
            fi
            ;;
        -*)
            syntax_error "unrecognized option: $1"
            ;;
        *)
            break
            ;;
    esac
    shift
done

readonly input="$1"

if [ ! "$input" ]; then
    syntax_error 'too few arguments'
fi

if [ ! -e "$input" ]; then
    die "input not found: $input"
fi

if ! $(which HandBrakeCLI >/dev/null); then
    die 'executable not in $PATH: HandBrakeCLI'
fi

if [ "$container_format" == 'mkv' ] && (($srt_forced_index > 0)) && ! $(which mkvpropedit >/dev/null); then
    die 'executable not in $PATH: mkvpropedit'
fi

title_options="--title $title"

if [ "$title" == '0' ]; then
    echo "Scanning: $input" >&2
fi

# Leverage `HandBrakeCLI` scan mode to extract all file- or directory-based
# media information. Significantly speed up scan with `--previews 2:0` option
# and argument.
#
readonly media_info="$(HandBrakeCLI $title_options --scan --previews 2:0 --input "$input" 2>&1)"

if [ "$debug" ]; then
    echo "$media_info" >&2
fi

if [ "$title" == '0' ]; then
    # Extract and reformat summary from media information for title listing.
    #
    readonly formatted_titles_info="$(echo "$media_info" |
        sed -n '/^+ title /,$p' |
        sed '/^  + autocrop: /d;/^  + support /d;/^HandBrake/,$d;s/\(^ *\)+ \(.*$\)/\1\2/')"

    if [ ! "$formatted_titles_info" ]; then
        die "no media title available in: $input"
    fi

    echo "$formatted_titles_info"
    exit

elif [ "$title" == '1' ]; then
    title_options=''
fi

if [ ! "$(echo "$media_info" | sed -n '/^+ title /,$p')" ]; then
    echo "$program: \`title $title\` not found in: $input" >&2
    echo "Try \`$program --title 0 [FILE|DIRECTORY]\` to scan for titles." >&2
    echo "Try \`$program --help\` for more information." >&2
    exit 1
fi

readonly output="$(basename "$input" | sed 's/\.[^.]\{1,\}$//').$container_format"

if [ -e "$output" ]; then
    die "output file already exists: $output"
fi

readonly size_array=($(echo "$media_info" | sed -n 's/^  + size: \([0-9]\{1,\}\)x\([0-9]\{1,\}\).*$/\1 \2/p'))

if ((${#size_array[*]} != 2)); then
    die "no video size information in: $input"
fi

readonly width="${size_array[0]}"
readonly height="${size_array[1]}"

# Limit reference frames for playback compatibility with popular devices.
#
case $preset in
    slower|veryslow|placebo)
        reference_frames='5'
        ;;
    *)
        reference_frames=''
        ;;
esac

level=''
size_options='--strict-anamorphic'

# Limit `x264` video buffer verifier (VBV) size to values appropriate for
# H.264 level with High profile:
#
#   25000 for level 4.0 (e.g. Blu-ray input)
#   17500 for level 3.1 (e.g. 720p input)
#   12500 for level 3.0 (e.g. DVD input)
#
if (($width > 1280)) || (($height > 720)); then

    if [ ! "$constrain_to_1280x720" ]; then
        vbv_maxrate="$default_max_bitrate_1080p"
        max_bufsize='25000'

        case $preset in
            slow|slower|veryslow|placebo)
                # Force H.264 level to 4.0 when using 5 reference frames.
                # Which causes HandBrakeCLI to emit this message:
                #
                #   x264 [warning]: DPB size (5 frames, 39000 mbs) > level limit (4 frames, 32768 mbs)
                #
                # ...but it can be ignored since the VBV maximum rate is
                # usually low.
                #
                level='4.0'
                ;;
        esac
    else
        vbv_maxrate="$default_max_bitrate_720p"
        max_bufsize='17500'
        size_options='--maxWidth 1280 --maxHeight 720 --loose-anamorphic'
    fi

elif (($width > 720)) || (($height > 576)); then
    vbv_maxrate="$default_max_bitrate_720p"
    max_bufsize='17500'
else
    vbv_maxrate="$default_max_bitrate_480p"
    max_bufsize='12500'
fi

if [ "$max_bitrate" ]; then
    vbv_maxrate="$max_bitrate"

    if (($vbv_maxrate > $max_bufsize)); then
        vbv_maxrate="$max_bufsize"
    fi

elif [ -f "$input" ]; then
    readonly duration_array=($(echo "$media_info" |
        sed -n 's/^  + duration: \([0-9][0-9]\):\([0-9][0-9]\):\([0-9][0-9]\)$/ \1 \2 \3 /p' |
        sed 's/ 0/ /g'))

    if ((${#duration_array[*]} == 3)); then
        # Calculate total bitrate from file size in bits divided by video
        # duration in seconds.
        #
        bitrate="$((($(stat -L -f %z "$input") * 8) / ((duration_array[0] * 60 * 60) + (duration_array[1] * 60) + duration_array[2])))"

        if [ "$bitrate" ]; then
            # Convert to kbps and round to nearest thousand.
            #
            bitrate="$((((bitrate / 1000) / 1000) * 1000))"

            if (($bitrate < $vbv_maxrate)); then
                readonly min_bitrate="$((vbv_maxrate / 2))"

                if (($bitrate < $min_bitrate)); then
                    vbv_maxrate="$min_bitrate"
                else
                    vbv_maxrate="$bitrate"
                fi
            fi
        fi
    fi
fi

if [ "$vbv_bufsize" ]; then

    if (($vbv_bufsize > $max_bufsize)); then
        vbv_bufsize="$max_bufsize"
    fi
else
    # The `x264` video buffer verifier (VBV) size must always be less than the
    # maximum rate to maintain quality in constant rate factor (CRF) mode.
    #
    vbv_bufsize="$((vbv_maxrate / 2))"
fi

# First extract frame rate from media information summary. If that frame rate
# is `23.976` then it's possible "real" frame rate is `29.97`. For file input,
# re-extract frame rate from stream information if available.
#
frame_rate="$(echo "$media_info" | sed -n 's/^  + size: .*, \([0-9]\{1,\}\.[.0-9]\{1,\}\) fps$/\1/p')"

if [ "$frame_rate" == '23.976' ] && [ -f "$input" ]; then
    readonly video_track_info="$(echo "$media_info" |
        sed -n '/^    Stream #[^:]\{1,\}: Video: /p' |
        sed -n 1p)"

    if [ "$video_track_info" ]; then
        readonly raw_frame_rate="$(echo "$video_track_info" | sed -n 's/^.*, \([0-9.]\{1,\}\) fps, .*$/\1/p')"

        if [ "$raw_frame_rate" ]; then
            frame_rate="$raw_frame_rate"
        fi
    fi
fi

if [ ! "$frame_rate" ]; then
    die "no video frame rate information in: $input"
fi

# Allow user to explicitly choose output frame rate. If none is chosen and
# input frame rate is `29.97` then force output frame rate of `23.976`.
# Otherwise set peak frame rate to `30` so HandBrakeCLI` can dynamically
# determine output frame rate.
#
if [ ! "$frame_rate_options" ]; then

    if [ "$auto_detelecine" ] && [[ "$frame_rate" =~ '29.97' ]]; then
        frame_rate_options='--rate 23.976'
    else
        frame_rate_options='--rate 30 --pfr'
    fi
fi

readonly all_audio_tracks_info="$(echo "$media_info" |
    sed -n '/^  + audio tracks:$/,/^  + subtitle tracks:$/p' |
    sed -n '/^    + /p')"

if [ ! "$all_audio_tracks_info" ]; then
    die "no audio track information in: $input"
fi

readonly audio_track_info="$(echo "$all_audio_tracks_info" | sed -n ${audio_track}p)"

if [ ! "$audio_track_info" ]; then
    die "\`audio $audio_track\` track not found in: $input"
fi

audio_track_channels="$(echo "$audio_track_info" |
    sed -n 's/^[^(]\{1,\} ([^(]\{1,\}) (\([^(]\{1,\}\)) .*$/\1/p' |
    sed 's/ ch$//')"

case $audio_track_channels in
    'Dolby Surround')
        audio_track_channels='2'
        ;;
    [0-9]*)
        high_channels="$(echo "$audio_track_channels" | sed 's/\.[0-9]\{1,\}$//')"
        low_channels="$(echo "$audio_track_channels" | sed 's/^[0-9]\{1,\}\.//')"

        if [ "$high_channels" ] && [ "$low_channels" ]; then
            audio_track_channels="$((high_channels + low_channels))"
        fi
        ;;
    *)
        die "bad audio channel information in: $input"
        ;;
esac

if [ ! "$audio_track_channels" ]; then
    die "no audio channel information in: $input"
fi

# For MP4 output, transcode audio input first into Advanced Audio Coding (AAC)
# format. Add second audio track in Dolby Digital (AC-3) format if audio input
# is multi-channel.
#
# Handle MKV output like MP4, but place any AC-3 format track first.
#
# Transcode stereo or mono audio using `HandBrakeCLI` default behavior, at 160
# or 80 kbps in AAC format. Use existing audio if already in that format.
#
# Transcode multi-channel audio input in AC-3 format. Use existing audio if
# already in that format. Allow user to disable AC-3 format output, change
# bitrate, or allow larger input bitrate to pass through without transcoding.
#
audio_track_list="$audio_track"
audio_track_name_list=''

if [ "$ac3_bitrate" ] && (($audio_track_channels > 2)); then
    audio_track_list="$audio_track,$audio_track"
    audio_track_name_list=','

    readonly help="$(HandBrakeCLI --help 2>/dev/null)"

    if $(echo "$help" | grep -q ca_aac); then
        aac_encoder='ca_aac'

    elif $(echo "$help" | grep -q av_aac); then
        aac_encoder='av_aac'

    elif $(echo "$help" | grep -q ffaac); then
        aac_encoder='ffaac'
    else
        aac_encoder='faac'
    fi

    if $(echo "$help" | grep -q ffac3); then
        ac3_encoder='ffac3'
    else
        ac3_encoder='ac3'
    fi

    readonly audio_track_bitrate="$(echo "$audio_track_info" | sed -n 's/^.* \([0-9]\{1,\}\)bps$/\1/p')"

    if (($pass_ac3_bitrate < $ac3_bitrate)); then
        pass_ac3_bitrate="$ac3_bitrate"
    fi

    if [[ "$audio_track_info" =~ '(AC3)' ]] && ((($audio_track_bitrate / 1000) <= $pass_ac3_bitrate)); then

        if [ "$container_format" == 'mkv' ]; then
            audio_options="--aencoder copy:ac3,$aac_encoder"
        else
            audio_options="--aencoder $aac_encoder,copy:ac3"
        fi

    elif [ "$container_format" == 'mkv' ]; then
        audio_options="--aencoder $ac3_encoder,$aac_encoder --ab $ac3_bitrate,"
    else
        audio_options="--aencoder $aac_encoder,$ac3_encoder --ab ,$ac3_bitrate"
    fi

elif [[ "$audio_track_info" =~ '(aac)' ]]; then
    audio_options='--aencoder copy:aac'
else
    audio_options=''
fi

if [ "$extra_audio_track_list" ]; then
    audio_options="--audio ${audio_track_list}$extra_audio_track_list $audio_options --aname"
    audio_track_name_list="${audio_track_name_list}$extra_audio_track_name_list"
else
    if (($audio_track > 1)); then
        audio_options="--audio $audio_track $audio_options"
    fi

    audio_track_name_list=''
fi

if [ "$auto_detelecine" ] && [[ "$frame_rate" =~ '29.97' ]]; then
    filter_options="$filter_options --detelecine"
fi

filter_options="$(echo "$filter_options" | sed 's/^ *//;s/ *$//;s/ \{1,\}/ /g')"

readonly all_subtitle_tracks_info="$(echo "$media_info" |
    sed -n '/^  + subtitle tracks:$/,$p' |
    sed -n '/^    + /p')"

if [ "$subtitle_track" ] && [ ! "$all_subtitle_tracks_info" ]; then
    die "no subtitle track information in: $input"
fi

# For file input, automatically find first "forced" subtitle and select it for
# burning into video. Allow user to disable this behavior.
#
if [ "$auto_burn" ] && [ -f "$input" ]; then
    readonly raw_subtitle_tracks_info="$(echo "$media_info" | sed -n '/^    Stream #[^:]\{1,\}: Subtitle: /p')"

    if [ "$raw_subtitle_tracks_info" ]; then
        readonly raw_subtitle_tracks_count="$(echo "$raw_subtitle_tracks_info" | wc -l | sed 's/ //g')"

        if [ "$raw_subtitle_tracks_count" == "$(echo "$all_subtitle_tracks_info" | wc -l | sed 's/ //g')" ]; then
            index='1'

            while ((index <= $raw_subtitle_tracks_count)); do

                if [[ "$(echo "$raw_subtitle_tracks_info" | sed -n ${index}p)" =~ '(forced)' ]]; then
                    subtitle_track="$index"
                    break
                fi

                index="$((index + 1))"
            done
        fi
    fi
fi

subtitle_options=''

if [ "$subtitle_track" ]; then
    readonly subtitle_track_info="$(echo "$all_subtitle_tracks_info" | sed -n ${subtitle_track}p)"

    if [ ! "$subtitle_track_info" ]; then
        die "\`subtitle $subtitle_track\` track not found in: $input"
    fi

    subtitle_options="--subtitle $subtitle_track --subtitle-burned"
fi

if (($srt_count > 0)); then
    srt_options="--srt-file $(echo "$srt_file_list" | sed 's/^,//')"

    srt_codeset_list="$(echo "$srt_codeset_list" | sed 's/^,//')"

    if [ "$srt_codeset_list" ]; then
        srt_options="$srt_options --srt-codeset $srt_codeset_list"
    fi

    srt_offset_list="$(echo "$srt_offset_list" | sed 's/^,//')"

    if [ "$srt_offset_list" ]; then
        srt_options="$srt_options --srt-offset $srt_offset_list"
    fi

    srt_lang_list="$(echo "$srt_lang_list" | sed 's/^,//')"

    if [ "$srt_lang_list" ]; then
        srt_options="$srt_options --srt-lang $srt_lang_list"
    fi

    if (($srt_forced_index > 0)); then
        srt_options="$srt_options --srt-default $srt_forced_index"
    fi
else
    srt_options=''
fi

if [ "$preset" == 'medium' ]; then
    preset_options=''
else
    preset_options="--x264-preset $preset"
fi

encoder_options="vbv-maxrate=$vbv_maxrate:vbv-bufsize=$vbv_bufsize"

if [ "$reference_frames" ]; then
    encoder_options="ref=$reference_frames:$encoder_options"
fi

if [ "$max_rate_factor" ]; then
    encoder_options="$encoder_options:crf-max=$max_rate_factor"
fi

if [ "$level" ]; then
    encoder_options="$encoder_options:level=$level"
fi

if [ "$extra_encoder_options" ]; then
    encoder_options="$(echo "$encoder_options:$extra_encoder_options" | sed 's/:*$//;s/:\{1,\}/:/g')"
fi

if [ "$debug" ]; then
    echo "title_options             = $title_options" >&2
    echo "chapters_options          = $chapters_options" >&2
    echo "container_format_options  = $container_format_options" >&2
    echo "preset_options            = $preset_options" >&2
    echo "tune_options              = $tune_options" >&2
    echo "encoder_options           = $encoder_options" >&2
    echo "rate_factor               = $rate_factor" >&2
    echo "frame_rate_options        = $frame_rate_options" >&2
    echo "audio_options             = $audio_options" >&2
    echo "audio_track_name_list     = $audio_track_name_list" >&2
    echo "crop_options              = $crop_options" >&2
    echo "size_options              = $size_options" >&2
    echo "filter_options            = $filter_options" >&2
    echo "subtitle_options          = $subtitle_options" >&2
    echo "srt_options               = $srt_options" >&2
    echo "passthru_options          = $passthru_options" >&2
    echo "input                     = $input" >&2
    echo "output                    = $output" >&2
    exit
fi

echo "Transcoding: $input" >&2

time {
    HandBrakeCLI \
        $title_options \
        $chapters_options \
        --markers \
        $container_format_options \
        --encoder x264 \
        $preset_options \
        $tune_options \
        --encopts $encoder_options \
        --quality $rate_factor \
        $frame_rate_options \
        $audio_options "$audio_track_name_list" \
        $crop_options \
        $size_options \
        $filter_options \
        $subtitle_options \
        $srt_options \
        $passthru_options \
        --input "$input" \
        --output "$output" \
        2>&1 | tee -a "${output}.log"

    if [ "$container_format" == 'mkv' ] && (($srt_forced_index > 0)) && [ -f "$output" ]; then
        mkvpropedit --quiet --edit track:s$srt_forced_index --set flag-forced=1 "$output" || exit 1
    fi
}
