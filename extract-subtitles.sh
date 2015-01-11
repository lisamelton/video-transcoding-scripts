#!/bin/bash
#
# extract-subtitles.sh
#
# Copyright (c) 2015 Tobias Haeberle
#

about() {
    cat <<EOF
$program 1.0 of January 5, 2015
Copyright (c) 2015 Tobias Haeberle
EOF
    exit 0
}

usage() {
    cat <<EOF
Extract subtitle tracks from Matroska file.

Usage: $program [OPTION]... [FILE]

    --help          display this help and exit
    --version       output version information and exit
    --debug         print all subtitle tracks of input and exit
    --language CODE extract only subtitle tracks with language
                        \`CODE\`. Can be used multiple times.

Requires \`mkvmerge\`, \`mkvextract\` executables in \$PATH
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

languages=''
debug=''

while [ "$1" ]; do
    case $1 in
        --language)
            languages="$languages $2"
            shift
            ;;
        --debug)
            debug='1'
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

if [ ! -f "$input" ]; then
    die "input file not found: $input"
fi

for tool in mkvmerge mkvextract ; do

    if ! $(which $tool >/dev/null); then
        die "executable not in \$PATH: $tool"
    fi
done

readonly identification="$(mkvmerge --identify-verbose "$input")"
readonly input_container="$(echo "$identification" | sed -n 's/^File .*: container: \(.*\) \[.*\]$/\1/p')"

if [ ! "$input_container" ]; then
    die "unknown input container format: $input"
fi


if [  ! "$input_container" == "Matroska" ]; then
    die "unsupported input container format: $input"
fi

index='0'
extract_command=''
while read format; do
    track_id="$(echo "$format" | sed -n 's/^\([0-9]\{1,\}\) .*$/\1/p')"
    number="$(echo "$format" | sed -n 's/^number:\([0-9]\{1,\}\).*$/\1/p')"
    uid="$(echo "$format" | sed -n 's/^.*uid:\([0-9]\{1,\}\).*$/\1/p')"
    codec_id="$(echo "$format" | sed -n 's/^.*codec_id:\(.*\) codec_.*:.*$/\1/p')"
    language="$(echo "$format" | sed -n 's/^.*language:\([a-zA-Z]\{3\}\) .*$/\1/p')"

    if [ $debug ]; then
        echo "Track ID $format"
        continue
    fi

    if [ ! "$languages" == '' ]; then
        if [[ "$languages" =~ "$language" ]]; then
            extract_command="$extract_command $track_id:${track_id}_$language.sup"
        fi
    else 
        extract_command="$extract_command $track_id:${track_id}_$language.sup"
    fi

done < <(echo "$identification" | sed -n 's/^Track ID \([0-9]\{1,\}\): subtitles.* \[\(.*\)\]$/\1 \2/p')

if [ ! $debug ]; then
    if [ "$extract_command" ]; then
        mkvextract tracks "$input" $extract_command
    else
        die "No subtitle tracks found."
    fi
fi