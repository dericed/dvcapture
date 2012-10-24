#!/bin/bash

#declare the label of the identifier associated with the ingest and resulting package. Other labels are declared directly in the use of the ask and offerChoice functions below.
sourceidlabel="SourceID"

#container format to use (use avi,mkv, or mov)
container="mov"

#declare directory for packages of dv files to be written to during processing
CACHE_DIR=/home/archive-dv/Desktop/dvgrabs

#name of the log for dvgrab process data
DVLOG=dvgrab_capture.log

#name of the log for user process data

#enter technical defaults
CaptureDeviceSoftware="ffmpeg,dv_capture.sh version 0.2"
PlaybackDeviceManufacturer="Sony"
PlaybackDeviceModel="DSR-11"
PlaybackDeviceSerialNo="93313"
Interface="IEEE 1394"


OPLOG=ingest_operator.log

EXPECTED_NUM_ARGS=0

deps(){
        DEPENDENCIES="dvgrab dvanalyzer gnuplot ffmpeg md5deep"
 
        deps_ok=YES
        for dep in $DEPENDENCIES ; do
                if [ ! $(which $dep) ] ; then
                        echo -e "This script requires $dep to run but it is not installed"
                        echo -e "If you are running ubuntu or debian you might be able to install $dep with the following command"
                        echo -e "sudo apt-get install $dep"
                        deps_ok=NO
                fi
        done
        if [[ "$deps_ok" == "NO" ]]; then
                echo -e "Unmet dependencies   ^"
                echo -e "Aborting!"
                exit 1
        else
                return 0
        fi
}
ask(){
	# This function requires 3 arguments
	# 1) A prompt
	# 2) The label for the metadata value
    read -p "$1" response
    if [ -z "$response" ] ; then
    	ask "$1" "$2"
    else
    	echo "${2}: ${response}"
    fi
}
offerChoice(){
	# This function requires 3 arguments
	# 1) A prompt
	# 2) The label for the metadata value
	# 3) A vocabulary list
	PS3="$1"
	label="$2"
	eval set "$3"
	select option in "$@"
	do
		break
	done
	echo "${label}: ${option}"
}

