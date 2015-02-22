#!/bin/bash
#
# setup.sh
#
# Bootstrap an OS X system for transcoding

set -eux

brew update

brew install caskroom/cask/brew-cask

brew cask install handbrakecli

brew install mkvtoolnix mplayer mp4v2

brew install --with-faac --with-fdk-aac ffmpeg
