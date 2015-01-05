# Video Transcoding Scripts

Utilities to transcode, inspect and convert videos.

## About

Hi, I'm [Don Melton](http://donmelton.com/). I wrote these scripts to transcode my collection of Blu-ray Discs and DVDs into a smaller, more portable format while remaining high enough quality to be mistaken for the originals.

While I've used rougher versions of these scripts for many years, I didn't publish any of them until I was featured in, "[How to rip and transcode video for the best quality possible](http://www.imore.com/vector-22-don-melton-transcoding-video)," a podcast with [Rene Ritchie](https://twitter.com/reneritchie). Those initial scripts were only available as separate Gists on GitHub. Now they're all collected in this repository:

<https://github.com/donmelton/video-transcoding-scripts>

All of these scripts are written in [Bash](http://www.gnu.org/software/bash/) and leverage excellent Open Source and cross-platform software like [HandBrake](https://handbrake.fr/), [MKVToolNix](https://www.bunkus.org/videotools/mkvtoolnix/), [MPlayer](http://mplayerhq.hu/), [FFmpeg](http://ffmpeg.org/), and [MP4v2](https://code.google.com/p/mp4v2/). These scripts are essentially intelligent wrappers around these other tools, designed to be executed from the command line shell.

Even if you don't use any of these scripts, you may find their source code or this "README" document helpful.

### Transcoding with `transcode-video.sh`

The primary script is `transcode-video.sh` and I wrote it because the preset system built into HandBrake wasn't quite powerful enough to automatically change bitrate and other encoding options based on different inputs. Plus, HandBrake's default presets themselves didn't produce what I wanted in terms of predictable output size with sufficient quality.

HandBrake's "AppleTV 3" preset is closest to what I wanted but transcoding "[Planet Terror (2007)](http://www.blu-ray.com/movies/Planet-Terror-Blu-ray/1248/)" with it results in a huge video bitrate of 19.9 Mbps, very near the original of 22.9 Mbps. And transcoding "[The Girl with the Dragon Tattoo (2011)](http://www.blu-ray.com/movies/The-Girl-with-the-Dragon-Tattoo-Blu-ray/35744/)," while much smaller in output size, lacks detail compared to the original.

Videos from the [iTunes Store](https://en.wikipedia.org/wiki/ITunes_Store) were my template for a smaller and more portable transcoding format. Their files are very good quality, only about 20% the size of the same video on a Blu-ray Disc, and play on a wide variety of devices.

To follow that template, the `transcode-video.sh` script configures the [x264 video encoder](http://www.videolan.org/developers/x264.html) within HandBrake to use a [constrained variable bitrate (CVBR)](https://en.wikipedia.org/wiki/Variable_bitrate) mode, and to automatically target bitrates appropriate for different input resolutions.

Input resolution | Target video bitrate
--- | ---
1080p or Blu-ray video | 5 Mbps
720p | 4 Mbps
480i, 576p or DVD video | 2 Mbps

These targets are technically maximum bitrates. But since this script modifies CVBR mode with a minimum quality threshold, x264 is allowed to exceed these bitrate limits to maintain that quality level. However, the final output video bitrate is still usually below or near the target. And almost always below the target when additional compression is applied via x264's preset system.

Which makes videos transcoded with this script very near the same size, quality and configuration as those from the iTunes Store, including their audio tracks.

If possible, audio is first passed through in its original form. This hardly ever works for Blu-ray Discs but it often will for DVDs and other random videos since this script can take almost any movie file as input.

When audio transcoding is required, it's done in [AAC format](https://en.wikipedia.org/wiki/Advanced_Audio_Coding) and, if the original is [multi-channel surround sound](https://en.wikipedia.org/wiki/Surround_sound), in [Dolby Digital AC-3 format](https://en.wikipedia.org/wiki/Dolby_Digital). Meaning the output can contain two tracks from the same source in different formats.

Input channels | Pass through | AAC track | AC-3 track
--- | --- | --- | ---
Mono | AAC only | 80 Kbps | none
Stereo | AAC only | 160 Kbps | none
Surround | AC-3 only, up to 448 Kbps | 160 Kbps | 384 Kbps with 5.1 channels

The surround pass through bitrate is `448 Kbps` because this is common on DVDs and re-encoding that at `384 Kbps` could degrade quality.

Additionally, the `transcode-video.sh` script automatically burns any forced subtitle track it detects into the output video track. "Burning" means that the subtitle becomes part of the video itself and isn't retained as a separate track. A "forced" subtitle track is detected by a special flag on that track in the input.

However, automatic forced subtitle detection only works when the input is a single file and not a disc image directory.

Another automatic behavior of `transcode-video.sh` is forcing a lower frame rate or applying a `deinterlace` filter to reduce jerky motion and visible artifacts in [interlaced video](https://en.wikipedia.org/wiki/Interlaced_video).

Most automatic behaviors in this script can be overridden or augmented with additional options. But, other than specifying cropping bounds, using `transcode-video.sh` can be as simple as this:

    transcode-video.sh "/path/to/Movie.mkv"

Which creates, after what is hopefully a reasonable amount of time, two files in the current working directory:

    Movie.mp4
    Movie.mp4.log

The first file is obviously the output video in [MP4 format](https://en.wikipedia.org/wiki/MPEG-4_Part_14). The second, while not as entertaining, is still useful since it's a log file from which performance metrics, video bitrate, relative quality, etc. can be extracted later.

### Crop detection with `detect-crop.sh`

One transcoding option I usually add on the command line is cropping bounds. And I wrote the `detect-crop.sh` script because this can't be done safely with an automatic behavior in `transcode-video.sh`.

Removing the black, non-content borders of a video during transcoding is not about making the edges of the output look pretty. Those edges are usually not visible anyway when viewed full screen.

Cropping is about faster transcoding and higher quality. Fewer pixels to read and write almost always leads to a speed improvement. Fewer pixels also means the x264 encoder within HandBrake doesn't waste bitrate on non-content.

HandBrake applies automatic crop detection by default. While it's usually correct, it does guess wrong often enough not to be trusted without review. For example, HandBrake's default behavior removes the top and bottom 140 pixels from "[The Dark Knight (2008)](http://www.blu-ray.com/movies/The-Dark-Knight-Blu-ray/743/)" and "[The Hunger Games: Catching Fire (2013)](http://www.blu-ray.com/movies/The-Hunger-Games-Catching-Fire-Blu-ray/67923/)," losing significant portions of their full-frame content.

And sometimes HandBrake only crops a few pixels from one or more edges, which is too small of a difference in size to improve performance or quality.

This is why `transcode-video.sh` doesn't allow HandBrake to apply cropping by default.

Instead, the `detect-crop.sh` script leverages both HandBrake and MPlayer, with additional measurements and constraints, to find the optimal video cropping bounds. It then indicates whether those two programs agree. To aid in review, this script prints commands to the terminal console allowing the recommended (or disputed) crop to be displayed, as well as sample command lines for `transcode-video.sh` itself. And it's this easy to use:

    detect-crop.sh "/path/to/Movie.mkv"

Which prints out something like this:

    Detecting: /path/to/Movie.mkv
    Scanning with `HandBrakeCLI`...
    Scanning with `mplayer`...
    Scanning with `mplayer`...
    Scanning with `mplayer`...
    Scanning with `mplayer`...
    Scanning with `mplayer`...
    Results are identical.

    mplayer -really-quiet -nosound -vf rectangle=1920:816:0:132 '/path/to/Movie.mkv'
    mplayer -really-quiet -nosound -vf crop=1920:816:0:132 '/path/to/Movie.mkv'

    transcode-video.sh --crop 132:132:0:0 '/path/to/Movie.mkv'

Just copy and paste the sample commands to preview or transcode.

When input is a disc image directory instead of a single file, the `detect-crop.sh` script does not use MPlayer, nor does it print out commands to preview the crop.

### Conversion with `convert-video.sh`

All videos from the iTunes Store are in MP4 format, which is what `transcode-video.sh` creates by default. But this script can also generate [Matroska format](https://en.wikipedia.org/wiki/Matroska) with the `--mkv` option like this:

    transcode-video.sh --mkv --crop 132:132:0:0 "/path/to/Movie.mkv"

Which creates these two files in the current working directory:

    Movie.mkv
    Movie.mkv.log

And I prefer generating Matroska format `.mkv` files because I can preview them with MPlayer or [VLC](http://www.videolan.org/vlc/) while they're being transcoded. That's just not possible with MP4 format.

But sometimes I like to play my videos on my iPhone or iPad and those devices work best with MP4 format. So I wrote the `convert-video.sh` script to repackage my videos into the other format without re-transcoding them. And it can work both ways, Matroska to MP4 or vice versa.

    convert-video.sh "Movie.mkv"

Which creates this MP4 file in the current working directory:

    Movie.mp4

Or...

    convert-video.sh "Movie.mp4"

Which creates this Matroska file in the current working directory:

    Movie.mkv

This script requires a properly organized file, in either format, with compatible video and audio tracks. Most output video files from `transcode-video.sh` meet this criteria, but videos from other sources can sometimes fail. Subtitle tracks are not converted.

## Requirements

All of these scripts work on OS X because that's the platform where I develop, test and use them. But none of them actually require OS X so, technically, they should also work on Windows and Linux. Your mileage may vary.

Since these scripts are essentially intelligent wrappers around other software, they do require certain command line tools to function. Most of these dependencies are available via [Homebrew](http://brew.sh/), a package manager for OS X. However, HandBrake is available via [Homebrew Cask](http://caskroom.io/), an extension to Homebrew.

HandBrake can also be downloaded and installed manually.

Tool | Transcoding | Crop detection | Conversion | Package | Cask
--- | --- | --- | --- | --- | ---
`HandBrakeCLI` | required | required | | | `handbrakecli`
`mkvpropedit` | required | | | `mkvtoolnix` | &nbsp;
`mplayer` | | required | | `mplayer` | &nbsp;
`mkvmerge` | | | required | `mkvtoolnix` | &nbsp;
`ffmpeg` | | | required | `ffmpeg` | &nbsp;
`mp4track` | required | | required | `mp4v2` | &nbsp;

As of version 5.0, `transcode-video.sh` requires HandBrake version 0.10.0 or later.

Installing a package with Homebrew is as simple as:

    brew install mkvtoolnix

To install both Homebrew Cask and `HandBrakeCLI`, the command line version of HandBrake:

    brew install caskroom/cask/brew-cask
    brew cask install handbrakecli

Nightly builds of HandBrake are also available. While often containing more up-to-date libraries, these versions of HandBrake are not always stable. Use them with caution.

To install both Homebrew Cask and a nightly build of `HandBrakeCLI`:

    brew install caskroom/cask/brew-cask
    brew cask install caskroom/versions/handbrakecli-nightly

### Downloading and installing HandBrake manually

You can find the official release of `HandBrakeCLI` here:

<https://handbrake.fr/downloads.php>

Or a nightly build of `HandBrakeCLI` here:

<https://handbrake.fr/nightly.php>

Whichever version you choose, make sure you download a disk image file containing the command line tool `HandBrakeCLI`, and not just the `HandBrake` application. Disk images containing `HandBrakeCLI` have "CLI" in the filename.

Open the disk image and then copy `HandBrakeCLI` to a directory listed in your `PATH` environment variable such as `/usr/local/bin`.

## Installation

As of now, all of my scripts must be installed manually.

You can retrieve them via the command line by cloning the entire repository like this:

    git clone https://github.com/donmelton/video-transcoding-scripts.git

Or download them individually from the GitHub website here:

<https://github.com/donmelton/video-transcoding-scripts>

Make sure each script is executable by setting its permissions like this:

    chmod +x transcode-video.sh

And then copy the scripts to a directory listed in your `PATH` environment variable such as `/usr/local/bin`.

## Usage

All of these scripts can take a single video file as their only argument:

    transcode-video.sh "/path/to/Movie.mkv"

Use `--help` to understand how to override their default behavior with other options:

    transcode-video.sh --help

Use `--fullhelp` to see more than just basic options for `transcode-video.sh`:

    transcode-video.sh --fullhelp

This built-in help is available even if a script's software dependencies are not yet installed.

While `transcode-video.sh` and `detect-crop.sh` work best with a single video file, both also accept a disc image directory as input:

    transcode-video.sh "/path/to/Movie disc image directory/"

Disc image directories are unencrypted backups of Blu-ray Discs or DVDs. Typically these formats include more than one video title. These additional titles can be bonus features, alternate versions of a movie, multiple TV show episodes, etc.

By default, the first title in a disc image directory is selected for transcoding or crop detection. Sometimes this is what you want. But most of the time it'll be the wrong choice.

If you know the title number you want, e.g. title number `25`, you can specify it with the `--title` option:

    transcode-video.sh --title 25 "/path/to/Movie disc image directory/"

But usually you need to scan the disk image first to find the correct title number. Scanning is done by using special title number `0`:

    transcode-video.sh --title 0 "/path/to/Movie disc image directory/"

All the titles in the disc image directory are then listed, along with other useful information like duration and format, so you can identify exactly which title you want. 

## Guide

### Alternatives to transcoding your media

Before using `transcode-video.sh` or any manual transcoding system, consider these four alternatives:

1. Buy or rent videos from online services like Apple, Amazon, Netflix, Hulu, YouTube, etc. Check "[Can I Stream.It?](http://www.canistream.it/)" to see if what you want to watch is available.
    * Upside: Often cheaper than buying physical media like Blu-ray Discs and DVDs.
    * Upside: Much easier to store and catalog than physical media.
    * Upside: Usually playable on mobile devices.
    * Downside: Most online services use [digital rights management (DRM)](https://en.wikipedia.org/wiki/Digital_rights_management), locking you into certain devices or ecosystems.
    * Downside: We're still years away from a [Spotify](https://www.spotify.com/)-like service for video, so it's likely you'll need to subscribe to multiple services to see anything close to the selection you want.
    * Downside: Even with shopping around, you probably won't find everything you want online.
    * Downside: Video and audio quality of online formats are nowhere close to that of Blu-ray Discs.
    * Downside: Online formats usually don't have the breadth of bonus content available on physical media.
2. Watch your existing collection of Blu-ray Discs and DVDs on a hardware disc player.
    * Upside: No doubt you bought a player when you bought the discs.
    * Upside: A hardware disc player is the best vehicle for viewing bonus content and interactive features.
    * Downside: Players are noisy, cumbersome, and cluttered with warnings, trailers and other crap to keep you away from promptly watching your videos.
    * Downside: Shuffling discs back and forth from their cases to the player is tedious and risks damage to the original media.
3. [Rip](https://en.wikipedia.org/wiki/Ripping) your collection of discs and watch them in their original format on your [digital media player](https://en.wikipedia.org/wiki/Digital_media_player).
    * Upside: Retains original high quality video and audio.
    * Upside: Ripping is usually necessary for transcoding anyway.
    * Downside: Requires a large capacity hard drive or [network-attached storage (NAS)](https://en.wikipedia.org/wiki/Network-attached_storage) device to hold the ripped files.
    * Downside: Most digital media players, like the [Apple TV](https://www.apple.com/appletv/) or [Roku](https://www.roku.com/), don't support playback of ripped media formats. You'll probably need a custom [Mac mini](http://www.apple.com/mac-mini/) or other computer configured as a [home theater PC (HTPC)](https://en.wikipedia.org/wiki/Home_theater_PC).
4. Dynamically transcode your ripped video files with [Plex Media Server](https://plex.tv/).
    * Upside: Easy to install, configure and use.
    * Upside: Automatically adjusts transcoding quality and size for different devices.
    * Downside: Requires a powerful enough computer somewhere on your network to act as the server and do the actual real-time transcoding.
    * Downside: Dynamic transcoding can produce noticeable quality defects in some videos.

### Preparing your media for transcoding

I have four rules when preparing my own media for transcoding:

1. Use [MakeMKV](http://www.makemkv.com/) to rip Blu-ray Discs and DVDs.
2. Rip each selected video as a single Matroska format `.mkv` file.
3. Look for forced subtitles and isolate them in their own track.
4. Convert lossless audio tracks to [FLAC format](https://en.wikipedia.org/wiki/FLAC).

Why MakeMKV?

* It runs on most desktop computer platforms like OS X, Windows and Linux. There's even a free version available to try before you buy.
* It was designed to decrypt and extract a video track, usually the main feature, of a disc and convert it into a single Matroska format `.mkv` file. And it does this really, really well.
* It can also make an unencrypted backup of your entire Blu-ray or DVD to a disc image directory.
* It's not pretty and it's not particularly easy use. But once you figure out how it works, you can rip your video exactly the way you want.

Why a single `.mkv` file?

* Many automatic behaviors and other features in both `transcode-video.sh` and `detect-crop.sh` are not available when input is a disc image directory. This is because that format limits the ability of `HandBrakeCLI` to detect or manipulate certain information about the video.
* Both forced subtitle extraction and lossless audio conversion, detailed below, are not possible when input is a disc image directory.

Why bother with forced subtitles?

* Remember "[The Hunt for Red October (1990)](http://www.blu-ray.com/movies/The-Hunt-For-Red-October-Blu-ray/920/)" when Sean Connery and Sam Neill are speaking actual Russian at the beginning of the movie instead of just using cheesy accents like they did the rest of the time? If you speak English, the Blu-ray Disc version provides English subtitles just for those few scenes. They're "forced" on screen for you. Which is actually very convenient.
* Forced subtitles are often embedded within a full subtitle track. And a special flag is set on the portion of that track which is supposed to be forced. MakeMKV can recognize that flag when it converts the video into a single `.mkv` file. It can even extract just the forced portion of that subtitle into a another separate subtitle track. And it can set a different "forced" flag in the output `.mkv` file on that separate track so other software can tell what it's for.
* Not all discs with forced subtitles have those subtitles embedded within other tracks. Sometimes they really are separate. But enough discs are designed with the embedded technique that you should avoid using a disc image directory as input for transcoding.

Why convert lossless audio?

* [DTS-HD Master Audio](https://en.wikipedia.org/wiki/DTS-HD_Master_Audio) is the most popular high definition, lossless audio format. It's used on more than 80% of all Blu-ray Discs.
* HandBrake, FFmpeg, MPlayer and other Open Source software can't decode the lossless portion of a DTS-HD audio track. They're only able to extract the non-HD, lossy core which is in [DTS format](https://en.wikipedia.org/wiki/DTS_(sound_system)).
* But MakeMKV can [decode DTS-HD with some help from additional software](http://www.makemkv.com/dtshd/) and convert it into FLAC format which can then be decoded by HandBrake and most other software. Once again, MakeMKV can only do this when it converts the video into a single `.mkv` file.

### The evolution of rate control in `transcode-video.sh`

The x264 video encoder within HandBrake provides either a specific video bitrate or a constant rate factor (CRF) to control how bits are allocated.

Using a specific video bitrate while encoding in one pass through the input is known as average bitrate (ABR) mode. It's called an "average" because a single pass can only approximate the target bitrate, although it usually comes very close.

ABR mode creates output of predictable size with unpredictable quality.

Versions of `transcode-video.sh` prior to 3.0 used a modified ABR mode that improved quality by allowing the bitrate to vary much, much more. This was done by setting x264's rate tolerance, how much it allows bitrate to vary, to the highest possible (or infinite) value. This was known as the "`ratetol=inf`" hack.

About 90% of the time, this modified ABR mode hack worked very well. But there were a some cases where it performed poorly, producing noticeable quality defects.

Using a constant rate factor is known as variable bitrate (VBR) mode. A rate factor is basically an arbitrary number targeting a constant level of quality. The x264 default CRF value is `23`. Lower values increase quality and bitrate. Higher values lower quality and bitrate. But because the target is a quality level, bitrate always varies significantly depending on input.

VBR mode creates output of predictable quality with unpredictable size.

Version 3.0 of `transcode-video.sh` switched to using a constrained variable bitrate (CVBR) mode. This mode set a specific upper limit on bitrate so that it behaved a bit like ABR mode. And that limit wasn't exceeded even when a higher level of quality was selected via the CRF value of `18`.

This constraint was imposed by using x264's video buffer verifier (VBV) system. Normally this system is used for bandwidth constrained situations such as streaming video.

Using the VBV system typically means providing two parameters to x264. The first is the maximum rate and the second is the buffer size. The maximum rate is the constraint. Typically the buffer size is set to the same value. But when the maximum rate is a low bitrate, as used by `transcode-video.sh`, then a buffer size of the same value will cause a noticeable quality defect with some input.

This particular defect usually manifests itself in flat, grainy areas of the input so that it appears as if these areas are going in and out of focus. It's very annoying.

Version 3.0 of `transcode-video.sh` eliminated this defect by setting the VBV buffer size to _half_ that of the maximum rate. I discovered this almost by accident and still have no idea why the trick works.

About 95% of the time, this CVBR mode worked very well. It was a significant improvement over the older modified ABR mode hack. But there were a few cases where CVBR mode performed poorly, producing other noticeable quality defects.

These other defects were caused by the hard upper limit on bitrate. To correctly transcode some input, sometimes you need a bigger bitrate.

Additionally, even a CRF value of `18` wasn't high enough quality. Bitrates were too low in some cases, which didn't cause defects so much as a loss of detail when compared to the original.

### How _modified_ constrained variable bitrate (CVBR) mode works

Current versions of `transcode-video.sh` modify CVBR mode to impose a minimum quality threshold so that x264 is allowed to exceed bitrate limits to maintain that quality level. This new constraint is simply a maximum CRF value of `25`. Additionally, the target CRF value has been lowered to `16`.

Together, maximum bitrate and maximum CRF essentially vie for control of the final output video bitrate, with the target CRF value doing its best to make helpful suggestions. What should be chaos turns out beautifully. Even though x264 spews the occasional "VBV underflow" error, it can be safely ignored.

This means the VBV maximum bitrate becomes a target bitrate when combined with a maximum CRF value. While the final output video bitrate is still usually below or near the target, it can sometimes get larger. On very rare occasions it can even be more than twice the target.

Don't panic. When additional compression is applied via x264's preset system, the output bitrate is almost always below or near the target.

If you don't want to apply additional compression to guarantee bitrates are below the target, and you're willing to sacrifice some quality in exchange for size, then you could raise both the CRF and maximum CRF values:

    transcode-video.sh --crf 18 --crf-max 26 "/path/to/Movie.mkv"

This is essentially what the experimental `--hq` option introduced in version 3.5 of `transcode-video.sh` did. That option is now deprecated, superseded by the new defaults.

Changing any of these rate control options has to be done very carefully. And I don't recommend it. Use the defaults.

### Supersize your transcoding with `--big`

If reducing output size is less important to you than the possibility of increasing quality, then you can simply raise the default bitrate limits for both video and Dolby Digital AC-3 audio.

For 1080p or Blu-ray Disc input, you could do this:

    transcode-video.sh --max 8000 --ac3 640 "/path/to/Movie.mkv"

Which sets the target video bitrate to `8000 Kbps` or `8 Mbps`, and the AC-3 audio bitrate, including the pass through bitrate, to `640 Kbps`.

But you would likely need to adjust that video bitrate a bit for DVD or other input. Instead, use the `--big` option:

    transcode-video.sh --big "/path/to/Movie.mkv"

With `--big`, the `transcode-video.sh` script does all the work for you based on the video resolution of your input.

Input resolution | Target video bitrate with `--big`
--- | ---
1080p or Blu-ray video | 8 Mbps
720p | 6 Mbps
480i, 576p or DVD video | 3 Mbps

For audio input, the change via `--big` is the same as using `--ac3 640`. Obviously this means there's no impact on the output bitrate of mono and stereo AAC audio tracks.

Input channels | Pass through<br />with `--big` | AAC track<br />with `--big` | AC-3 track<br />with `--big`
--- | --- | --- | ---
Mono | AAC only | 80 Kbps | none
Stereo | AAC only | 160 Kbps | none
Surround | AC-3 only, up to 640 Kbps | 160 Kbps | 640 Kbps with 5.1 channels

Keep in mind there's no guarantee that using `--big` will make perceptible quality improvements for every video. But it will improve some of them. Your mileage may vary.

Also, using `--big` will reduce performance. Why? You're doing more calculations and writing more bits out to disk. And that takes more time.

### Understanding and using the x264 preset system

The `--preset` option in `transcode-video.sh` controls the x264 video encoder, not the other preset system built into HandBrake. It takes a preset name as its single argument:

    transcode-video.sh --preset slow "/path/to/Movie.mkv"

Some x264 presets are also available as shortcut options, i.e. you can use just `--slow` instead of having to type `--preset slow`:

    transcode-video.sh --slow "/path/to/Movie.mkv"

The x264 presets are supposed to trade encoding speed for compression efficiency, and their names attempt to reflect this. However, that's not quite how they always work.

Preset name | Shortcut option | Note
--- | --- | ---
`ultrafast` | none | not recommended
`superfast` | none | not recommended
`veryfast` | `--veryfast` | trades quality for speed
`faster` | `--faster` | trades quality for speed
`fast` | `--fast` | trades quality for speed
`medium` | none | default
`slow` | `--slow` | trades speed for compression
`slower` | `--slower` | trades speed for compression
`veryslow` | `--veryslow` | trades speed for compression
`placebo` | none | not recommended

Prior to version 4.0 of `transcode-video.sh`, `fast` was the default preset. Now `medium` is the default, just like x264 and HandBrake. This means transcoding is slower. However, you can easily return to the old level of performance with:

    transcode-video.sh --fast "/path/to/Movie.mkv"

Presets faster than `medium` trade quality for more speed. While this quality loss may still be acceptable with `fast`, it becomes more noticeable as preset speed increases at the default target video bitrates.

Quality loss from using faster presets may manifest itself as blockiness, [color banding](https://en.wikipedia.org/wiki/Colour_banding), or loss of detail. But these problems can be mitigated by raising the target video bitrate with the `--big` or `--max` options:

    transcode-video.sh --big --veryfast "/path/to/Movie.mkv"

Avoid using `superfast` and `ultrafast` because they significantly lower quality and compression efficiency.

Presets slower than `medium` trade encoding speed for more compression efficiency. Usually, this means more compression as preset speed decreases. Your mileage may vary.

When the output video bitrate is not below or near the target using `medium`, applying a slower preset can significantly reduce that bitrate.

In some cases the `slow` preset can also improve quality, but the benefit compared to `medium` may not be perceptible for most input. Presets slower than `slow` may actually cause small artifacts for some input due to higher compression.

The `slower`, `veryslow` and `placebo` presets are modified in `transcode-video.sh` to maintain compatibility with devices from Apple and other manufacturers. When using these presets for output larger than `1280x720` pixels, the [H.264 level](https://en.wikipedia.org/wiki/H.264/MPEG-4_AVC#Levels) is constrained to `4.0`, usually limiting the number of [reference frames](https://en.wikipedia.org/wiki/Reference_frame_(video)).

Avoid using `placebo` because it's simply not worth the time and may not even produce smaller output than `veryslow`. There's a reason this particular preset doesn't follow the nomenclature.

To produce output even closer in configuration to what's available from the iTunes Store, you need to use at least the `slow` preset. And for a very few number of videos, you may need to use `slower` or `veryslow` to reach the same level of compression.

### Evaluating the quality of a transcoding

Most people watch television anywhere from a distance between 1.5 to 2.5 times the diagonal of their screen. With big-screen desktop computers and mobile devices, that viewing distance has shrunk to where it's essentially the same distance as the screen diagonal.

The goal of a smaller, more portable format means that a video transcoding will be, by necessity, a lower-bitrate copy. Which also means quality will be lost during the process of compression. The trick is to make that quality loss invisible so that the transcoded copy remains good enough to be mistaken for the original.

Here are some guidelines to consider when making that evaluation:

* View the transcoding at the same size and from the same distance as you would the original. Otherwise you're not making a fair comparison.
* Don't pause playback to compare the transcoding with the original on the same frame. The transcoding usually won't look as good because video is designed to be in motion and compression takes advantage of this to fool you.
* View with audio on. Not only do you need to evaluate audio quality, but without audio you're missing the immersive experience designed, once again, to fool you.
* When you do see or hear something that looks or sounds wrong, compare your observation against the original. Even Blu-ray Discs have flaws. These can be caused by bad encoding, bad mastering or just plain bad source material.

### Saving time and space by constraining your video and audio

About half of all high definition video on broadcast television is in 720p format. Most people who watch television don't have a surround sound system with which to listen to it.

If 720p video and stereo audio look and sound acceptable, you might want to consider these formats to save transcoding time and storage space. This is especially appropriate for mobile devices such as phones with their smaller screens and limited audio output.

Use the `--720p` option to constrain 1080p or Blu-ray Disc input within a `1280x720` pixel boundary:

    transcode-video.sh --720p "/path/to/Movie.mkv"

This doesn't affect video input that is already that size or smaller, such as DVDs.

Add the `--no-surround` option to disable multi-channel surround sound and limit output to, at most, two-channel stereo:

    transcode-video.sh --720p --no-surround "/path/to/Movie.mkv"

### Adding audio tracks

Many Blu-ray Discs and DVDs have additional audio tracks. Some of these tracks might be for other languages and some for commentaries.

To include audio track `3` when transcoding, use the `--add-audio` option:

    transcode-video.sh --add-audio 3 "/path/to/Movie.mkv"

To also include audio track `5` and name it "Director Commentary":

    transcode-video.sh --add-audio 3 --add-audio 5,"Director Commentary" "/path/to/Movie.mkv"

Starting with version 5.0 of `transcode-video.sh`, track names can include a comma (",").

By default, all added audio tracks are transcoded in AAC format. If the original audio track is multi-channel surround sound, use the `--allow-ac3` option to transcode in Dolby Digital AC–3 format:

    transcode-video.sh --allow-ac3 --add-audio 3 --add-audio 5,"Director Commentary" "/path/to/Movie.mkv"

The `--allow-ac3` option applies to all added audio tracks.

### Including DTS audio

The DTS audio format has both lossless and lossy variants, and is usually available on Blu-ray Discs. Use the `--allow-dts` option to include these tracks in their original format without transcoding:

    transcode-video.sh --allow-dts "/path/to/Movie.mkv"

The `--allow-dts` option applies to both the main audio track and all added audio tracks.

Keep in mind that lossless DTS-HD Master Audio tracks are encoded at bitrates often larger than the default target video bitrate. So including them is of dubious value if your goal with transcoding is compression.

Also, while `HandBrakeCLI` can include DTS audio tracks within the MP4 format, the output is not compatible with iTunes, Apple TV or many other devices.

### Batch control for `transcode-video.sh`

Although `transcode-video.sh` doesn't handle multiple inputs, it's easy to add this capability by creating a `batch.sh` script.

Such a script can simply be a list of commands:

    #!/bin/bash

    transcode-video.sh --crop 132:132:0:0 "/path/to/Movie.mkv"
    transcode-video.sh --crop "/path/to/Another Movie.mkv"
    transcode-video.sh --crop 0:0:240:240 "/path/to/Yet Another Movie.mkv"

But a better solution is to write the script once and supply the list of movies and their crop values separately:

    #!/bin/bash

    readonly work="$(cd "$(dirname "$0")" && pwd)"
    readonly queue="$work/queue.txt"
    readonly crops="$work/crops"

    input="$(sed -n 1p "$queue")"

    while [ "$input" ]; do
        title_name="$(basename "$input" | sed 's/\.[^.]*$//')"
        crop_file="$crops/${title_name}.txt"

        if [ -f "$crop_file" ]; then
            crop_option="--crop $(cat "$crop_file")"
        else
            crop_option=''
        fi

        sed -i '' 1d "$queue" || exit 1

        transcode-video.sh $crop_option "$input"

        input="$(sed -n 1p "$queue")"
    done

This requires a `work` directory on disk with three items, one of which is a directory itself:

    batch.sh
    crops/
        Movie.txt
        Yet Another Movie.txt
    queue.txt

The contents of `crops/Movie.txt` is simply the crop value for `/path/to/Movie.mkv`:

    132:132:0:0

And the contents of `queue.txt` is just the list of movies, full paths without quotes, delimited by carriage returns:

    /path/to/Movie.mkv
    /path/to/Another Movie.mkv
    /path/to/Yet Another Movie.mkv

Notice that there's no crop file for `/path/to/Another Movie.mkv`. This is because it doesn't require cropping.

For other options that won't change from input to input, e.g. `--mkv`, simply augment the line in the script calling `transcode-video.sh`:

        transcode-video.sh --mkv $crop_option "$input"

The transcoding process is started by executing the script:

    ./batch.sh

The path is first deleted from the `queue.txt` file and then passed as an argument to the `transcode-video.sh` script. To pause after `transcode-video.sh` returns, simply insert a blank line at the top of the `queue.txt` file.

## Feedback

The best way to send feedback is mentioning me, [@donmelton](https://twitter.com/donmelton), on Twitter. I always try to respond quickly but sometimes it may take as long as 24 hours.

## Acknowledgements

A big "thank you" to the developers of HandBrake and the other tools used by these scripts. So much wow.

Thanks to [Rene Ritchie](https://twitter.com/reneritchie) for letting me continue to babble on about transcoding in his podcasts.

Thanks to [Joyce Melton](https://twitter.com/erinhalfelven), my sister, for help editing this massive "README" document.

Many thanks to [Jordan Breeding](https://twitter.com/jorbsd) and numerous others online for their positive feedback, bug reports and useful suggestions.

## License

Video Transcoding Scripts is copyright [Don Melton](http://donmelton.com/) and available under a [MIT license](https://github.com/donmelton/video-transcoding-scripts/blob/master/LICENSE).
