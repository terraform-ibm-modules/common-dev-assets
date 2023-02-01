#!/usr/bin/env bash

# Pre-commit hook that checks certain files exist in the project
# first argument must be --NUM_OF_FILES_TO_CHECK={the number of files you want to check exist}

v="${1/--/}"
declare "$v"

max=$((NUM_OF_FILES_TO_CHECK+2))

# create an array of all the files
array=()
index=0
for ((x=max; x<=$#; x++))
do
    array[index]=${!x}
    index=$((index+1))
done

# check that all files specified exist in root of project
for ((i=2; i<max; i++))
do
    if [[ ! " ${array[*]} " =~ ${!i} ]]; then
        echo "${!i} missing from project. Please correct before continuing."
        exit 1
    fi
done
