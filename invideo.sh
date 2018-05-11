#!/bin/bash
ARG=$1
INPUT_TARGET=$2
TMP=/mnt/$(echo $INPUT_TARGET | sed  "s/\/dev\///g")
DEST_FOLDER=$3
HASH_LIST=$DEST_FOLDER/.hash_list

echo "BRUNINI invideo v0.1 beta"

if [[ $ARG = "-m" ]] || [[ $ARG = "-f" ]] || [[ $ARG = "-h" ]] || [[ $ARG = "-c" ]]; then
    echo ""
else
    echo "You must specify an valid argument, use -h to see the documentation."
    exit 0
fi

if [ $ARG = "-m" ]; then
    for LINE in $(df | tr -s " " | cut -d " " -f1,6)
    do
        if [ $INPUT_TARGET = $LINE ]; then
            MP=$(df | grep $INPUT_TARGET | tr -s " " | cut -d " " -f6)
            echo "$INPUT_TARGET is already mounted in $MP, please unmount or specify the mounting point instead. "
            exit 0
        fi
    done
    mkdir -p $TMP
    mount $INPUT_TARGET $TMP
    TARGET=$TMP
    echo "$INPUT_TARGET is now mounted in $TARGET."
fi

if [ $ARG = "-f" ]; then
    TARGET=$INPUT_TARGET
fi

if [ $ARG = "-c" ]; then
    TARGET=$INPUT_TARGET
    HASH_LIST=$INPUT_TARGET/.hash_list
fi

if [ $ARG = "-h" ]; then
    echo "
    Usage: invideo [OPTION] [TARGET] [DESTINATION_FOLDER] [HASH_LIST]
    Copy videos files from memory into folders if the file hash not exists on incremental list.

    Mandatory arguments are.
    -f                  Specify an already mounted folder as target to searching video files and copy.
    -m                  Specify device to be temporary mounted  and user as target to searching video files and copy.
    -c                  Generate hash list of previous copied files and don't copy anything."
    exit 0
fi

if [ -z "$4" ]; then
    echo "Hash list is not specified."
else
    HASH_LIST=$4
fi

if [ -f $HASH_LIST ]; then
   echo "Using hash list in $HASH_LIST."
else
   echo "Creating hash list in $HASH_LIST."
   touch $HASH_LIST
fi

echo ""
echo "Searching for files in $TARGET."
find $TARGET -type f -name "*.MTS" -o -name "*.MPG" -o -name "*.MOV" -o -name "*.JPG" | while read FILE_PATH
do
    EXISTS=0
    echo ''
    echo "Calculating partial file hash of $FILE_PATH"
    FILE_HASH=$(cat "$FILE_PATH" | head -n 30720 | sha512sum  | cut -d " " -f1)
    SH=${FILE_HASH:0:15}
    echo "Verify if $SH exists on hash list"
    for HASH_LINE in $(cat $HASH_LIST)
    do
        if [ $FILE_HASH = $HASH_LINE ]; then
            EXISTS=1
            break
        fi
    done
    if [ $EXISTS -eq 1 ]; then
        echo $SH "exists in hash list, passing."
    else
        if [ $ARG = "-c" ]; then
            echo "Writing full hash to the list."
        else
            echo $SH "not exists in hash list, copying."
            FILENAME=$(basename -- "$FILE_PATH")
            EXTENSION="${FILENAME##*.}"
            FILENAME="${FILENAME%.*}"
            pv "$FILE_PATH" > $DEST_FOLDER/$FILENAME.$SH.$EXTENSION
        fi
        echo $FILE_HASH >> $HASH_LIST 
    fi
done


if [[ $TARGET = $TMP ]]; then
        umount $TMP
        rm -rf $TMP
    echo "Temporary mounting point is now unmonted and deleted."
fi
