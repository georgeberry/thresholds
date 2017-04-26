#!/bin/bash


# find /Volumes/Starbuck/class/twitter_data/modified_essential/US_GB_CA_AU_NZ_SG/part-014*.bz2 -print0 | xargs -0 -n1 -P6 -- bash -c './timelines_from_raw.sh "$0"'

BASEN=$(basename "$1")
OUTB=${BASEN}
OUTX=".tsv"
OUTN=$OUTB$OUTX

bzcat $1 | cut -f2 | jq -r '{"obama2012": 1, "election2012": 1, "kony2012": 1, "romney": 1, "rippaulwalker": 1, "teamobama": 1, "bringbackourgirls": 1, "trayvonmartin": 1, "hurricanesandy": 1, "cantbreathe": 1, "miley": 1, "olympics2014": 1, "prayfornewtown": 1, "goodbyebreakingbad": 1, "governmentshutdown": 1, "riprobinwilliams": 1, "romneyryan2012": 1, "harlemshake": 1, "euro2012": 1, "marriageequality": 1, "benghazi": 1, "debate2012": 1, "newtown": 1, "linsanity": 1, "zimmerman": 1, "betawards2014": 1, "justicefortrayvon": 1, "samelove": 1, "worldcupfinal": 1, "prayersforboston": 1, "nobama": 1, "ferguson": 1, "springbreak2014": 1, "drawsomething": 1, "nfldraft2014": 1, "romney2012": 1, "snowden": 1, "replaceashowtitlewithtwerk": 1, "inaug2013": 1, "ivoted": 1, "trayvon": 1, "ios6": 1, "voteobama": 1, "jodiarias": 1, "windows8": 1, "mentionsomebodyyourethankfulfor": 1, "sharknado2": 1, "gop2012": 1, "whatdoesthefoxsay": 1, "firstvine": 1} as $x
| .
| .user[0].id_str as $uid
| select(
  [.tweets[].entities.hashtags[].text | ascii_downcase | in($x)]
  | any)
| .tweets[]
| "\($uid)\t\(.created_at)\t\(.id_str)\t\(.text)\t\([.entities.hashtags[].text | ascii_downcase])"' > /Volumes/Starbuck/class/twitter_data/thresholds/$OUTN
