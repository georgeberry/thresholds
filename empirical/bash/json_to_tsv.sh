#!/bin/bash

# FOR DEBUG:  head -n10 |\

BASEN=$(basename "$1")
OUTB=${BASEN}
OUTX=".tsv"
OUTN=$OUTB$OUTX
# echo $OUTN

bzcat $1 |\
cut -f2 |\
jq -r '. | .user[0].id_str as $uid | .tweets[] | select( .entities.hashtags | length > 0) | "\(.entities.hashtags[].text)\t\($uid)\t\(.id_str)\t\(.created_at)"'\
> $OUTN


