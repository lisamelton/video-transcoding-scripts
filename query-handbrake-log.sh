#!/bin/bash
#
# query-handbrake-log.sh
#
# Copyright (c) 2014-2024 Lisa Melton
#

about() {
    cat <<EOF
$program 1.0 of November 21, 2014
Copyright (c) 2014-2024 Lisa Melton
EOF
    exit 0
}

usage() {
    cat <<EOF
Report information from HandBrake-generated \`.log\` files.

Usage: $program INFO [OPTION]... [FILE|DIRECTORY]...

Information types:
    time        time spent during transcoding
                    (sorted from short to long)
    speed       speed of transcoding in frames per second
                    (sorted from fast to slow)
    bitrate     video bitrate of transcoded output
                    (sorted from low to high)
    ratefactor  average P-frame quantizer for transcoding
                    (sorted from low to high)

Options:
    --reverse   reverse direction of sort
    --unsorted  don't sort

    --help      display this help and exit
    --version   output version information and exit

Results are written to standard output.
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

readonly program="$(basename "$0")"

case $1 in
    --help)
        usage
        ;;
    --version)
        about
        ;;
esac

if (($# < 1)); then
    syntax_error 'too few arguments'
fi

readonly info="$1"

case $info in
    time|bitrate|ratefactor)
        sort_options='--numeric-sort'
        ;;
    speed)
        sort_options='--numeric-sort --reverse'
        ;;
    *)
        syntax_error "unrecognized information type: $1"
        ;;
esac
shift

while [ "$1" ]; do
    case $1 in
        --reverse)
            case $info in
                time|bitrate|ratefactor)
                    sort_options='--numeric-sort --reverse'
                    ;;
                speed)
                    sort_options='--numeric-sort'
                    ;;
            esac
            ;;
        --unsorted)
            sort_options=''
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

if (($# < 1)); then
    syntax_error 'too few arguments'
fi

logs=()
directory_count='0'
last_directory=''

while [ "$1" ]; do

    if [ ! -e "$1" ]; then
        die "input not found: $1"
    fi

    if [ -d "$1" ]; then
        directory_logs=("$1"/*.log)
        directory_count="$((directory_count + 1))"
        last_directory="$(cd "$1" 2>/dev/null && pwd)"

        if ((${#directory_logs[*]} == 1)) && [ "$(basename "${directory_logs[0]}")" == '*.log' ]; then
            die "\`.log\` files not found: $1"
        else
            logs=("${logs[@]}" "${directory_logs[@]}")
        fi
    else
        file_directory="$(cd "$(dirname "$1")" 2>/dev/null && pwd)"

        if [ "$last_directory" != "$file_directory" ]; then
            directory_count="$((directory_count + 1))"
            last_directory="$file_directory"
        fi

        logs=("${logs[@]}" "$1")
    fi

    shift
done

for item in "${logs[@]}"; do
    video_name="$(basename "$item" | sed 's/\.log$//')"

    if (($directory_count > 1)); then
        video_name="$video_name ($(dirname "$item"))"
    fi

    case $info in
        time|speed)
            fps="$(grep 'average encoding speed' "$item" | sed 's/^.* \([0-9.]*\) fps$/\1/')"

            if [ ! "$fps" ]; then

                if [ "$info" == 'time' ]; then
                    echo "00:00:00 $video_name"
                else
                    echo "00.000000 fps $video_name"
                fi

                continue
            fi

            if [ "$(echo "$fps" | wc -l | sed 's/^[^0-9]*//')" == '2' ]; then

                # Calculate single `fps` result from two-pass `.log` file.
                #
                pass_1_fps="$(echo "$fps" | sed -n 1p)"
                pass_2_fps="$(echo "$fps" | sed -n 2p)"

                fps="$(ruby -e 'printf "%.6f", (1 / ((1 / '$pass_1_fps') + (1 / '$pass_2_fps')))')"
            fi

            if [ "$info" == 'time' ]; then
                duration="$(grep '+ duration: ' "$item" | sed 's/^.* \([0-9:]*\)$/\1/')"
                duration=($(echo " $duration " | sed 's/:/ /g;s/ 0/ /g'))
                duration="$(((duration[0] * 60 * 60) + (duration[1] * 60) + duration[2]))"

                rate="$(grep '+ frame rate: ' "$item")"

                if [ ! "$rate" ]; then
                    echo "00:00:00 $video_name"
                    continue
                fi

                rate="$(echo "$rate" | sed '$!d;s/^.*+ frame rate: //;s/^.* -> constant //;s/ fps -> .*$//;s/ fps$//')"

                duration="$(ruby -e 'printf "%.0f", (('$duration' * '$rate') / '$fps')')"

                ruby -e 'printf "%02d:%02d:%02d '"$video_name"'\n", '$((duration / (60 * 60)))', '$(((duration / 60) % 60))', '$((duration % 60))
            else
                echo "$fps fps $video_name"
            fi
            ;;
        bitrate)
            kbps="$(grep 'mux: track 0' "$item")"

            if [ ! "$kbps" ]; then
                echo "0000.00 kbps $video_name"
                continue
            fi

            echo "$(echo "$kbps" | sed 's/^.* \([0-9.]* kbps\).*$/\1/') $video_name"
            ;;
        ratefactor)
            qp="$(grep 'x26[45] \[info\]: frame P:' "$item")"

            if [ ! "$qp" ]; then
                echo "00.00 $video_name"
                continue
            fi

            echo "$(echo "$qp" | sed '$!d;s/^.* QP://;s/ *size:.*$//') $video_name"
            ;;
    esac

done |

if [ "$sort_options" ]; then
    sort $sort_options
else
    cat
fi
