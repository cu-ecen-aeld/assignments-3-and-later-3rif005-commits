#!/bin/sh
# Tester script for assignment 4
# Author: Siddhant Jajoo

set -e
set -u

NUMFILES=10
WRITESTR=AELD_IS_FUN
WRITEDIR=/tmp/aeld-data
# Requirement: Config files are at /etc/finder-app/conf
CONF_DIR=/etc/finder-app/conf

# If the config directory doesn't exist, fall back to local conf (for local testing)
if [ ! -d "${CONF_DIR}" ]; then
    CONF_DIR=conf
fi

username=$(cat ${CONF_DIR}/username.txt)

if [ $# -lt 3 ]
then
    echo "Using default value ${WRITESTR} for string to write"
    if [ $# -lt 1 ]
    then
        echo "Using default value ${NUMFILES} for number of files to write"
    else
        NUMFILES=$1
    fi      
else
    NUMFILES=$1
    WRITESTR=$2
    WRITEDIR=/tmp/aeld-data/$3
fi

MATCHSTR="The number of files are ${NUMFILES} and the number of matching lines are ${NUMFILES}"

echo "Writing ${NUMFILES} files containing string ${WRITESTR} to ${WRITEDIR}"

rm -rf "${WRITEDIR}"

# Requirement: Config files are at /etc/finder-app/conf
assignment=$(cat ${CONF_DIR}/assignment.txt)

if [ $assignment != 'assignment1' ]
then
    mkdir -p "$WRITEDIR"
    if [ -d "$WRITEDIR" ]; then
        echo "$WRITEDIR created"
    else
        exit 1
    fi
fi

for i in $( seq 1 $NUMFILES)
do
    # Requirement: Run with executables found in the PATH
    writer "$WRITEDIR/${username}$i.txt" "$WRITESTR"
done

# Requirement: Run with executables found in the PATH
OUTPUTSTRING=$(finder.sh "$WRITEDIR" "$WRITESTR")

# Requirement: Write output to /tmp/assignment4-result.txt
echo "${OUTPUTSTRING}" > /tmp/assignment4-result.txt

# remove temporary directories
rm -rf /tmp/aeld-data

set +e
echo ${OUTPUTSTRING} | grep "${MATCHSTR}"
if [ $? -eq 0 ]; then
    echo "success"
    exit 0
else
    echo "failed: expected ${MATCHSTR} in ${OUTPUTSTRING} but instead found"
    exit 1
fi
