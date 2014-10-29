#!/bin/bash
#
# detect-crop.sh
#
# Copyright (c) 2013-2014 Don Melton
#

about() {
    cat <<EOF
$program 3.1 of October 29, 2014
Copyright (c) 2013-2014 Don Melton
EOF
    exit 0
}

usage() {
    cat <<EOF
Detect crop values for video file or disc image directory to use with
\`mplayer\` and \`transcode-video.sh\` (a wrapper script for \`HandBrakeCLI\`).

Usage: $program [OPTION]... [FILE|DIRECTORY]

    --title NUMBER      select numbered title in video media (default: 1)
                            (\`0\` to scan media, list title numbers and exit)
    --max-step MINUTES  maximum interval between samples (default: 5)
                            (Must be integer between 1 and 10)
    --no-constrain      don't constrain crop to optimal shape

    --help              display this help and exit
    --version           output version information and exit

Requires \`HandBrakeCLI\` and \`mplayer\` executables in \$PATH.
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

calculate_crop() {

    if [ "$constrain" ]; then
        local delta_x="$(($width - $crop_width))"
        local delta_y="$(($height - $crop_height))"

        if (($delta_x && $delta_y)); then

            if (($delta_x > $delta_y)); then
                crop_height="$height"
                crop_y='0'
            else
                crop_width="$width"
                crop_x='0'
            fi
        fi

        local min_crop="$(($width / 64))"
        min_crop="$(($min_crop + ($min_crop % 2)))"
        delta_x="$(($width - $crop_width))"

        if (($delta_x && ($delta_x < $min_crop))); then
            crop_width="$width"
            crop_x='0'
        fi

        delta_y="$(($height - $crop_height))"

        if (($delta_y && ($delta_y < $min_crop))); then
            crop_height="$height"
            crop_y='0'
        fi
    fi

    if (($crop_width == 0)); then
        crop_width="$width"
    fi

    if (($crop_height == 0)); then
        crop_height="$height"
    fi

    if (($crop_x == $width)); then
        crop_x='0'
    fi

    if (($crop_y == $height)); then
        crop_x='0'
    fi

    mplayer_crop="$crop_width:$crop_height:$crop_x:$crop_y"
    handbrake_crop="$crop_y:$((height - (crop_y + crop_height))):$crop_x:$((width - (crop_x + crop_width)))"
}

escape_string() {
    echo "$1" | sed "s/'/'\\\''/g;/ /s/^\(.*\)$/'\1'/"
}

print_commands() {
    echo

    if [ -f "$input" ]; then
        echo "mplayer -really-quiet -nosound -vf rectangle=$1 $(escape_string "$input")"
        echo "mplayer -really-quiet -nosound -vf crop=$1 $(escape_string "$input")"
        echo
    fi

    echo "transcode-video.sh $([ "$title" == '1' ] || echo "--title $title ")--crop $2 $(escape_string "$input")"
    echo
}

readonly program="$(basename "$0")"

case $1 in
    --help)
        usage
        ;;
    --version)
        about
        ;;
esac

debug=''
title='1'
constrain='yes'
max_step=5

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
        --max-step|--step)
            max_step="$(printf '%.0f' "$2")"
            shift

            if (($max_step < 1)); then
                syntax_error 'maximum step value too small'

            elif (($max_step > 10)); then
                syntax_error 'maximum step value too large'
            fi
            ;;
        --no-constrain)
            constrain=''
            ;;
        --constrain)
            deprecated "$1"
            constrain='yes'
            ;;
        --with-handbrake)
            deprecated "$1"
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

if ! $(which mplayer >/dev/null); then
    die 'executable not in $PATH: mplayer'
fi

if [ "$title" == '0' ]; then
    echo "Scanning: $input" >&2
    samples='2'
else
    samples='1'
fi

media_info="$(HandBrakeCLI --title $title --scan --previews $samples:0 --input "$input" 2>&1)"

if [ "$debug" ]; then
    echo "$media_info" >&2
fi

if [ "$title" == '0' ]; then
    readonly formatted_titles_info="$(echo "$media_info" |
        sed -n '/^+ title /,$p' |
        sed '/^  + autocrop: /d;/^  + support /d;/^HandBrake/,$d;s/\(^ *\)+ \(.*$\)/\1\2/')"

    if [ ! "$formatted_titles_info" ]; then
        die "no media title available in: $input"
    fi

    echo "$formatted_titles_info"
    exit
fi

if [ ! "$(echo "$media_info" | sed -n '/^+ title /,$p')" ]; then
    echo "$program: \`title $title\` not found in: $input" >&2
    echo "Try \`$program --title 0 [FILE|DIRECTORY]\` to scan for titles." >&2
    echo "Try \`$program --help\` for more information." >&2
    exit 1
fi

readonly size_array=($(echo "$media_info" | sed -n 's/^  + size: \([0-9]\{1,\}\)x\([0-9]\{1,\}\).*$/\1 \2/p'))

if ((${#size_array[*]} != 2)); then
    die "no video size information in: $input"
fi

readonly width="${size_array[0]}"
readonly height="${size_array[1]}"

readonly duration_array=($(echo "$media_info" |
    sed -n 's/^  + duration: \([0-9][0-9]\):\([0-9][0-9]\):\([0-9][0-9]\)$/ \1 \2 \3 /p' |
    sed 's/ 0/ /g'))

if ((${#duration_array[*]} != 3)); then
    die "no duration information in: $input"
fi

readonly duration="$(((duration_array[0] * 60 * 60) + (duration_array[1] * 60) + duration_array[2]))"

if (($duration < 2)); then
    die "duration too short in: $input"
fi

max_step="$((max_step * 60))"

step="$((duration / 12))"

if (($step < 1)); then
    step='1'

elif (($step > $max_step)); then
    step="$max_step"
fi

samples="$(((duration / step) + 1))"

echo "Detecting: $input" >&2

if [ -f "$input" ]; then
    echo 'Scanning with `HandBrakeCLI`...' >&2
fi

media_info="$(HandBrakeCLI --title $title --scan --previews $samples:0 --input "$input" 2>&1)"

readonly autocrop_array=($(echo "$media_info" |
    sed -n 's|^  + autocrop: \([0-9/]*\)$|\1|p' |
    sed 's|/| |g'))

if ((${#autocrop_array[*]} != 4)); then
    die "no autocrop information in: $input"
fi

if [ "$debug" ]; then
    echo "${autocrop_array[*]}" | sed 's/ /:/g' >&2
fi

crop_x="${autocrop_array[2]}"
crop_y="${autocrop_array[0]}"
crop_width="$((width - crop_x - ${autocrop_array[3]}))"
crop_height="$((height - crop_y - ${autocrop_array[1]}))"

calculate_crop

first_mplayer_crop="$mplayer_crop"
first_handbrake_crop="$handbrake_crop"

if [ -f "$input" ]; then
    crop_width='0'
    crop_height='0'
    crop_x="$width"
    crop_y="$height"

    last_line=''
    last_timestamp="$(date +%s)"

    echo 'Scanning with `mplayer`...' >&2

    for start in $(seq $step $step $((duration - step))); do

        while read line; do

            if [ ! "$line" ]; then
                continue
            fi

            if [ "$line" != "$last_line" ]; then

                if [ "$debug" ]; then
                    echo "$line" >&2
                else
                    timestamp="$(date +%s)"

                    if ((($timestamp - $last_timestamp) >= 5)); then
                        last_timestamp="$timestamp"
                        echo 'Scanning with `mplayer`...' >&2
                    fi
                fi

                line_array=($(echo "$line" | sed 's/:/ /g'))

                if (($crop_width < ${line_array[0]})); then
                    crop_width="${line_array[0]}"
                fi

                if (($crop_height < ${line_array[1]})); then
                    crop_height="${line_array[1]}"
                fi

                if (($crop_x > ${line_array[2]})); then
                    crop_x="${line_array[2]}"
                fi

                if (($crop_y > ${line_array[3]})); then
                    crop_y="${line_array[3]}"
                fi
            fi

            last_line="$line"
        done < <(
            mplayer -quiet -benchmark -vo null -ao null -vf cropdetect=24:2 "$input" -ss $start -frames 10 2>/dev/null |
            sed -n 's/^.*crop=\([0-9]\{1,\}:[0-9]\{1,\}:[0-9]\{1,\}:[0-9]\{1,\}\).*$/\1/p'
        )
    done

    calculate_crop

    if [ "$mplayer_crop" != "$first_mplayer_crop" ] || [ "$handbrake_crop" != "$first_handbrake_crop" ]; then
        echo 'Results differ.' >&2
        echo
        echo '# From `HandBrakeCLI`:'
        print_commands "$first_mplayer_crop" "$first_handbrake_crop"
        echo '# From `mplayer`:'
    else
        echo 'Results are identical.' >&2
    fi
fi

print_commands "$mplayer_crop" "$handbrake_crop"
