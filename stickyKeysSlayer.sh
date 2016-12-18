#!/bin/bash
#
# stickyKeysSlayer.sh
# Copyright (c) 2016 Dennis Maldonado
# Copyright (c) 2016 Tim McGuffin
#
#
# Incorporating code from sticky_keys_hunter
# Copyright (c) 2015 Zach Grace
# Licensed GPL v3+
#
#						
# License: GPLv3
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
########################################################################### 
#
# Dependencies:
#	imagemagick
#	xdotool
#	parallel
#	bc
#       python-numpy
#       python-opencv
#
# All packages exist in the Kali repositories:
#	apt-get update
# 	apt-get -y install imagemagick xdotool parallel bc python-numpy python-opencv
#
# Description
#	Establishes a Remote Destop session (RDP) with the specified hosts and sends key presses
#	to launch the accessibility tools within the Windows Login screen. stickyKeysSlayer.sh 
#	will analyze the console and alert if a command prompt window opens up. Screenshots will be
#	put into a folder ('./rdp-screenshots' by default) and screenshots with a cmd.exe window 
#	are put in a subfolder ('./rdp-screenshots/discovered' by default).
#	stickyKeysSlayer.sh accepts a single host or a list of hosts, delimited by line and works
#	with multiple hosts in parallel.
#
#
########################################################################### 

# Default options if arguments not specified
PROCESSES=1
TIMEOUT=30
VERBOSE=0
SCREENSHOT_FOLDER="rdp-screenshots"
DISCOVERED_FOLDER="discovered"
BYPASSCNT=0

# Find out script's working directory
WORKDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# Check if script is a symlink
if [ -L "$0" ]; then
   WORKDIR="$(dirname "$(readlink -f "$0")")"
fi

TEMPLATEDIR="$WORKDIR/templates/"

# Timing settings. Not necessary to modify
TIMEOUT_STEP=1
BACKDOOR_WAIT_TIME=2

# Trap ctrl-c and call control_c()
trap control_c INT

function control_c {
	killall rdesktop
	echo "Interrupt detected. Killing all rdesktop processes"
	exit 0
}

function currentDateTime {
	echo -n $(date "+%Y-%m-%d %H:%M:%S")
}

function echoOutput {
	echo -e "$(currentDateTime) $CNT $HOST \e[34m[*]\e[0m $1"
}

function echoVerbose {
	if [ $VERBOSE -eq 1 ]; then
		echo -e "$(currentDateTime) $CNT $HOST \e[33m[v]\e[0m $1"
	fi
}

function echoError {
	echo -e "$(currentDateTime) $CNT $HOST \e[31m[!]\e[0m $1"
}

function echoSuccess {
	echo -e "$(currentDateTime) $CNT $HOST \e[32m[*]\e[0m $1"
}

function echoHelp {
	echo -e ""
    echo -e "Usage: $0 [-v] [-t timeout_in_seconds] [-s skip_num] [-j num_of_jobs] [-o output_folder] <Host/IP/filename>"
	echo -e ""
	echo -e "Establishes a Remote Destop session (RDP) with the specified hosts and sends key presses to launch the accessibility tools within the Windows Login screen. stickyKeysSlayer.sh will analyze the console and alert if a command prompt window opens up. Screenshots will be put into a folder ('./rdp-screenshots' by default) and screenshots with a cmd.exe window are put in a subfolder ('./rdp-screenshots/discovered' by default). stickyKeysSlayer.sh accepts a single host or a list of hosts, delimited by line and works with multiple hosts in parallel."
	echo -e ""
	echo -e "Mandatory arguements"
	echo -e "\tHost/IP/filename \t Single target (by hostname or IP address) or list of targets (file, one host/ip per line)"
	echo -e ""
	echo -e "Voluntary arguments"
	echo -e "\t-v \t Verbose. Provide more verbose messages. DEFAULT = disabled"
	echo -e "\t-t \t Timeout. Number of seconds to wait before killing the RDP session. DEFAULT = 30"
        echo -e "\t-j \t Jobs. Number of jobs to spawn. DEFAULT = 1"
	echo -e "\t-s \t Skip N hosts in provided file"
	echo -e "\t-o \t Output folder. Specify the folder to store the screenshots. If the folder does not exist, one will be created. DEFAULT = ./rdp-screenshots"
	echo -e "\t-h \t Help message. You are reading it"
	echo -e ""
	echo -e "Examples"
	echo -e "\tScan a single host"
	echo -e "\t\t$0 192.168.13.37"
	echo -e ""
	echo -e "\tUse verbose mode with 8 threads and a timeout of 10 on a lists of hosts in targetlist.txt"
	echo -e "\t\t$0 -v -j 8 -t 10 targetlist.txt"
	echo -e ""
	echo -e "Authors"
	echo -e "\tDennis Maldonado - @DennisMald"
	echo -e "\tTim McGuffin - @notmedic"
	echo -e "\tWith code from: Zach Grace - @ztgrace"
	echo -e ""
	echo -e "License"
	echo -e "\tLicensed GPL v3+"
	exit 1
}

