#!/bin/bash

# Check if there is 2 runtime arguments when run this script
if [ "$#" -ne 2 ]; then
    echo "ERROR: please include the required arguments next time!"
    exit 1
fi

filesdir=$1
searchstr=$2

# Check if the first runtime argument is directory
if [ -d "$filesdir" ]; then
    echo "Path is valid"
else
    echo "ERROR: the path is not valid!"
    exit 1
fi

# Check if the first runtime argument is directory
if [ -z "$searchstr" ]; then
    echo "ERROR: the string for search is not valid!"
    exit 1
else
    echo "The string for search is valid"
fi

# note: wc -l is count the number of lines from the output of the command 1
#       because whe  we do command1 | command2 , the command1 create output
#       then the command 2 takes that output as input
X=$(find "$filesdir" -type f | wc -l)
Y=$(grep -r -n "$searchstr" "$filesdir" | wc -l)
echo "The number of files are $X and the number of matching lines are $Y"