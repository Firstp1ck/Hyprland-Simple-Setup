#!/usr/bin/env bash
#
# A TUI to play music.
#
# I wrote this to act as a way to announce my 2024 album Nightfall but got
# incredibly lazy and didn't finish it until a year later :p.
#
# This program was modeled after some GUI programs I have worked on in the past.
# The way it works is that 2 tasks are spawned as background tasks (1
# indefinitely, 1 as needed) and the main thread waits for events from those 2
# background tasks.
#
#                          Main Program
#                        /              \
#                       /                \
#                      /                  \
#         Read Keyboard Events          Play a Single Song
#
# The main program puts itself into an infinite loop where it waits for events
# from both child tasks.  It does this by using a named piped (via `mkfifo`)
# that is created by this script in a temp dir on the filesystem.
#
# The pipe is opened for both reading and writing before any tasks are spawned
# so everything will have access to it.  This allows the "Read Keyboard Events"
# task to block indefinitely until data is read from stdin (the keyboard) and
# also the "Play a Single Song" task to send up information about the underlying
# `ffplay` command, like it's PID when it starts, and its exit code when it
# finishes.
#
# The main process is the only thing that will ever touch the UI - the 2
# background tasks will simply transmit data back up to the main process and the
# main process will handle any and all logic to play music, change the UI, etc.
#
# This program allows the user to pick any song they'd like to play and it'll
# start playing it immediately (killing the previous `ffplay` instance if there
# is one).  If the song finishes the next song will be played automatically
# until the last song of the album is played and finishes.
#
# Author: Dave Eddy <dave@daveeddy.com>
# Date: May 13, 2024
# License: MIT

TAGLINE='Nightfall (2024) by Dave Eddy'
WEBSITE='https://nightfall.ysap.sh'
BASE_URL='https://music.daveeddy.com/static/music/Nightfall - 2024/mp3'
TRACKS=(
	'01 Before the Night'
	'02 Snowfall Serenade'
	'03 Tears Unspoken'
	'04 Colors'
	'05 Gone'
	'06 Safe House'
	'07 B♭ Song (2024 Version)'
	'08 Drifted Away'
	'09 Piano Improvisation'
	'10 Reverie Amidst Ruins'
	'11 Echoes of Solace'
	'12 Song for an Empty World'
	'13 The Final Storm'
)
IFS= read -d '' -r ALBUM_ART <<"EOF"

 ,ggg, ,ggggggg,
