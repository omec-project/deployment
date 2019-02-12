#!/bin/bash

# Parse options
# ##############################
DEFAULTANSWER=""
while getopts "y" opt; do
  case $opt in
    y)
      #echo "-y was triggered!" >&2
      DEFAULTANSWER="-y"
      ;;
    \?)
      if [ -n "$OPTARG"  ]
      then
        echo "Invalid option: \"$OPTARG\"" >&2
      fi
      ;;
  esac
done
shift $(($OPTIND - 1))