if [ $# -ne $EXPECTED_NUM_ARGS ] ; then
   output_help
   exit 0
fi

deps

dvstatus=`dvcont status`
if [ "$?" = "1" ] ; then
	echo "The DV deck is not found. Make sure the FireWire is attached correctly and that the deck is on."
	exit 1
fi

# setting static process metadata
echo
echo "CaptureDeviceSoftware: $CaptureDeviceSoftware"
echo "PlaybackDeviceManufacturer: $PlaybackDeviceManufacturer"
echo "PlaybackDeviceModel: $PlaybackDeviceModel"
echo "PlaybackDeviceSerialNo: $PlaybackDeviceSerialNo"
echo "Interface: $Interface"
echo
answer=`offerChoice "Do these values match your setup: " "setupcorrect" "'Yes' 'No'"`
if [ "$answer" == "setupcorrect: No" ] ; then
    echo "Please edit these values in the header of $0 and rerun."
    exit
fi

tmplog=/tmp/dv_capture
touch "$tmplog"
echo "CaptureDeviceSoftware: $CaptureDeviceSoftware" > "$tmplog"
echo "PlaybackDeviceManufacturer: $PlaybackDeviceManufacturer" >> "$tmplog"
echo "PlaybackDeviceModel: $PlaybackDeviceModel" >> "$tmplog"
echo "PlaybackDeviceSerialNo: $PlaybackDeviceSerialNo" >> "$tmplog"
echo "Interface: $Interface" >> "$tmplog"

answer=`ask "Please enter the Operator name: " "Operator"`
echo "$answer" >> "$tmplog"
echo
answer=`ask "Please enter the Source ID: " "$sourceidlabel"`
echo "$answer" >> "$tmplog"
id=`echo $answer | cut -d = -f 2`
answer=`offerChoice "Please enter the tape format: " "SourceFormat" "'DVCam' 'miniDV' 'DVCPRO'"`
echo "$answer" >> "$tmplog"
echo
answer=`offerChoice "Please enter the tape cassette brand: " "CassetteBrand" "'Sony' 'Panasonic' 'JVC' 'Maxell' 'Fujifilm'"`
echo "$answer" >> "$tmplog"
echo
answer=`ask "Please enter the Cassette Product No. (example: DVM60, 124, 126L): " "CassetteProductNo"`
echo "$answer" >> "$tmplog"
echo
answer=`ask "Please enter the tape condition: " "CassetteCondition"`
echo "$answer" >> "$tmplog"
echo


dvstatus=`dvcont status`
while [ "$dvstatus" = "Loading Medium" ] ; do 
    echo -n "Insert cassette: # ${id}, hit [q] to quit, or any key to continue. "
    read insert_response
    if [ "$insert_response" = "q" ] ; then
    	exit 1
    else
    	dvstatus=`dvcont status`
    fi
done

answer=`offerChoice "How should the tape be prepared?: " "PrepareMethod" "'Full repack then start' 'Rewind then start' 'Start from current position'"`
echo "$answer" >> "$tmplog"
prepanswer=`echo "$answer" | cut -d = -f 2`
if [ "$prepanswer" = "Full repack then start" ] ; then
    dvcont stop
    echo "Fast Forwarding..."
    dvcont ff
    (stat=$(dvcont status); while [[ "$stat" != "Winding stopped" ]]; do sleep 2; stat=$(dvcont status); done)
    echo "Rewinding..."
    dvcont rewind
    (stat=$(dvcont status); while [[ "$stat" != "Winding stopped" ]]; do sleep 2; stat=$(dvcont status); done)

elif [ "$prepanswer" = "Rewind then start" ] ; then
    dvcont stop
    echo "Rewinding..."
    dvcont rewind
    (stat=$(dvcont status); while [[ "$stat" != "Winding stopped" ]]; do sleep 2; stat=$(dvcont status); done)
fi

packageid=`cat "$tmplog" | grep "$sourceidlabel" | cut -d '=' -f 2`
if [ -d "$CACHE_DIR/$packageid" ] ; then
   echo "The directory $CACHE_DIR/$packageid already exists. Please delete the directory and try again or do not ingest it again."
   exit
fi

startingtime=$(date +"%Y-%m-%dT%T%z")
echo "starting to set up ingest package for $packageid"
echo "If the video on the tape ends AND the timecode stops incrementing below, then please press STOP on the deck to end the capture."

#set up package
mkdir -p "$CACHE_DIR/$packageid" "$CACHE_DIR/$packageid/objects" "$CACHE_DIR/$packageid/logs" "$CACHE_DIR/$packageid/metadata/submissionDocumentation"
#checking dir existence
if [ ! -d "$CACHE_DIR/$packageid" ]; then	
   echo "ERROR:$CACHE_DIR/$packageid does not exist and could not be corrected."
   exit 1
fi
mv "$tmplog" "$CACHE_DIR/$packageid/metadata/submissionDocumentation/$OPLOG"
echo starting capturing tape...
dvgrab -f raw -showstatus -size 0 "$CACHE_DIR/$packageid/objects/${packageid}_.dv" 2>&1 | tee "$CACHE_DIR/$packageid/metadata/submissionDocumentation/${DVLOG}"
#trap '	
echo finished capturing tape...
dvcont rewind &
endingtime=$(date +"%Y-%m-%dT%T%z")
echo "startingtime=$startingtime" >> "$CACHE_DIR/$packageid/metadata/submissionDocumentation/$OPLOG"
echo "endingtime=$endingtime" >> "$CACHE_DIR/$packageid/metadata/submissionDocumentation/$OPLOG"
echo done with "$packageid".
scriptdir=`dirname "$0"`

package="$CACHE_DIR/$packageid"

# dvanalyzer analysis
file=`find "$package/objects" -maxdepth 1 -mindepth 1 -type f -name "*v" ! -name ".*"`
filename=`basename "$file"`
if [ -f "$file" ] ; then
	outputdir="$package/metadata/submissionDocumentation/${filename%.*}_analysis"
        if [ ! -d "$outputdir" ] ; then
	mkdir -p "$outputdir"
	# plot graph
	echo Analyzing DV stream...
	dvanalyzer </dev/null --XML "$file"  > "$outputdir/${filename%.*}_dvanalyzer.xml"
	xsltproc "$scriptdir/dvanalyzer.xsl" "$outputdir/${filename%.*}_dvanalyzer.xml" > "$outputdir/${filename%.*}_dvanalyzer_summary.txt"
	echo Plotting results...
	echo "set terminal svg size 1920, 1080
	set border 0
	set datafile separator ','
	set output '$outputdir/${filename%.*}_${count}_dvanalyzer.svg'
	set multiplot layout 4, 1 title 'DV Analyzer Graphs of $filename'
	set style fill solid border -1
	set xrange [ 0: ]
	set yrange [ 0:100 ]
	set grid y
	unset xtics
	set xdata time
	set timefmt '%S'
	set xtics format '%H:%M:%S'
	set xtics nomirror
	plot '$outputdir/${filename%.*}_dvanalyzer_summary.txt' u (\$1/29.97):(\$2) title 'Video Error Concealment (percentage)' lt 1 with impulses 
	plot '' u (\$1/30):(\$3) title 'Channel 1 Audio Error (percentage)' lt 2 with impulses
	plot '' u (\$1/30):(\$4) title 'Channel 2 Audio Error (percentage)' lt 3 with impulses 
	set yrange [ -100:100 ]
	plot '' u (\$1/30):(\$5) title 'Audio Error Head Difference' lt 4 with impulses" | gnuplot
	echo Done
	fi
else
	echo "ERROR - $name is not a file"
fi

# rewrap dv file to container
cd "$package/objects/"
for dvfile in *.dv ; do
    if [ -f "$dvfile" ] ; then
        ffmpeg -i "$dvfile" -map 0 -c copy "${dvfile%.*}.${container}"
        if [ "$?" = "0" ] ; then
            rm "$dvfile"
        fi
    fi
done

#md5deep on objects
md5deep -retl "$package/objects/" > "$package/metadata/checksum.txt"

#' 0