dP""Y8,8P"""""Y8b                    ,dPYb,      I8   ,dPYb,             ,dPYb, ,dPYb,
Yb, `8dP'     `88                    IP'`Yb      I8   IP'`Yb             IP'`Yb IP'`Yb
 `"  88'       88   gg               I8  8I   88888888I8  8I             I8  8I I8  8I
     88        88   ""               I8  8'      I8   I8  8'             I8  8' I8  8'
     88        88   gg     ,gggg,gg  I8 dPgg,    I8   I8 dP    ,gggg,gg  I8 dP  I8 dP
     88        88   88    dP"  "Y8I  I8dP" "8I   I8   I8dP    dP"  "Y8I  I8dP   I8dP
     88        88   88   i8'    ,8I  I8P    I8  ,I8,  I8P    i8'    ,8I  I8P    I8P
     88        Y8,_,88,_,d8,   ,d8I ,d8     I8,,d88b,,d8b,_ ,d8,   ,d8b,,d8b,_ ,d8b,_
     88        `Y88P""Y8P"Y8888P"88888P     `Y88P""Y8PI8"888P"Y8888P"`Y88P'"Y888P'"Y88
                               ,d8I'                  I8 `8,
                             ,dP'8I                   I8  `8,
                            ,8"  8I                   I8   8I
                            I8   8I                   I8   8I
                            `8, ,8I                   I8, ,8'
                             `Y8P"                     "Y8P'
EOF

# Requirements
MIN_COLUMNS=110
MIN_LINES=49

# Global state
BG_JOB=
NOW_PLAYING=
PIPE=
SELECTED=0

CONTROL_PIPE="/tmp/nightfall_control"
mkfifo "$CONTROL_PIPE" 2>/dev/null

# print and error and die
fatal() {
	tput setaf 1
	echo "[error]" "$@" >&2
	tput sgr0
	exit 1
}

# called when the process exits
# shellcheck disable=SC2317
cleanup() {
	# reset the terminal
	tput cnorm
	tput rmcup
	stty echo 2>/dev/null

	# stop any song and remove the pipe
	stop
	if [[ -n $PIPE ]]; then
		echo "removing pipe: $PIPE"
		rm -f "$PIPE"
	fi

	# remove the control pipe
    rm -f "$CONTROL_PIPE"

	# call to action lol
	echo
	echo 'View the source code or download the album'
	tput setaf 207
	echo "=> $WEBSITE"
	echo

	# look for any stray ffplay processes just to be nice
	tput setaf 1
	local output
	output=$(pgrep ffplay)
	if [[ -n $output ]]; then
		echo '!!! warning: stray ffplay processes possibly found !!!'
		echo 'IF YOU ARE STILL HEARING MUSIC try running the following'
		echo 'and killing any pids found'
		echo
		echo '$ pgrep ffplay'
		echo
	fi

	tput sgr0
}

# draw a box around the outside of the terminal
draw-box() {
	local offset=$1

	# full line
	local line=''
	for ((i = 0; i < COLUMNS - (offset * 2 * 2); i++)); do
		line+=' '
	done

	# draw top line
	tput cup "$offset" "$((offset * 2))"
	echo -n "$line"

	# draw bottom line
	tput cup "$((LINES - offset - 1))" "$((offset * 2))"
	echo -n "$line"

	# draw left side line
	local x=$((offset * 2))
	for ((i = offset; i < LINES - offset - 1; i++)); do
		tput cup "$i" "$x"
		echo -n '  '
	done

	# draw right side line
	local x=$((COLUMNS - (offset * 2) - 2))
	for ((i = offset; i < LINES - offset - 1; i++)); do
		tput cup "$i" "$x"
		echo -n '  '
	done
}

# draw the UI (album art, track list, now playing, etc.)
draw-ui() {
	local track i

	local x=$((COLUMNS / 2))
	local y=$((LINES / 2 - 17))

	tput setaf 197

	# draw album art
	((x -= 43))
	while IFS= read -r line; do
		tput cup "$y" "$x"
		echo -n "$line"
		((y++))
	done <<< "$ALBUM_ART"

	x=$((COLUMNS / 2 - 15))

	# draw album info
	((y++))
	tput cup "$y" "$x"
	tput setaf 207
	echo -n "$TAGLINE"

	# draw tracklist
	tput setaf 183
	((y += 2))
	i=1
	local max=0
	for track in "${TRACKS[@]}"; do
		if ((${#track} > max)); then
			max=${#track}
		fi

		local arrow='   '
		if ((SELECTED + 1 == i)); then
			arrow=' ->'
		fi

		tput cup "$y" "$x"
		echo -n "$arrow $track"

		((y++))
		((i++))
	done

	# draw now playing
	((y++))
	tput cup "$y" "$x"
	tput setaf 207
	if [[ -n $NOW_PLAYING ]]; then
		printf 'Now Playing: %-*s' "$max" "${TRACKS[NOW_PLAYING]}"
	else
		# clear the now playing
		printf '             %-*s' "$max" ' '
	fi

	tput sgr0
}

# given a track name return a link to the mp3
make-url() {
	local name=$1
	echo "$BASE_URL/$name.mp3"
}

# stop any song currently playing
stop() {
	if [[ -n $BG_JOB ]]; then
		kill "$BG_JOB" 2>/dev/null
		BG_JOB=
	fi
	NOW_PLAYING=
}

# try to play a song given by its index
play() {
	local i=$1

	# stop any existing song
	stop

	# stop here if we are out of bounds
	if ((i >= ${#TRACKS[@]})); then
		return
	fi

	NOW_PLAYING=$i

	# figure out the track name and URL
	local track=${TRACKS[NOW_PLAYING]}
	[[ -n $track ]] || fatal "invalid track index: $SELECTED"

	# play the song by URL
	local url
	url=$(make-url "$track")
	play-song-task "$url" <&- &
}

# background task to play a song and transmit up its data
play-song-task() {
	local url=$1

	ffplay -hide_banner -loglevel panic -autoexit -nodisp "$url" &

	local pid=$!
	echo 'song-play' "$pid" >&3

	wait "$pid"
	local code=$?
	echo 'song-stop' "$pid" "$code" >&3
}

# background task to read keyboard events
read-keyboard-events-task() {
	# read user input - handle arrow keys and letters
	local escape_char=$'\u1b'
	while true; do
		local data=
		read -rsn1 data 2>/dev/null || return
		if [[ $data == "$escape_char" ]]; then
			read -rsn2 data 2>/dev/null || return
		fi

		local output=
		case "$data" in
			'[A' | k) output='key-up';;
			'[B' | j) output='key-down';;
			''      ) output='key-enter';;
		esac

		if [[ -n $output ]]; then
			echo "$output" >&3
		fi
	done
}

main() {
	if ! command -v ffplay &>/dev/null; then
		echo 'ffplay (by ffmpeg) required for playback'
		echo 'instal "ffmpeg" with your package manager and try again'
		fatal 'ffplay not found'
	fi

	# figure out window size
	shopt -s checkwinsize

	# in order to init the variables we need to fork (and exit) a program or
	# a subshell - this is what this line does
	(:)

	local cols=$COLUMNS
	local lines=$LINES

	# this can fail if bash < 4, so let's manually retrieve the data with
	# external tools
	if [[ -z $cols || -z $lines ]]; then
		cols=$(tput cols)
		lines=$(tput lines)
	fi

	# ensure terminal size is correct
	if [[ -z $cols || -z $lines ]]; then
		fatal 'cannot determine terminal size'
	fi

	echo "terminal size: ${cols}x$lines"
	if ((cols < MIN_COLUMNS || lines < MIN_LINES)); then
		fatal 'terminal is too small to display player:' \
		   "must be >= ${MIN_COLUMNS}x${MIN_LINES}"
	fi

	# ensure these are at least initialized
	COLUMNS=$cols
	LINES=$lines

	# create the FIFO used for communication between tasks
	PIPE=/tmp/nightfall.$$
	mkfifo "$PIPE" || fatal "failed to create pipe $PIPE"
	exec 3<>"$PIPE" || fatal "failed to open pipe $PIPE"
	echo "created FIFO pipe: $PIPE"

	echo 'use j/k or your arrow keys to move up and down'

	# cleanup when program exits
	trap cleanup exit

	# get the window ready for drawing
	tput smcup
	tput civis
	stty -echo

	# draw static UI
	tput clear
	tput setab 57; draw-box 0
	tput setab 56; draw-box 1
	tput setab 55; draw-box 2
	tput setab 54; draw-box 3
	tput setab 53; draw-box 4
	tput setab 52; draw-box 5

	tput sgr0
	tput cup 10 20
	tput sc

	local num_tracks=${#TRACKS[@]}

	# draw the UI initially
	draw-ui

    # Start playing the first song automatically
    play 0

	# start reading keyboard events in the background
	read-keyboard-events-task <&0 &

	# Open the control pipe for both reading and writing to prevent EOF
	exec 4<> "$CONTROL_PIPE"
	while read -r cmd <&4; do
		case "$cmd" in
			toggle)
				if [[ -n $BG_JOB ]]; then
					stop
				else
					play "$SELECTED"
				fi
				;;
			stop)
				stop
				;;
		esac
	done &

	# wait for events (from the keyboard or the player)
	local data
	while read -ra data; do
		# we have read an event!
		local event=${data[0]}
		local args=("${data[@]:1}")

		#echo "read event: $event (${args[*]})"

		case "$event" in
			key-up) ((SELECTED--));;
			key-down) ((SELECTED++));;
			key-enter) play "$SELECTED";;
			song-play)
				# song started playing - record the PID
				local pid=${args[0]}

				# kill any existing song (this shouldn't
				# happen... but just in case because of bugs and
				# the async nature of signals)
				if [[ -n $BG_JOB ]]; then
					kill "$BG_JOB" 2>/dev/null
				fi

				BG_JOB=$pid
				;;
			song-stop)
				local pid=${args[0]}
				local code=${args[1]}

				# some other pid may have taken over this spot -
				# don't overwrite it
				if [[ $BG_JOB == "$pid" ]]; then
					BG_JOB=
				fi

				# check if the song exited cleanly (song finished)
				if ((code == 0)); then
					# play next track
					play "$((NOW_PLAYING + 1))"
				fi
				;;
		esac

		# bounds check index
		if ((SELECTED < 0)); then
			((SELECTED = 0))
		elif ((SELECTED >= num_tracks)); then
			((SELECTED = num_tracks - 1))
		fi

		# draw the UI
		draw-ui
	done <&3

	fatal 'not reached'
}

main "$@"