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

# Created by Nemo <runranplay@nemo.house.cx> for himself. 
# Let's say it's licensed under the GPL. That's simple eh? :)

SCANRATE=20	# rescan every how many songs?
COUNT=0		# how many songs have we played?
HISTORYSIZE=100	# how much collision history to keep?
declare -a HISTORY
for i in $(seq 0 $HISTORYSIZE) ; do
  HISTORY[$i]=0
done


function do_findpldir {
  if [ -w . ] ; then
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
# find "." \( -iname \*ogg -o -iname \*OGG -o -iname \*wav -o -iname \*WAV -o -iname \*mp3 -o -iname \*MP3 \) -type f -printf '%p\n' > $PLAYLISTAT/.playlist
find "." -type f \( -iname \*ogg -o -iname \*OGG -o -iname \*wav -o -iname \*WAV -o -iname \*mp3 -o -iname \*MP3 \) -follow -printf '%p\n' > $PLAYLISTAT/.playlist.m3u
sort $PLAYLISTAT/.playlist.m3u > $PLAYLISTAT/playlist.m3u
echo " ... saved to $PLAYLISTAT/playlist.m3u"

SONGCOUNT=$(cat $PLAYLISTAT/playlist.m3u | wc -l)
echo " * Songs in playlist: $SONGCOUNT"
}


function do_getrandom {
# this functions finds us a random number, one that hasn't been used recently

# force the looping :)
UNIQUE=no

while [ "$UNIQUE" == "no" ] ; do 

  PLAYNUMBER=$(echo "($RANDOM*$SONGCOUNT)/32767+1" | bc)  # should be an integer number?

# echo -n "debug: $PLAYNUMBER"
  # assume our chosen number IS unique...
  UNIQUE=yes


# loop through the history checking for repeats
  for i in $(seq 0 $HISTORYSIZE) ; do
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
  HISTORY[$COUNTCHK]=$PLAYNUMBER
}


function do_playrandom {

# first, find a random song from that list
do_getrandom

# is there a better way to extract a specific line from a file?
SONG=$(head -n $PLAYNUMBER $PLAYLISTAT/playlist.m3u | tail -1)

SONGTYPE=${SONG##*.}

echo "$SONG"
echo "$SONG" > /tmp/.currentsong

if [ "$SONGTYPE" == "ogg" ] || [ "$SONGTYPE" == "OGG" ] ; then
  ogg123 -b 4096 -q "$SONG"
elif [ "$SONGTYPE" == "mp3" ] || [ "$SONGTYPE" == "MP3" ] ; then
  mpg123 -b 4096 -q "$SONG" 2> /dev/null
else
  bplay -B 4096 "$SONG"
fi
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
    do_findpldir 
    echo " * Auto updating $PLAYLISTTYPE playlist now"
    do_findsongs
  fi
  COUNT=$((COUNT+1))
  do_playrandom
done

# actually, this last bit never occurs, since the ^c'ing out of the
# previous loop exits the script. I've not bothered to capture the signal
# and handle it properly. 
echo "$COUNT songs played"
