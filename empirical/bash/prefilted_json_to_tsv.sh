#!/bin/bash

# FOR DEBUG:  head -n10 |\

BASEN=$(basename "$1")
OUTB=${BASEN}
OUTX=".tsv"
OUTN=$OUTB$OUTX
# echo $OUTN

bzcat $1 |\
awk 'BEGIN { FS = "\t" } ; FNR==NR { uid[$1]=1; next } $1 in uid { print $2 }' /Volumes/pci_ssd/twitter_patrick/bidirected_us_edges/success_plus_users.txt - |\
jq -r '. | .user[0].id_str as $uid | .tweets[] | select( .entities.hashtags | length > 0) | "\(.entities.hashtags[].text)\t\($uid)\t\(.id_str)\t\(.created_at)"'\
> $OUTN
