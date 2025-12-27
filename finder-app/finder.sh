#!/bin/sh
filesdir=$1
searchstr=$2

if [ $# -lt 2 ]
then
    echo "Error: Two arguments required: <directory> <search_string>"
    exit 1
fi

if [ ! -d "$filesdir" ]
then
    echo "Error: $filesdir is not a directory"
    exit 1
fi

X=$(find "$filesdir" -type f | wc -l)
Y=$(grep -r "$searchstr" "$filesdir" | wc -l)

echo "The number of files are $X and the number of matching lines are Y"