# Check if rdesktop process is still alive, error out if not.
function isAlive {
    local pid=$1
    kill -0 $pid 2>/dev/null
    if [ $? -eq 1 ]; then
        echoError "Process Died. Failed to connect"
        exit 1
    fi
}

# Check if TIMEOUT time has been reached, error out if TIMEOUT is reached
function isTimedOut {
    local time=$1
    if [ $(echo "$time >= $TIMEOUT" | bc) -eq 1 ]; then
        echoError "Timed out"
		kill $pid
        exit 1
    fi
}

# Take screenshots of the rdesktop window for analysis and saving
function screenshot {
    local screenshot=$1
    local window=$2
	local screenshotTimer=0
	local importTimeout=$TIMEOUT
	echoVerbose "Saving screenshot for Window ID: $window"
	import -frame -window "$window" "$screenshot" &
	local importPid=$!
	while true; do
		sleep 0.1
		echoVerbose "Waiting for import process to finish up ($screenshotTimer seconds)"
		kill -0 $importPid 2> /dev/null
		if [ $? -ne 0 ]; then
			echoVerbose "Screenshot saved to $screenshot for Window ID: $window"
			break
		fi
		if [ $(echo "$screenshotTimer >= $importTimeout" | bc) -eq 1 ]; then
			echoVerbose "The 'import' process may be hanging... killing PID: $!"
			kill $importPid
			isAlive $pid
			echoError "Could not take screenshot for Window ID: $window. Stopping job."
			kill $pid
			exit 1
		fi
		screenshotTimer=$(echo "$screenshotTimer + 0.1" | bc)
	done
}

# Detect amount of black pixels from the screenshot
function testBlack {
	local IMAGE=$1
	local RETVAR=$2
	local BLACK=$(convert $IMAGE -format %c histogram:info:- | grep "\#000000 " | cut -d : -f 1 | tr -d ' ')
	if [ -z "$BLACK" ]
	then
		local BLACK=0
	fi
	eval $RETVAR="'$BLACK'"
}

function sendKeyStrokes {
	isAlive $pid
	local targetWindow=$2
	echoOutput "Attempting to trigger displayswitch.exe backdoor"
	xdotool key --window "$targetWindow" super+p
	echoOutput "Attempting to trigger utilman.exe backdoor"
	xdotool key --window "$targetWindow" super+u
	echoOutput "Attempting to trigger sethc.exe backdoor"
	# 6 shift presses fixed some timing issues
	xdotool key --window "$targetWindow" shift shift shift shift shift shift
	#echoOutput "Attempting to trigger magnifier.exe backdoor"
	#xdotool key --window $targetWindow super+equal
	#xdotool key --window $targetWindow super+minus
	#echoOutput "Attempting to trigger narrator.exe backdoor"
	#xdotool key --window $targetWindow super+Return
}

function makeFolder {
	if [ ! -d "$1" ]; then
		echoVerbose "Folder does not exist. Creating $1 folder"
		mkdir "$1"
	fi
}

