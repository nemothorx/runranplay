#!/bin/bash

# RUN RANdom PLAYlist
# ie, play random songs. simply. 

# version log
# 20030930 - 1.0 release
# 20040505 - 1.1
#	* use /tmp/.playlist if $PWD/.playlist is unwritable	
#	* ensure `find` only finds regular files 
# 20050222 - 1.2
#	* $SCANRATE added
# 20060804 - 1.3
#	* m4a support added
# 20080121 - 1.4beta
#	* video support added (mpeg/mov/avi/etc)
#	* player now uses `mplayer` for ALL formats for simplicity
#	* video will fail and move in if $DISPLAY fails...
#	* note that this now enables forward/rewind within a track
# 20080406 - 1.5
#	* the HISTORYSIZE is now dynamic is SONGCOUNT less than 50
#	* HISTORY array is now correctly re-populated as songs played
#	  (previously was only populating for 'historysize' times
#	  after each scan refresh. If scanrate was larger than size,
#	  then history was no longer being updated)
# 20110815 - 1.6
#	* aif support added (ie, I found I had aif files,
#	  and that mplayer supported them :)
#	* fixed issue with SONGCOUNT=51 -> HISTORYSIZE=50
#	    ...it's now dynamic up till SONGCOUNT=100
# 20120415 - 1.7
#	* flac, wma, m4a support added (yeah, m4a fell out somewhere since 1.3)
#	* random album support added (-album)
#	* SONGCOUNT is now ITEMCOUNT
# 20120513 - 1.8
#	* improved -album handling to detect the songtype
#	   ...before: mplayer $ALBUM/*
#	   ...now: mplayer $ALBUM/*.$SONGTYPE
# 20120724 - 1.9
#	* handle #comments in .m3u files
# 20200613 - 1.10
#       * use mpv instead of mplayer
#       * slight tweak of output
# 20210909 - 1.11
#       * `find` now ignores /all/ paths. for 4zzz archive suiting
# 20220612 - 1.12
#       * now supporting opus

# Created by Nemo <runranplay@nemo.house.cx> for himself. 
# Let's say it's licensed under the GPL. That's simple eh? :)

SCANRATE=20	# rescan every how many songs?
COUNT=0		# how many songs have we played?
HISTORYSIZE=50	# how much collision history to keep?
HISTORYMADE=0	# simple flag to say we haven't made history yet
declare -a HISTORY

function do_mkhistory {
    if [ $ITEMCOUNT -lt 100 ] ; then
	HISTORYSIZE=$(($ITEMCOUNT/2))
	echo -n  " ...adjusting historysize" 
    fi
    for i in $(seq 1 $HISTORYSIZE) ; do
      HISTORY[$i]=0
    done
    HISTORYMADE=1
}

function do_findpldir {
  if [ -w "$PWD" ] ; then
  # TODO: it needs to check the .playlist.m3x and playlist.m3x writability too,
  # since $PWD writability is pointless if .playlist.m3x exists already and
  # *isn't*, then that sucks!
    PLAYLISTAT="."
    PLAYLISTTYPE=local
  else
    PLAYLISTAT="/tmp"
    PLAYLISTTYPE=shared
  fi
}

function do_findsongs {
    # first up, let's find all the songs we want

    echo -n " * Finding songs in $PWD"
    #find "." -type f \( -iname \*ogg -o -iname \*wav -o -iname \*mp3 \) -follow -printf '%p\n' > $PLAYLISTAT/.playlist.m3u
    find "." -not -wholename \*/all/\* -type f \( -iname \*flac -o -iname \*ogg -o -iname \*wav -o -iname \*mp3 -o -iname \*mpg -o -iname \*avi -o -iname \*mpeg -o -iname \*flv -o -iname \*mov -o -iname \*m2v -o -iname \*mp4 -o -iname \*m4a -o -iname \*aif -o -iname \*aiff -o -iname \*wma -o -iname \*opus \) -follow -printf '%p\n' > $PLAYLISTAT/.playlist.m3x
    sort $PLAYLISTAT/.playlist.m3x > $PLAYLISTAT/playlist.m3x
    echo " ... saved to $PLAYLISTAT/playlist.m3x"
}

function do_findalbums {
    cat $SONGLISTFILE | egrep -o ".*/" | uniq > $PLAYLISTAT/.albumlist
}

function do_getrandom {
    # this functions finds us a random number, one that hasn't been used recently

    # force the looping :)
    UNIQUE=no

    echo -n "[ "
    while [ "$UNIQUE" == "no" ] ; do 

	#  PLAYNUMBER=$(echo "($RANDOM*$ITEMCOUNT)/32767+1" | bc)  # should be an integer number?
#	PLAYNUMBER=`expr \( $RANDOM % $ITEMCOUNT \) + 1`
        PLAYNUMBER=$(shuf -i 1-$ITEMCOUNT -n 1) # let's not limit our playlist to the max of $RANDOM

	# now assume our chosen number IS unique...
	UNIQUE=yes

	# loop through the history checking for repeats
	for i in $(seq 1 $HISTORYSIZE) ; do
	    if [ ${HISTORY[$i]} -eq $PLAYNUMBER ] ; then
		    # found a repeat, unique=no
		    UNIQUE=no
		    echo -n "."
	    fi
	done

    #  echo "" # debug
    # at this point, either unique=no and we loop back and choose a new PLAYNUMBER
    # or unique=yes and we leave the loop

    done
    # finally, store our selected number in the array for future history
    HISTORYNUM=$((COUNT%HISTORYSIZE+1))
    # HISTORYNUM cycles through the HISTORYSIZE to ensure history is correctly
    # populated
    HISTORY[$HISTORYNUM]=$PLAYNUMBER
    printf "%8s" "$PLAYNUMBER ]"
}


