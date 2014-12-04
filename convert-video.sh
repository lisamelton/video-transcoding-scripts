#!/bin/bash
#
# convert-video.sh
#
# Copyright (c) 2013-2014 Don Melton
#

about() {
    cat <<EOF
$program 2.0 of December 3, 2014
Copyright (c) 2013-2014 Don Melton
EOF
    exit 0
}

usage() {
    cat <<EOF
Convert video file from Matroska to MP4 format or from MP4 to Matroksa format
WITHOUT TRANSCODING VIDEO.

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

readonly identification="$(mkvmerge --identify-verbose "$input")"
readonly input_container="$(echo "$identification" | sed -n 's/^File .*: container: \(.*\) \[.*\]$/\1/p')"

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

video_track=''
ac3_audio_track=''
aac_audio_track=''
extra_aac_audio_track_list=''
other_audio_track=''
index='0'

while read format; do

    if [ ! "$video_track" ] && [ "$format" == 'video (MPEG-4p10/AVC/h.264)' ]; then
        video_track="$index"
    fi

    if [[ "$format" =~ ^'audio ' ]]; then

        case $format in
            'audio (AC3/EAC3)')

                if [ ! "$ac3_audio_track" ] && [ ! "$other_audio_track" ]; then
                    ac3_audio_track="$index"
                fi
                ;;
            'audio (AAC)')

                if [ ! "$other_audio_track" ]; then

                    if [ ! "$aac_audio_track" ]; then
                        aac_audio_track="$index"
                    else
                        extra_aac_audio_track_list="$extra_aac_audio_track_list,$index"
                    fi
                fi
                ;;
            *)
                if [ "$input_container" == 'Matroska' ] && [ ! "$other_audio_track" ] && [ ! "$ac3_audio_track" ] && [ ! "$aac_audio_track" ]; then
                    other_audio_track="$index"
                fi
                ;;
        esac
    fi

    index="$((index + 1))"

done < <(echo "$identification" | sed -n '/^Track ID /s/^Track ID [0-9]\{1,\}: \(.*\) \[.*\]$/\1/p')

if [ ! "$video_track" ]; then
    die "missing H.264 format video track: $input"
fi

if [ "$input_container" == 'Matroska' ]; then
    map_options="-map 0:$video_track"
    codec_options='-c copy'

    if [ "$aac_audio_track" ]; then
        map_options="$map_options -map 0:$aac_audio_track"
    fi

    if $(ffmpeg -version | grep enable-libfdk-aac >/dev/null); then
        aac_encoder='libfdk_aac'
    else
        aac_encoder='libfaac'
    fi

    if [ "$ac3_audio_track" ]; then
        map_options="$map_options -map 0:$ac3_audio_track"

        if [ ! "$aac_audio_track" ]; then
            map_options="$map_options -map 0:$ac3_audio_track"
            codec_options="-c:v copy -ac 2 -c:a:0 $aac_encoder -b:a:0 160k -c:a:1 copy"
        fi
    fi

    if [ "$extra_aac_audio_track_list" ]; then
        map_options="$map_options$(echo "$extra_aac_audio_track_list" | sed 's/,/ -map 0:/g')"
    fi

    if [ "$other_audio_track" ]; then
        map_options="$map_options -map 0:$other_audio_track"

        readonly channels="$(echo "$identification" |
            sed -n '/^Track ID '$other_audio_track': /s/^.* audio_channels:\([0-9]\{1,\}\).*$/\1/p')"

        if [ "$channels" ] && (($channels > 2)); then
            map_options="$map_options -map 0:$other_audio_track"
            codec_options="-c:v copy -ac 2 -c:a:0 $aac_encoder -b:a:0 160k -ac 6 -c:a:1 ac3 -b:a:1 384k"
        else
            codec_options="-c:v copy -ac 2 -c:a $aac_encoder -b:a 160k"
        fi
    fi

    echo "Converting to MP4 format: $input" >&2

    time {
        ffmpeg \
            -i "$input" \
            $map_options \
            $codec_options \
            "$output" \
            || exit 1

        if [ "$aac_audio_track" ] || [ "$ac3_audio_track" ] || [ "$other_audio_track" ]; then
            flag='true'
            index='1'

            while read enabled_flag; do

                if [ "$enabled_flag" != "$flag" ]; then
                    mp4track --track-index $index --enabled $flag "$output" || exit 1
                fi

                flag='false'
                index="$((index + 1))"

            done < <(mp4track --list "$output" | sed -n '/enabled/p' | sed 1d | sed 's/^[^=]*= //')
        fi
    }
else
    track_order="0:$video_track"
    audio_tracks=''

    if [ "$ac3_audio_track" ]; then
        track_order="$track_order,0:$ac3_audio_track"
        audio_tracks="$ac3_audio_track"
    fi

    if [ "$aac_audio_track" ]; then
        track_order="$track_order,0:$aac_audio_track"

        if [ "$ac3_audio_track" ]; then
            audio_tracks="$audio_tracks,$aac_audio_track"
        else
            audio_tracks="$aac_audio_track"
        fi

        if [ "$extra_aac_audio_track_list" ]; then
            track_order="$track_order$(echo "$extra_aac_audio_track_list" | sed 's/,/,0:/g')"
            audio_tracks="$audio_tracks$extra_aac_audio_track_list"
        fi
    fi

    track_name_options=()

    if [ "$audio_tracks" ]; then
        audio_tracks_option="--audio-tracks $audio_tracks"

        readonly track_names="$(mp4track --list "$input" |
            sed -n '/userDataName/p' |
            sed 1d |
            sed 's/^[^=]*= //;s/^<absent>$//')"

        for index in $(echo "$audio_tracks" | sed 's/,/ /g'); do
            name="$(echo "$track_names" | sed -n ${index}p)"

            if [ "$name" ]; then
                track_name_options=("${track_name_options[@]}" --track-name "$index:$name")
            fi
        done
    else
        audio_tracks_option='--no-audio'
    fi

    echo "Converting to Matroska format: $input" >&2

    time mkvmerge \
        --output "$output" \
        --track-order $track_order \
        --disable-track-statistics-tags \
        $audio_tracks_option \
        "${track_name_options[@]}" \
        "$input" \
        || exit 1
fi