# Analyze Remote Desktop via pattern matching, find unusual behaviour.
# Patterns and Templates can be modified in /patterns/ and /templates/ directories
function analyzeDesktop {
        echoOutput "Attempting to identify OS Version and unusual behaviour"
        # Call for external script that will identify OS with .png files in /patterns/ directory
        WINVER=$("$WORKDIR/detect-windows.py" "$afterScreenshot")
        if [[ ! "$WINVER" == "other" ]]; then
                echoOutput "OS Detected: $(echo $WINVER | cut -d' ' -f1,2|tr '_' ' ')"
                for i in $(ls $TEMPLATEDIR/*.png | grep -i $WINVER); do

                         TEMPLATENAME=$(basename $i | cut -d'_' -f1,2 | sed 's/_/-/g' )
                         a=$(compare -metric RMSE $i $2 /dev/null 2>&1 | cut -d' ' -f1|cut -d'.' -f1)
                         if [[ ! $a -gt 18000 ]]; then 
                                  echoVerbose "Screenshot matched 'regular' pattern"
                                  makeFolder "$SCREENSHOT_FOLDER/not-interesting"
                                  mv "$afterScreenshot" "$SCREENSHOT_FOLDER"/not-interesting/"$WINVER".$HOST.png
                                  echoVerbose "Screenshot saved to $SCREENSHOT_FOLDER/not-interesting/$WINVER"."$HOST.png"
                                  REGULAR=true
                                  break
                         fi
                done        
                if [ ! "$REGULAR" = true ]; then
                         echoVerbose 'Screenshot should be reviewed manually or template missing'
                fi
        fi

}


function scanHost {
	# Launch rdesktop in the background
	echoOutput "Initiating rdesktop connection"
	# -x m  >> modem connection behaviour
	# -z    >> enable rdp compression
	# -a 16 >> 16 bit color depth (faster)
	# -n "" >> pass empty hostname
	# -T    >> set title
	rdesktop -x m -z -n "" -T "rdesktop - $HOST" -u "" -a 16 $HOST 2>/dev/null & 
	pid=$!

	# Get the rdesktop Window ID by it's Window Title
	WindowID=""
	timer=0
	echoVerbose "Searching for Window Title: 'rdesktop - $HOST'"
	while true; do
		isAlive $pid
		isTimedOut $timer
		WindowID=$(xdotool search --name "^rdesktop - $HOST$" 2> /dev/null)
		if [ $? = 0 ]; then
			WindowID=$(echo "$WindowID" | head -n 1)
			echoVerbose "Found Window Title: 'rdesktop - $HOST', Window ID: $WindowID"
			break
		fi
		sleep $TIMEOUT_STEP
		echoVerbose "Can not find Window Title: 'rdesktop - $HOST', Trying again ($timer seconds)"
		timer=$(echo "$timer + $TIMEOUT_STEP" | bc)
	done

	# Focus to the RDP window by it's Window ID
	echoVerbose "Setting window focus to Window ID: $WindowID"
	timer=0
	while true; do
		isAlive $pid
		isTimedOut $timer
		xdotool windowfocus "$WindowID" 2> /dev/null
		if [ $? = 0 ]; then
			echoVerbose "Focused on Window ID: $WindowID"
			break
		fi
		sleep $TIMEOUT_STEP
		echoVerbose "Unable to focus to Window ID: $WindowID. Trying again ($timer seconds)"
		timer=$(echo "$timer + $TIMEOUT_STEP" | bc)
	done

	# If the screen is all black delay for $TIMEOUT_STEP seconds all the way until $TIMEOUT seconds is reached
	timer=0
	while true; do
		isAlive $pid
		isTimedOut $timer
                # Screenshot the window and if the only one color is returned (black), give it chance to finish loading
		screenshot "$temp" "$WindowID"
		testBlack "$temp" consoleLoadedCheck
		echoVerbose "[DEBUG] ConsoleLoadedCheck = $consoleLoadedCheck"
		# Maximum loaded console was found at 413000 threshold. When fully black ~ 500000
		if [ $consoleLoadedCheck -lt 415000 ]; then
			echoOutput "Console Loaded"
			# Sleep a few seconds to allow the console to fully load
			sleep 3.0
			testBlack "$temp" pretestblack
			echoVerbose "[DEBUG]  $temp - PretestBlack = $pretestblack!!!"
	#		cp -v $temp /tmp/lol/
			break
		fi

		echoVerbose "Waiting on desktop to load. Waited for $timer seconds"
		sleep $TIMEOUT_STEP
		timer=$(echo "$timer + $TIMEOUT_STEP" | bc)
	done

	# Clean up temporary screenshots
	rm "$temp"

	sendKeyStrokes $pid $WindowID

	# Seems to be a delay if cmd.exe is set as the debugger this probably needs some tweaking
	echoVerbose "Waiting $BACKDOOR_WAIT_TIME seconds for the backdoors to trigger"
	sleep $BACKDOOR_WAIT_TIME

	makeFolder "$SCREENSHOT_FOLDER"
				
	# Take screenshot of final result and calcuculate black pixels
	afterScreenshot="$SCREENSHOT_FOLDER/$HOST.png"
	screenshot "$afterScreenshot" "$WindowID"
	testBlack "$afterScreenshot" posttestblack
	echoVerbose "[DEBUG] PostTestBlack = $posttestblack!!!"
	blackdifference=$(echo $posttestblack - $pretestblack | bc)
	echoVerbose "[DEBUG] Difference = $blackdifference!!!"

	# Detect if a cmd.exe console is loaded by the black pixels
	if [ "$blackdifference" -gt "40000" -a "$blackdifference" -lt "480000" ]; then
		echoSuccess "Screenshot may show a command prompt!"
		makeFolder "$SCREENSHOT_FOLDER/$DISCOVERED_FOLDER"
		mv $afterScreenshot "$SCREENSHOT_FOLDER/$DISCOVERED_FOLDER/"
		echoOutput "Moved screenshot to $SCREENSHOT_FOLDER/$DISCOVERED_FOLDER/"
	else
                echoOutput "Screenshot does not appear to show a command prompt."
		# Analyze desktop via pattern matching (0.7 seconds latency on Intel i5)
		analyzeDesktop
	fi

	# Close the rdesktop window after everything has finished
	kill $pid
}

export DISPLAY=:0
OPTIND=1
while getopts ":vj:t:o:hs:" opt; do
	case $opt in
		v)
			echoVerbose "Verbose mode activated"
			VERBOSE=1
			;;
		j)
			if [ $OPTARG -eq $OPTARG 2> /dev/null ]; then
				#echoVerbose "Spawning $OPTARG processess"
				PROCESSES=$OPTARG
			else
				echoError "Invalid value for processes. Must be an integer value"
				echoHelp
			fi
			;;
		t)
			if [ $OPTARG -eq $OPTARG 2> /dev/null ]; then
				#echoVerbose "Timeout set to $OPTARG seconds"
				TIMEOUT=$OPTARG
			else
				echoError "Invalid value for timeout. Must be an integer value (seconds)"
				echoHelp
			fi
			;;
		o)
			# Create the folder for screenshots if necessary
			SCREENSHOT_FOLDER=$OPTARG
			if [ ! -d "$SCREENSHOT_FOLDER" ]; then
				echoVerbose "Folder does not exist. Creating $SCREENSHOT_FOLDER folder"
				mkdir "$SCREENSHOT_FOLDER"
			fi
			;;
		h)
			echoHelp
			;;
		s)
			# Bypass X hosts in provided file.
			if [ $OPTARG -eq $OPTARG 2> /dev/null ]; then
				BYPASSCNT=$OPTARG
				echo "$BYPASSCNT" > /tmp/cntbypass
			fi
			;;
		:)
			echoError "Missing argument"
			echoHelp
			;;
		\?)
			echoError "Invalid Option $OPTARG"
			echoHelp
			;;
	esac
done

HOST=${@:$OPTIND:1}

temp="/tmp/$HOST.png"

if [ -z $1 ]; then
	echoError "Not enough arguments"
	echoHelp
fi

if [ -z "$HOST" ]; then
	echoError "No HOST specified"
	echoHelp
fi

# Check if this script was called from within parallel
if [[ $(ps -o args= $PPID) == *"parallel"*"$0"* ]]; then
        # Restore bypass number for processes executed by parallel
	BYPASSCNT=`cat /tmp/cntbypass`
	# Restore filename for processes executed by parallel
	CNT=`awk "/$HOST/{ print NR; exit }" $(cat /tmp/file_input)`
	if [[ $CNT -gt $BYPASSCNT ]]; then
		scanHost
	fi
	exit 0
fi

# Run with parallel if file is specified instead of host
if [ -f "$HOST" ]; then
        # Store filename for processes executed by parallel
	echo "$HOST" > /tmp/file_input
        # Store bypass number for processes executed by parallel
	echo 0 > /tmp/cntbypass
	echoOutput "Supplied host is a file, parallelizing across $PROCESSES processes"
	parallel -P $PROCESSES $0 ${@:1:$#-1} < $HOST
	exit 0

# If host is specified, run normally
else
	scanHost
	exit 0
fi

shift $(($OPTIND -1))


