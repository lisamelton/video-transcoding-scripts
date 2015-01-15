#!/usr/bin/env bash

usage() {
	echo "batch.sh path_to_videos"
	exit 0
}

input=$1
script_path="$(cd "$(dirname "$0")" && pwd)"

if [[ -d "$input" ]];
then
	files="$(find "$input" -name "*.mov")"
	# file="$(sed -n 1p <<< "$files")"
	
	echo "$files" | while read line; do
			echo "$line"
			
	        # echo "./transcode-video.sh --720p --fix_rotation \"$line\""
			output="$("$script_path"/transcode-video.sh --720p --fix_rotation --no_logs "$line" &)"
			# output=$("$script_path"/exit.sh --720p --fix_rotation "$line")
			
			echo "$output"
	        ((i++))
	done


	
	# while [ "$file" ]; do
	# 		sed '' 1d <<< "$files" || exit 1
	# 		
	# 		echo "transcode-video.sh --720p --fix_rotation \"$file\""
	# 		# transcode-video.sh --720p --fix_rotation "$file"
	# 		
	# 
	# 		file="$(sed -n 1p <<< "$files")"
	# 	done
else
	echo "Error, no input"
	usage
fi
