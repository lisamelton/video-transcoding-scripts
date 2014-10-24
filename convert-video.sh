#!/bin/bash
#
# convert-video.sh
#
# Copyright (c) 2013-2014 Don Melton
#

about() {
    cat <<EOF
$program 1.0 of October 23, 2014
Copyright (c) 2013-2014 Don Melton
EOF
    exit 0
}

usage() {
    cat <<EOF
Convert video file from Matroska to MP4 format or from MP4 to Matroksa format
WITHOUT TRANSCODING.

Usage: $program [OPTION]... [FILE]

    --help      display this help and exit
    --version   output version information and exit

Requires \`mkvmerge\`, \`ffmpeg\` and \`mp4track\` executables in \$PATH
Output is written to current working directory.
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

readonly input="$1"

if [ ! "$input" ]; then
    syntax_error 'too few arguments'
fi

if [ ! -f "$input" ]; then
    die "input file not found: $input"
fi

for tool in mkvmerge ffmpeg mp4track; do

    if ! $(which $tool >/dev/null); then
        die "executable not in \$PATH: $tool"
    fi
done

readonly identification="$(mkvmerge --identify "$input")"
readonly input_container="$(echo "$identification" | sed -n 's/^File .*: container: //p')"

if [ ! "$input_container" ]; then
    die "unknown input container format: $input"
fi

case $input_container in
    'Matroska')
        container_format='mp4'
        ;;
    'QuickTime/MP4')
        container_format='mkv'
        ;;
    *)
        die "unsupported input container format: $input"
        ;;
esac

readonly output="$(basename "$input" | sed 's/\.[^.]*$//').$container_format"

if [ -e "$output" ]; then
    die "output file already exists: $output"
fi

readonly track0="$(echo "$identification" | sed -n 's/^Track ID 0: //p')"

if [ ! "$track0" ]; then
    die "missing video track: $input"
fi

# Require H.264 format video in first track.
#
if [ "$track0" != 'video (MPEG-4p10/AVC/h.264)' ]; then
    die "expected H.264 format video in first track of input file: $input"
fi

readonly track1="$(echo "$identification" | sed -n 's/^Track ID 1: //p')"

if [ ! "$track1" ]; then
    die "missing audio track: $input"
fi

# Require Dolby Digital (AC-3) or Advanced Audio Coding (AAC) format audio in
# second track.
#
if [ "$track1" != 'audio (AC3/EAC3)' ] && [ "$track1" != 'audio (AAC)' ]; then
    die "expected AC-3 or AAC format audio in second track of input file: $input"
fi

last_audio_track_index='1'

readonly track2="$(echo "$identification" | sed -n 's/^Track ID 2: //p')"

if [ "$input_container" == 'Matroska' ]; then

    if [ "$track1" == 'audio (AC3/EAC3)' ] && [ "$track2" == 'audio (AAC)' ]; then
        last_audio_track_index='2'
        map_options='-map 0:2 -map 0:1'
        adjust_enabled='true'
    else
        map_options='-map 0:1'
        adjust_enabled=''
    fi
else
    if [ "$track1" == 'audio (AAC)' ] && [ "$track2" == 'audio (AC3/EAC3)' ]; then
        last_audio_track_index='2'
        track_order='0:0,0:2,0:1'
        audio_tracks='2,1'
    else
        track_order='0:0,0:1'
        audio_tracks='1'
    fi
fi

index="$((last_audio_track_index + 1))"

while : ; do
    track="$(echo "$identification" | sed -n 's/^Track ID '$index': //p')"

    if [ "$track" != 'audio (AAC)' ]; then
        break
    fi

    if [ "$input_container" == 'Matroska' ]; then
        map_options="$map_options -map 0:$index"
    else
        track_order="$track_order,0:$index"
        audio_tracks="$audio_tracks,$index"
    fi

    index="$((index + 1))"
done

if [ "$input_container" == 'Matroska' ]; then
    echo "Converting to MP4 format: $input" >&2

    time {
        ffmpeg \
            -i "$input" \
            -map 0:0 \
            $map_options \
            -c copy \
            "$output" \
            || exit 1

        if [ "$adjust_enabled" ]; then
            mp4track --track-index 1 --enabled true "$output" &&
            mp4track --track-index 2 --enabled false "$output" || exit 1
        fi
    }
else
    readonly track_names="$(mp4track --list "$input" |
        sed -n '/userDataName/p' |
        sed 1d |
        sed 's/^[^=]*= //;s/^<absent>$//')"

    track_name_options=()

    for index in $(echo "$audio_tracks" | sed 's/,/ /g'); do
        name="$(echo "$track_names" | sed -n ${index}p)"

        if [ "$name" ]; then
            track_name_options=("${track_name_options[@]}" --track-name "$index:$name")
        fi
    done

    echo "Converting to Matroska format: $input" >&2

    time mkvmerge \
        --output "$output" \
        --track-order $track_order \
        --disable-track-statistics-tags \
        --audio-tracks $audio_tracks \
        "${track_name_options[@]}" \
        "$input" \
        || exit 1
fi
