#!/bin/bash

# Check if there is 2 runtime arguments when run this script
if [ "$#" -ne 2 ]; then
    echo "ERROR: please include the required arguments next time!"
    exit 1
fi

writefile=$1
writestr=$2

# Check if the first runtime argument is directory
if [! -d "$writefile" ]; then
    echo "ERROR: the path is not valid!"
    exit 1
else
    echo "Path is valid"
fi

# Check if the second runtime argument is string
if [ -z "$writestr" ]; then
    echo "ERROR: the string for search is not valid!"
    exit 1
else
    echo "The string for search is valid"
fi

# create the file directory/file it is not exist
mkdir -p "$(dirname "$writefile")"
# write the string to the file 
echo "$writestr" > "$writefile"
# check if everything ok
if [ $? -ne 0 ]; then
    echo "Error: Could not create this file $writefile"
    exit 1
fi
echo "The writing process passed correctly."
