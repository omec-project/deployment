#!/bin/bash

function ask2continue()
{
# 1. parameter is the question text ($1) 
# return status: 0 = ok, continue

  if [ -z "$1" ]
  then
    question="Continue ?"
  else
    question="$1"
  fi

  if [[ $DEFAULTANSWER = "-y" ]]
  then
    return 0
  fi
  read -p "$question" Answer

  if [[ "${Answer}" = "y" || "${Answer}" = "Y" ]]
  then
    return 0
  else
    return 1
  fi
}
