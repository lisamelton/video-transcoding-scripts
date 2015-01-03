#!/bin/bash
#
# transcode-video.sh
#
# Copyright (c) 2013-2015 Don Melton
#

about() {
    cat <<EOF
$program 5.3 of January 3, 2015
Copyright (c) 2013-2015 Don Melton
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
                        (\`--slow\` can also improve quality for some input)
    --crop T:B:L:R  set video crop values (default: 0:0:0:0)
                        (use \`detect-crop.sh\` script for optimal bounds)
                        (use \`--crop auto\` for \`HandBrakeCLI\` behavior)
    --720p          constrain video to fit within 1280x720 pixel bounds
    --audio TRACK   select main audio track (default: 1)
    --burn TRACK    burn subtitle track (default: first forced track, if any)

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
    --start-at,--stop-at UNIT:VALUE
                    start or stop at \`frame\`, \`duration\` or \`pts\`
                        (\`duration\` in seconds, \`pts\` on 90 kHz clock)

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
                        (\`--slow\` can also improve quality for some input)

Video options:
    --crop T:B:L:R  set video crop values (default: 0:0:0:0)
                        (use \`detect-crop.sh\` script for optimal bounds)
                        (use \`--crop auto\` for \`HandBrakeCLI\` behavior)
    --720p          constrain video to fit within 1280x720 pixel bounds
    --1080p             "       "   "   "    "    1920x1080  "     "
    --2160p             "       "   "   "    "    3840x2160  "     "
    --rate FPS[,limited]
                    set video frame rate with optional peak-limited flag
                        (default: based on input)

Audio options:
    --audio TRACK   select main audio track (default: 1)
    --single        don't create secondary main audio track
    --add-audio TRACK[,NAME]
                    add audio track in AAC format with optional name
                        (can be used multiple times)
    --allow-ac3     allow multi-channel AC-3 format in additional audio tracks
    --allow-dts     allow multi-channel DTS formats in all audio tracks
                        (also allows AC-3 format in additional audio tracks)
    --no-surround   don't output multi-channel formats in any audio track
    --ac3 BITRATE   set AC-3 audio bitrate to 384|448|640 kbps (default: 384)
    --pass-ac3 BITRATE
                    set passthru AC-3 audio <= 384|448|640 kbps (default: 448)
                        (only applies to multi-channel)
    --copy-ac3      always passthru AC-3 audio in main track
                        (including mono and stero, regardless of bitrate)
    --copy-all-ac3  always passthru AC-3 audio in all tracks
                        (including mono and stero, regardless of bitrate)

Subtitle options:
    --burn TRACK    burn subtitle track (default: first forced track, if any)
    --no-auto-burn  don't automatically burn first forced subtitle
    --add-subtitle [forced,]TRACK
                    add subtitle track with optional forced playback flag
                        (can be used multiple times)
    --burn-srt [ENCODING,][OFFSET,]FILENAME
                    burn subtitle track from SubRip-format \`.srt\` text file
                        with optional character set encoding (default: latin1)
                        with optional +/- offset in milliseconds (default: 0)
                        (values before filename can appear in any order)
    --add-srt [ENCODING,][OFFSET,][LANGUAGE,][forced,]FILENAME
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
    --buffer SIZE   set video buffer size (default: 50% of maximum bitrate)
    --add-encopts OPTION=VALUE[:OPTION=VALUE...]
                    specify additional x264 encoder options
    --crf FACTOR    set constant rate factor (default: 16)
    --crf-max FACTOR
                    set maximum constant rate factor (default: 25)
                        (use \`--crf-max none\` to disable)
    --filter NAME[=SETTINGS]
                    apply \`HandBrakeCLI\` video filter with optional settings
                        (default: \`deinterlace\` for some 29.97 fps input)
                        (refer to \`HandBrakeCLI --help\` for more information)
                        (can be used multiple times)

Passthru options:
    --angle, --normalize-mix, --drc, --gain,
    --no-opencl, --optimize, --use-opencl, --use-hwd
                    all passed through to \`HandBrakeCLI\` unchanged 
                        (refer to \`HandBrakeCLI --help\` for more information)

Other options:
    --debug         output diagnostic information to \`stderr\` and exit
                        (with \`HandBrakeCLI\` command line sent to \`stdout\`)
    --version       output version information and exit

Requires \`HandBrakeCLI\` executable in \$PATH.
May require \`mp4track\` and \`mkvpropedit\` executables in \$PATH for some options.
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

escape_string() {
    echo "$1" | sed "s/'/'\\\''/g;s/^\(.*\)$/'\1'/"
}

readonly program="$(basename "$0")"

# OPTIONS
#
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

media_title='1'
section_options=''
container_format='mp4'
default_max_bitrate_2160p='10000'
default_max_bitrate_1080p='5000'
default_max_bitrate_720p='4000'
default_max_bitrate_480p='2000'
preset='medium'
crop_values='0:0:0:0'
constrain_width='4096'
constrain_height='2304'
frame_rate_options=''
main_audio_track='1'
single_main_audio=''
extra_audio_tracks=()
allow_ac3=''
allow_dts=''
allow_surround='yes'
ac3_bitrate='384'
pass_ac3_bitrate='448'
copy_ac3=''
copy_all_ac3=''
burned_subtitle_track=''
auto_burn='yes'
extra_subtitle_tracks=()
burned_srt_file=''
extra_srt_files=()
tune_options=''
max_bitrate=''
vbv_bufsize=''
extra_encopts_options=''
rate_factor='16'
max_rate_factor='25'
filter_options=''
auto_deinterlace='yes'
passthru_options=''
debug=''

while [ "$1" ]; do
    case $1 in
        --title)
            media_title="$(printf '%.0f' "$2" 2>/dev/null)"
            shift

            if (($media_title < 0)); then
                die "invalid media title number: $media_title"
            fi
            ;;
        --chapters|--start-at|--stop-at)
            section_options="$section_options $1 $2"
            shift
            ;;
        --mkv|--m4v)
            container_format="${1:2:3}"
            ;;
        --preset|--veryfast|--faster|--fast|--slow|--slower|--veryslow)

            if [ "$1" == '--preset' ]; then
                preset="$2"
                shift
            else
                preset="${1:2}"
            fi
            ;;
        --big|--better)
            [ "$1" == '--better' ] && deprecated_and_replaced "$1" '--big'
            default_max_bitrate_2160p='16000'
            default_max_bitrate_1080p='8000'
            default_max_bitrate_720p='6000'
            default_max_bitrate_480p='3000'
            ac3_bitrate='640'
            ;;
        --crop)
            crop_values="$2"
            shift
            ;;
        --720p|--resize)
            [ "$1" == '--resize' ] && deprecated_and_replaced "$1" '--720p'
            constrain_width='1280'
            constrain_height='720'
            ;;
        --1080p)
            constrain_width='1920'
            constrain_height='1080'
            ;;
        --2160p)
            constrain_width='3840'
            constrain_height='2160'
            ;;
        --rate)
            frame_rate_argument="$2"
            shift

            frame_rate_options="--rate $(printf '%.3f' "$(echo "$frame_rate_argument" | sed 's/,.*$//')" 2>/dev/null | sed 's/0*$//;s/\.$//')"

            if [[ "$frame_rate_argument" =~ ',limited'$ ]]; then
                frame_rate_options="$frame_rate_options --pfr"

            elif [[ "$frame_rate_argument" =~ ',' ]]; then
                die "invalid frame rate argument: $frame_rate_argument"
            fi
            ;;
        --audio)
            main_audio_track="$(printf '%.0f' "$2" 2>/dev/null)"
            shift

            if (($main_audio_track < 1)); then
                die "invalid main audio track: $main_audio_track"
            fi
            ;;
        --single)
            single_main_audio='yes'
            ;;
        --add-audio)
            extra_audio_tracks=("${extra_audio_tracks[@]}" "$2")
            shift
            ;;
        --allow-ac3)
            allow_ac3='yes'
            allow_surround='yes'
            ;;
        --allow-dts)
            allow_ac3='yes'
            allow_dts='yes'
            allow_surround='yes'
            ;;
        --no-surround|--no-ac3)
            [ "$1" == '--no-ac3' ] && deprecated_and_replaced "$1" '--no-surround'
            allow_ac3=''
            allow_dts=''
            allow_surround=''
            copy_ac3=''
            copy_all_ac3=''
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
        --copy-ac3)
            copy_ac3='yes'
            ;;
        --copy-all-ac3)
            copy_ac3='yes'
            copy_all_ac3='yes'
            ;;
        --burn)
            burned_subtitle_track="$(printf '%.0f' "$2" 2>/dev/null)"
            shift

            if (($burned_subtitle_track < 1)); then
                die "invalid burn subtitle track: $burned_subtitle_track"
            fi

            burned_srt_file=''
            ;;
        --no-auto-burn)
            auto_burn=''
            ;;
        --add-subtitle)
            extra_subtitle_tracks=("${extra_subtitle_tracks[@]}" "$2")
            shift
            ;;
        --burn-srt)
            burned_srt_file="$2"
            burned_subtitle_track=''
            auto_burn=''
            shift
            ;;
        --add-srt|--srt)
            [ "$1" == '--srt' ] && deprecated_and_replaced "$1" '--add-srt'
            extra_srt_files=("${extra_srt_files[@]}" "$2")
            shift
            ;;
        --tune)
            tune_options="$tune_options --encoder-tune $2"
            shift
            ;;
        --max|--vbv-maxrate|--abr)
            [ "$1" == '--abr' ] && deprecated_and_replaced "$1" '--max'
            max_bitrate="$(printf '%.0f' "$2" 2>/dev/null)"
            shift

            if (($max_bitrate < 1)); then
                die "invalid maximum video bitrate: $max_bitrate"
            fi
            ;;
        --buffer|--vbv-bufsize)
            vbv_bufsize="$(printf '%.0f' "$2" 2>/dev/null)"
            shift

            if (($vbv_bufsize < 1)); then
                die "invalid video buffer size: $vbv_bufsize"
            fi
            ;;
        --add-encopts)
            extra_encopts_options="$2"
            shift
            ;;
        --crf)
            rate_factor="$(printf '%.2f' "$2" 2>/dev/null | sed 's/0*$//;s/\.$//')"
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
                    max_rate_factor="$(printf '%.2f' "$max_rate_factor" 2>/dev/null | sed 's/0*$//;s/\.$//')"

                    if (($max_rate_factor < 0)); then
                        die "invalid maximum constant rate factor: $max_rate_factor"
                    fi
                    ;;
            esac
            ;;
        --filter)
            filter="$2"
            shift

            filter_name="$(echo "$filter" | sed 's/=.*$//')"

            case $filter_name in
                deinterlace|decomb|detelecine)
                    auto_deinterlace=''
                    ;;
                denoise|nlmeans|nlmeans-tune|deblock|rotate|grayscale)
                    ;;
                *)
                    syntax_error "unsupported video filter: $filter_name"
                    ;;
            esac

            filter_options="$filter_options --$filter"
            ;;
        --angle|--start-at|--stop-at|--normalize-mix|--drc|--gain)
            passthru_options="$passthru_options $1 $2"
            shift
            ;;
        --no-opencl|--optimize|--use-opencl|--use-hwd)
            passthru_options="$passthru_options $1"
            ;;
        --debug)
            debug='yes'
            ;;
        --hq)
            deprecated "$1"
            ;;
        --with-original-audio)
            deprecated_and_replaced "$1" '--allow-dts'
            allow_dts='yes'
            audio_track="$(printf '%.0f' "$1" 2>/dev/null)"

            if (($audio_track > 0)); then
                main_audio_track="$audio_track"
                shift
            fi
            ;;
        --detelecine)
            deprecated_and_replaced "$1" '--filter detelecine'
            filter_options="$filter_options --detelecine"
            ;;
        --no-auto-detelecine)
            deprecated "$1"
            ;;
        --srt-burn)
            deprecated "$1"
            srt_number="$(printf '%.0f' "$2" 2>/dev/null)"

            if (($srt_number > 0)); then
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

# INPUT
#
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

if [ "$media_title" == '0' ]; then
    echo "Scanning: $input" >&2
fi

# Leverage `HandBrakeCLI` scan mode to extract all file- or directory-based
# media information. Significantly speed up scan with `--previews 2:0` option
# and argument.
#
readonly media_info="$(HandBrakeCLI --title $media_title --scan --previews 2:0 --input "$input" 2>&1)"

if [ "$media_title" == '0' ]; then
    echo "$media_info"
    exit
fi

if [ "$debug" ]; then
    echo "$media_info" >&2
fi

if ! $(echo "$media_info" | grep -q '^+ title '$media_title':$'); then
    echo "$program: media title number $media_title not found in: $input" >&2
    echo "Try \`$program --title 0 [FILE|DIRECTORY]\` to scan for media titles." >&2
    echo "Try \`$program --help\` for more information." >&2
    exit 1
fi

readonly output="$(basename "$input" | sed 's/\.[0-9A-Za-z]\{1,\}$//').$container_format"

if [ -e "$output" ]; then
    die "output file already exists: $output"
fi

# VIDEO
#
readonly size_array=($(echo "$media_info" | sed -n 's/^  + size: \([0-9]\{1,\}\)x\([0-9]\{1,\}\).*$/\1 \2/p'))

if ((${#size_array[*]} != 2)); then
    die "video size not found: $input"
fi

width="${size_array[0]}"
height="${size_array[1]}"

if [ "$crop_values" != '0:0:0:0' ] && [ "$crop_values" != 'auto' ]; then
    readonly crop_array=($(echo "$crop_values" |
        sed -n 's/^\([0-9]\{1,\}\):\([0-9]\{1,\}\):\([0-9]\{1,\}\):\([0-9]\{1,\}\)$/ \1 \2 \3 \4 /p' |
        sed 's/ 0\([0-9]\)/ \1/g'))

    width="$((width - ${crop_array[2]} - ${crop_array[3]}))"
    height="$((height - ${crop_array[0]} - ${crop_array[1]}))"

    if (($width < 1)) || (($height < 1)); then
        die "invalid crop: $crop_values"
    fi
fi

if ((($width > $constrain_width)) || (($height > $constrain_height))); then
    size_options="--maxWidth $constrain_width --maxHeight $constrain_height --loose-anamorphic"

    adjusted_height="$(ruby -e 'printf "%.0f", '$height' * ('$constrain_width'.0 / '$width')')"
    adjusted_height=$((adjusted_height - (adjusted_height % 2)))

    if (($adjusted_height > $constrain_height)); then
        width="$(ruby -e 'printf "%.0f", '$width' * ('$constrain_height'.0 / '$height')')"
        width=$((width + (width % 2)))
        height="$constrain_height"
    else
        width="$constrain_width"
        height="$adjusted_height"
    fi
else
    size_options='--strict-anamorphic'
fi

# Limit `x264` video buffer verifier (VBV) size to values appropriate for
# H.264 level with High profile:
#
#   300000 for level 5.1 (e.g. 2160p input)
#    25000 for level 4.0 (e.g. Blu-ray input)
#    17500 for level 3.1 (e.g. 720p input)
#    12500 for level 3.0 (e.g. DVD input)
#
level_options=''

if (($width > 1920)) || (($height > 1080)); then
    vbv_maxrate="$default_max_bitrate_2160p"
    max_bufsize='300000'

elif (($width > 1280)) || (($height > 720)); then
    vbv_maxrate="$default_max_bitrate_1080p"
    max_bufsize='25000'

    case $preset in
        slow|slower|veryslow|placebo)
            level_options="--encoder-level 4.0"
            ;;
    esac

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

if [ ! "$frame_rate_options" ]; then
    frame_rate_options='--rate 30 --pfr'
    readonly frame_rate="$(echo "$media_info" | sed -n 's/^  + size: .*, \([0-9]\{1,\}\.[.0-9]\{1,\}\) fps$/\1/p')"

    if [ ! "$frame_rate" ]; then
        die "no video frame rate information in: $input"
    fi

    if [ "$frame_rate" == '29.970' ]; then
        readonly video_stream_info="$(echo "$media_info" | sed -n '/^    Stream #[^:]\{1,\}: Video: /p' | sed -n 1p)"
        force_frame_rate=''

        if [ "$video_stream_info" ]; then
            $(echo "$video_stream_info" | grep -q 'mpeg2video') && force_frame_rate='yes'
        else
            $(echo "$media_info" | grep -q '^  + vts ') && force_frame_rate='yes'
        fi

        if [ "$force_frame_rate" ]; then
            frame_rate_options='--rate 23.976'

        elif [ "$auto_deinterlace" ]; then
            filter_options="$filter_options --deinterlace"
        fi
    fi
fi

# AUDIO
#
if (($pass_ac3_bitrate < $ac3_bitrate)); then
    pass_ac3_bitrate="$ac3_bitrate"
fi

if [ "$ac3_bitrate" == '640' ]; then
    ac3_bitrate=''
fi

track_index='1'

audio_track_list=''
audio_encoder_list=''
audio_bitrate_list=''
audio_track_name_list=''
audio_track_name_edits=()

readonly all_audio_tracks_info="$(echo "$media_info" |
    sed -n '/^  + audio tracks:$/,/^  + subtitle tracks:$/p' |
    sed -n '/^    + /p')"

audio_track_info="$(echo "$all_audio_tracks_info" | sed -n ${main_audio_track}p)"

if [ "$audio_track_info" ]; then
    audio_track_list="$main_audio_track"

    if $(HandBrakeCLI --help 2>/dev/null | grep -q 'ca_aac'); then
        aac_encoder='ca_aac'
    else
        aac_encoder='av_aac'
    fi

    surround_audio_encoder=''
    surround_audio_bitrate=''
    stereo_audio_encoder="$aac_encoder"

    if [ "$copy_ac3" ] && [[ "$audio_track_info" =~ '(AC3)' ]]; then
        surround_audio_encoder='copy'

    elif (($(echo "$audio_track_info" | sed 's/^.*(\([0-9]\{1,\}\)\.\([0-9]\{1,\}\) ch).*$/\1\2/;s/^$/0/') > 20)); then

        if [ "$allow_surround" ]; then

            if ( [[ "$audio_track_info" =~ '(AC3)' ]] && ((($(echo "$audio_track_info" | sed -n 's/^.* \([0-9]\{1,\}\)bps$/\1/p' | sed 's/^$/640/') / 1000) <= $pass_ac3_bitrate)) ) || ( [ "$allow_dts" ] && [[ "$audio_track_info" =~ '(DTS' ]] ); then
                surround_audio_encoder='copy'
            else
                surround_audio_encoder='ac3'
                surround_audio_bitrate="$ac3_bitrate"
            fi
        fi

    elif [[ "$audio_track_info" =~ '(AAC)' ]]; then
        stereo_audio_encoder='copy'
    fi

    if [ "$surround_audio_encoder" ] && [ ! "$single_main_audio" ]; then
        audio_track_list="$main_audio_track,$main_audio_track"
        audio_track_name_list=','

        if [ "$container_format" == 'mkv' ]; then
            audio_encoder_list="$surround_audio_encoder,$stereo_audio_encoder"
            audio_bitrate_list="$surround_audio_bitrate,"
        else
            audio_encoder_list="$stereo_audio_encoder,$surround_audio_encoder"
            audio_bitrate_list=",$surround_audio_bitrate"
        fi

        track_id='3'
        track_index='3'
    else
        audio_track_list="$main_audio_track"

        if [ "$surround_audio_encoder" ]; then
            audio_encoder_list="$surround_audio_encoder"
            audio_bitrate_list="$surround_audio_bitrate"
        else
            audio_encoder_list="$stereo_audio_encoder"
        fi

        track_id='2'
        track_index='2'
    fi

    for item in "${extra_audio_tracks[@]}"; do
        track_number="$(printf '%.0f' "$(echo "$item" | sed 's/,.*$//')" 2>/dev/null)"

        if (($track_number < 1)); then
            die "invalid additional audio track: $item"
        fi

        audio_track_info="$(echo "$all_audio_tracks_info" | sed -n ${track_number}p)"

        if [ ! "$audio_track_info" ]; then
            die "missing additional audio track: $input"
        fi

        audio_track_list="$audio_track_list,$track_number"
        audio_bitrate_list="$audio_bitrate_list,"

        if [ "$copy_all_ac3" ] && [[ "$audio_track_info" =~ '(AC3)' ]]; then
            audio_encoder_list="$audio_encoder_list,copy"

        elif (($(echo "$audio_track_info" | sed 's/^.*(\([0-9]\{1,\}\)\.\([0-9]\{1,\}\) ch).*$/\1\2/;s/^$/0/') > 20)); then

            if [ "$allow_ac3" ]; then

                if ( [[ "$audio_track_info" =~ '(AC3)' ]] && ((($(echo "$audio_track_info" | sed -n 's/^.* \([0-9]\{1,\}\)bps$/\1/p' | sed 's/^$/640/') / 1000) <= $pass_ac3_bitrate)) ) || ( [ "$allow_dts" ] && [[ "$audio_track_info" =~ '(DTS' ]] ); then
                    audio_encoder_list="$audio_encoder_list,copy"
                else
                    audio_encoder_list="$audio_encoder_list,ac3"
                    audio_bitrate_list="$audio_bitrate_list$ac3_bitrate"
                fi
            else
                audio_encoder_list="$audio_encoder_list,$aac_encoder"
            fi

        elif [[ "$audio_track_info" =~ '(AAC)' ]]; then
            audio_encoder_list="$audio_encoder_list,copy"
        else
            audio_encoder_list="$audio_encoder_list,$aac_encoder"
        fi

        if [[ "$item" =~ ',' ]]; then
            track_name="$(echo "$item" | sed 's/^[^,]*,//')"
        else
            track_name=''
        fi

        sanitized_name="$(echo "$track_name" | sed 's/,/_/g')"
        audio_track_name_list="$audio_track_name_list,$sanitized_name"

        if [ "$sanitized_name" != "$track_name" ]; then

            if [ "$container_format" == 'mkv' ]; then
                audio_track_name_edits=("${audio_track_name_edits[@]}" "$track_id,$track_name")
            else
                audio_track_name_edits=("${audio_track_name_edits[@]}" "$track_index,$track_name")
            fi
        fi

        track_id="$((track_id + 1))"
        track_index="$((track_index + 1))"
    done

elif (($main_audio_track > 1)) || ((${#extra_audio_tracks[*]} > 0)); then
    die "missing audio track: $input"
fi

if [ "$audio_track_list" ]; then
    audio_options="--audio $audio_track_list --aencoder $audio_encoder_list"

    if [ "$(echo "$audio_bitrate_list" | sed 's/,//g')" ]; then
        audio_options="$audio_options --ab $audio_bitrate_list"
    fi

    if [ "$(echo "$audio_track_name_list" | sed 's/,//g')" ]; then
        audio_options="$audio_options --aname"
    else
        audio_track_name_list=''
    fi
else
    audio_options=''
fi

# SUBTITLES
#
subtitle_track_list=''

readonly all_subtitle_tracks_info="$(echo "$media_info" |
    sed -n '/^  + subtitle tracks:$/,$p' |
    sed -n '/^    + /p')"

if [ "$burned_subtitle_track" ]; then
    subtitle_track_info="$(echo "$all_subtitle_tracks_info" | sed -n ${burned_subtitle_track}p)"

    if [ ! "$subtitle_track_info" ]; then
        die "missing subtitle track: $input"
    fi

    subtitle_track_list="$burned_subtitle_track"

elif [ "$auto_burn" ]; then
    readonly all_subtitle_streams_info="$(echo "$media_info" | sed -n '/^    Stream #[^:]\{1,\}: Subtitle: /p')"
    subtitle_track='1'

    while : ; do
        subtitle_track_info="$(echo "$all_subtitle_tracks_info" | sed -n ${subtitle_track}p)"

        if [ ! "$subtitle_track_info" ]; then
            break
        fi

        if [[ "$(echo "$all_subtitle_streams_info" | sed -n ${subtitle_track}p)" =~ '(forced)' ]]; then
            burned_subtitle_track="$subtitle_track"
            subtitle_track_list="$burned_subtitle_track"
            break
        fi

        subtitle_track="$((subtitle_track + 1))"
    done
fi

forced_subtitle_track_id=''
track_id='1'

for item in "${extra_subtitle_tracks[@]}"; do
    track_number="$(printf '%.0f' "$(echo "$item" | sed 's/^forced,//')" 2>/dev/null)"

    if (($track_number < 1)); then
        die "invalid additional subtitle track: $item"
    fi

    subtitle_track_info="$(echo "$all_subtitle_tracks_info" | sed -n ${track_number}p)"

    if [ ! "$subtitle_track_info" ]; then
        die "missing additional subtitle track: $input"
    fi

    if [ "$container_format" != 'mkv' ] && [[ "$subtitle_track_info" =~ '(PGS)' ]]; then
        die "incompatible additional subtitle track for MP4 format: track_number"
    fi

    if [ ! "$subtitle_track_list" ]; then
        subtitle_track_list="$track_number"
    else
        subtitle_track_list="$subtitle_track_list,$track_number"
    fi

    if [[ "$item" =~ ^'forced,' ]]; then

        if [ "$track_number" == "$burned_subtitle_track" ]; then
            die "forced subtitle track is already burned: $track_number"
        fi

        if [ "$container_format" == 'mkv' ]; then
            forced_subtitle_track_id="$track_id"
        else
            forced_subtitle_track_id="$track_index"
        fi
    fi

    track_id="$((track_id + 1))"
    track_index="$((track_index + 1))"
done

if [ "$subtitle_track_list" ]; then
    subtitle_options="--subtitle $subtitle_track_list"

    if [ "$burned_subtitle_track" ]; then
        subtitle_options="$subtitle_options --subtitle-burned"
    fi
else
    subtitle_options=''
fi

# OTHER SUBTITLES
#
tmp=''

if [ "$burned_srt_file" ] || ((${#extra_srt_files[*]} > 0)); then
    trap '[ "$tmp" ] && rm -rf "$tmp"' 0
    trap '[ "$tmp" ] && rm -rf "$tmp"; exit 1' SIGHUP SIGINT SIGQUIT SIGTERM

    tmp="/tmp/${program}.$$"
    mkdir -m 700 "$tmp" || exit 1
fi

srt_file_list=''
srt_codeset_list=''
srt_offset_list=''
srt_lang_list=''

if [ "$burned_srt_file" ]; then
    srt_file="$burned_srt_file"
    srt_offset=''
    srt_codeset=''

    while [[ "$srt_file" =~ ',' ]]; do
        srt_prefix="$(echo "$srt_file" | sed 's/,.*$//')"

        if [ ! "$srt_offset" ] && [[ "$srt_prefix" =~ ^[+-]?[0-9][0-9]*$ ]]; then
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
        syntax_error "missing burned subtitle filename"
    fi

    if [ ! -f "$srt_file" ]; then
        die "burned subtitle not found: $srt_file"
    fi

    tmp_srt_file_link="$tmp/burned-subtitle.srt"
    ln -s "$(cd "$(dirname "$srt_file")" 2>/dev/null && echo "$(pwd)/$(basename "$srt_file")")" "$tmp_srt_file_link"

    srt_file_list="$tmp_srt_file_link"
    srt_codeset_list="$srt_codeset"
    srt_offset_list="$srt_offset"
fi

for item in "${extra_srt_files[@]}"; do
    srt_file="$item"
    srt_lang=''
    srt_offset=''
    srt_codeset=''

    while [[ "$srt_file" =~ ',' ]]; do
        srt_prefix="$(echo "$srt_file" | sed 's/,.*$//')"

        if [ "$srt_prefix" == 'forced' ]; then

            if [ "$container_format" == 'mkv' ]; then
                forced_subtitle_track_id="$track_id"
            else
                forced_subtitle_track_id="$track_index"
            fi

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

    tmp_srt_file_link="$tmp/subtitle-$track_id.srt"
    ln -s "$(cd "$(dirname "$srt_file")" 2>/dev/null && echo "$(pwd)/$(basename "$srt_file")")" "$tmp_srt_file_link"

    if [ ! "$srt_file_list" ]; then
        srt_file_list="$tmp_srt_file_link"
        srt_codeset_list="$srt_codeset"
        srt_offset_list="$srt_offset"
        srt_lang_list="$srt_lang"
    else
        srt_file_list="$srt_file_list,$tmp_srt_file_link"
        srt_codeset_list="$srt_codeset_list,$srt_codeset"
        srt_offset_list="$srt_offset_list,$srt_offset"
        srt_lang_list="$srt_lang_list,$srt_lang"
    fi

    track_id="$((track_id + 1))"
    track_index="$((track_index + 1))"
done

if [ "$srt_file_list" ]; then
    srt_options="--srt-file $srt_file_list"

    if [ "$(echo "$srt_codeset_list" | sed 's/,//g')" ]; then
        srt_options="$srt_options --srt-codeset $srt_codeset_list"
    fi

    if [ "$(echo "$srt_offset_list" | sed 's/,//g')" ]; then
        srt_options="$srt_options --srt-offset $srt_offset_list"
    fi

    if [ "$(echo "$srt_lang_list" | sed 's/,//g')" ]; then
        srt_options="$srt_options --srt-lang $srt_lang_list"
    fi

    if [ "$burned_srt_file" ]; then
        srt_options="$srt_options --srt-burn"
    fi
else
    srt_options=''
fi

# OTHER OPTIONS
#
if [ "$media_title" == '1' ]; then
    title_options=''
else
    title_options="--title $media_title"
fi

section_options="$(echo "$section_options" | sed 's/^ *//')"

if [ "$preset" == 'medium' ]; then
    preset_options=''
else
    preset_options="--encoder-preset $preset"
fi

tune_options="$(echo "$tune_options" | sed 's/^ *//')"

encopts_options="vbv-maxrate=$vbv_maxrate:vbv-bufsize=$vbv_bufsize"

# Limit reference frames for playback compatibility with popular devices.
#
case $preset in
    slower|veryslow|placebo)
        encopts_options="ref=5:$encopts_options"
        ;;
esac

if [ "$max_rate_factor" ]; then
    encopts_options="$encopts_options:crf-max=$max_rate_factor"
fi

if [ "$extra_encopts_options" ]; then
    encopts_options="$(echo "$encopts_options:$extra_encopts_options" | sed 's/:*$//;s/:\{1,\}/:/g')"
fi

if [ "$crop_values" == 'auto' ]; then
    crop_options=''
else
    crop_options="--crop $crop_values"
fi

filter_options="$(echo "$filter_options" | sed 's/^ *//;s/ *$//;s/ \{1,\}/ /g')"

passthru_options="$(echo "$passthru_options" | sed 's/^ *//')"

# DEBUG OUTPUT
#
if [ "$debug" ]; then
    echo >&2
    echo "title_options             = $title_options" >&2
    echo "section_options           = $section_options" >&2
    echo "preset_options            = $preset_options" >&2
    echo "tune_options              = $tune_options" >&2
    echo "encopts_options           = $encopts_options" >&2
    echo "level_options             = $level_options" >&2
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
    echo >&2

    command="$(echo "HandBrakeCLI $title_options $section_options --markers --encoder x264 $preset_options $tune_options --encopts $encopts_options $level_options --quality $rate_factor $frame_rate_options $audio_options" | sed 's/ *$//;s/ \{1,\}/ /g')"

    if [ "$audio_track_name_list" ]; then
        command="$command $(escape_string "$audio_track_name_list")"
    fi

    command="$command $(echo "$crop_options $size_options $filter_options $subtitle_options $srt_options $passthru_options" | sed 's/^ *//;s/ *$//;s/ \{1,\}/ /g') --input $(escape_string "$input") --output $(escape_string "$output") 2>&1 | tee -a $(escape_string "${output}.log")"

    echo "$command"

    for item in "${audio_track_name_edits[@]}"; do
        track_id="$(echo "$item" | sed 's/,.*$//')"
        track_name="$(echo "$item" | sed 's/^[^,]*,//')"

        if [ "$container_format" == 'mkv' ]; then
            echo "[ -f $(escape_string "$output") ] && mkvpropedit --quiet --edit track:a$track_id --set name=$(escape_string "$track_name") $(escape_string "$output")"
        else
            echo "[ -f $(escape_string "$output") ] && mp4track --track-index $track_id --hdlrname $(escape_string "$track_name") $(escape_string "$output")"
            echo "[ -f $(escape_string "$output") ] && mp4track --track-index $track_id --udtaname $(escape_string "$track_name") $(escape_string "$output")"
        fi
    done

    if [ "$forced_subtitle_track_id" ]; then

        if [ "$container_format" == 'mkv' ]; then
            echo "[ -f $(escape_string "$output") ] && mkvpropedit --quiet --edit track:s$forced_subtitle_track_id --set flag-default=1 --set flag-forced=1 $(escape_string "$output")"
        else
            echo "[ -f $(escape_string "$output") ] && mp4track --track-index $forced_subtitle_track_id --enabled true $(escape_string "$output")"
        fi
    fi

    exit
fi

# OUTPUT
#
if [ "$container_format" == 'mkv' ]; then
    tool='mkvpropedit'
else
    tool='mp4track'
fi

if ( ((${#audio_track_name_edits[*]} > 0)) || [ "$forced_subtitle_track_id" ] ) && ! $(which $tool >/dev/null); then
    die "executable not in \$PATH: $tool"
fi

echo "Transcoding: $input" >&2

time {
    HandBrakeCLI \
        $title_options \
        $section_options \
        --markers \
        --encoder x264 \
        $preset_options \
        $tune_options \
        --encopts $encopts_options \
        $level_options \
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

    if [ -f "$output" ]; then

        for item in "${audio_track_name_edits[@]}"; do
            track_id="$(echo "$item" | sed 's/,.*$//')"
            track_name="$(echo "$item" | sed 's/^[^,]*,//')"

            if [ "$container_format" == 'mkv' ]; then
                mkvpropedit --quiet --edit track:a$track_id --set name="$track_name" "$output" || exit 1
            else
                mp4track --track-index $track_id --hdlrname "$track_name" "$output" &&
                mp4track --track-index $track_id --udtaname "$track_name" "$output" || exit 1
            fi
        done

        if [ "$forced_subtitle_track_id" ]; then

            if [ "$container_format" == 'mkv' ]; then
                mkvpropedit --quiet --edit track:s$forced_subtitle_track_id --set flag-default=1 --set flag-forced=1 "$output" || exit 1
            else
                mp4track --track-index $forced_subtitle_track_id --enabled true "$output" || exit 1
            fi
        fi
    fi
}