function do_playrandom {

    # first, find a random song from that list
    do_getrandom

    # is there a better way to extract a specific line from a file?
    TARGET=$(grep -v "^#" $PLAYLISTFILE | head -n $PLAYNUMBER  | tail -1)
#    echo "$TARGET" > /tmp/.currentsong

    if [ "$ALBUM" == "true" ] ; then
#	echo ">>>$TARGET<<<"
	SONGONE=$(grep "$TARGET" $SONGLISTFILE | head -1)
	SONGTYPE=${SONGONE##*.}
	SONGNAME=${SONGONE%.*}
        # PLAYTHIS=$(ls -1 $TARGET*$SONGTYPE)
    else
#        echo ">>$TARGET<<"
	SONG=$TARGET
	SONGNAME=${SONG%.*}
        SONGTYPE=${SONG##*.}
	PLAYTHIS=$TARGET
    fi
    # So mplayer should work on all songs AND vid... ;)
    # TODO: detect $DISPLAY to handle this better :)
    echo -n " $TARGET"
    grep "$TARGET" $SONGLISTFILE | tr "\n" "\0" | xargs -0 mpv --really-quiet --vid=no
    echo 
}



function do_showtime {
        TIME=$1;
        OUT=""
	
	#echo "original: $TIME"
        
	SECS=$(($TIME%60));		# any leftover seconds from a minute
        TIME=$(($TIME - $SECS));	# then remove those...
        
	# TIME should now be an exact num minutes
	#echo "less $SECS seconds: $TIME"
				
	MINS=$((($TIME%3600)/60));	# any leftover minutes from an hour
        TIME=$(($TIME - ($MINS*60)));	# then remove those...
        
	# TIME should now be an exact num hours
	#echo "less $MINS minutes: $TIME"
				
	HRS=$((($TIME%86400)/3600));	# any leftover hours in a day
        TIME=$(($TIME - ($HRS*3600)));		# then remove those...
	
	# TIME should now be an exact num days 
	#echo "less $HRS hours: $TIME"
	
	DAYS=$(($TIME/86400));
	
	if [[ $DAYS -ne 0 ]]; then
                OUT="${DAYS} days"
        fi
	if [[ $HRS -ne 0 ]]; then
                OUT="${OUT} ${HRS}h "
        fi
        if [[ $MINS -ne 0 ]]; then
                OUT="${OUT} ${MINS}m "
        fi
        if [[ $SECS -ne 0 ]]; then
                OUT="${OUT} ${SECS}s "
        fi

	echo $OUT
}


# all functions now defined, let's get down to business. 
# main() if you like that kind of thing. 

STARTTIME=$(date +%s)

while true ; do
  COUNTCHK=$((COUNT%$SCANRATE))
  if [ "$COUNTCHK" -eq "0" ] ; then
    NOWTIME=$(date +%s)
    TOTALTIME=$(($NOWTIME - $STARTTIME))
    if [ "$COUNT" -gt "0" ] ; then 
      AVERAGETIME=$(($TOTALTIME / $COUNT))
      SHOW_TOTALTIME=$(do_showtime $TOTALTIME)
      SHOW_AVERAGETIME=$(do_showtime $AVERAGETIME)
      echo " * $COUNT tracks in $SHOW_TOTALTIME. Average $SHOW_AVERAGETIME per track"
    fi
    case "$1" in
	*.m3x|*.m3u|*.M3X|*.M3U)
	    # we have a m3u already...
	    PLAYLISTFILE=$1
	    ;;
	-album)
	    ALBUM=true
	    # unknown/no option given, we make our own
	    do_findpldir 
	    echo " * Auto updating $PLAYLISTTYPE playlist now"
	    do_findsongs
	    SONGLISTFILE="$PLAYLISTAT/playlist.m3x"
	    do_findalbums
	    PLAYLISTFILE="$PLAYLISTAT/.albumlist"
	    ;;
	*)
	    # unknown/no option given, we make our own
	    do_findpldir 
	    echo " * Auto updating $PLAYLISTTYPE playlist now"
	    do_findsongs
	    SONGLISTFILE="$PLAYLISTAT/playlist.m3x"
	    PLAYLISTFILE=$SONGLISTFILE
    esac
    ITEMCOUNT=$(grep -c -v "^#" $PLAYLISTFILE)
    echo -n " * Items in playlist: $ITEMCOUNT"
    [ "$HISTORYMADE" -ne "1" ] && do_mkhistory
    echo " ...history size is $HISTORYSIZE"
  fi
  do_playrandom
  COUNT=$((COUNT+1))
done

# actually, this last bit never occurs, since the ^c'ing out of the
# previous loop exits the script. I've not bothered to capture the signal
# and handle it properly. 
echo "$COUNT songs played"
