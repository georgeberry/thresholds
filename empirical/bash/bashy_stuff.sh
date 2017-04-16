bzcat /Volumes/Starbuck/class/twitter_data/modified_essential/US_GB_CA_AU_NZ_SG/part-01424.bz2 | head -n100 | cut -f2 | jq -c '.' > ~/Expire/temp.json

head -n1 ~/Expire/temp.json

head -n1 ~/Expire/temp.json | jq '{ user: .user, tweets: [.tweets[] | select( .entities.hashtags | length > 0)| {text: .text, entities.hashtags: .entities.hashtags, id_str: .id_str, created_at: .created_at} ]}'

head -n1 ~/Expire/temp.json | jq -r '. | .tweets[] | select( .entities.hashtags | length > 0) | "\(.id_str)\t\(.created_at)\t\(.entities.hashtags[].text)"'

cat ~/Expire/temp.json | jq -r '"\(.tweets[].entities.hashtags[].text?)\t\(.user[0].id_str)\t\(.tweets[].created_at)\t\(.tweets[].id_str)"' > ~/Expire/test.tsv

cat ~/Expire/temp.json | jq -r '. | .user[0].id_str as $uid | .tweets[] | select( .entities.hashtags | length > 0) | "\(.entities.hashtags[].text)\t\($uid)\t\(.id_str)\t\(.created_at)"' > ~/Expire/test.tsv



find /Volumes/Starbuck/class/twitter_data/modified_essential/US_GB_CA_AU_NZ_SG/part-*.bz2 -print0 | xargs -0 -n1 -P6 -- bash -c '~/Expire/json_to_tsv.sh "$0"'

FILE1=$1

BASEN=${$1##*/}
BASEN=${$BASEN%.*}
echo du $$1
echo BASEN


bzcat $1 | jq -r '. | .user[0].id_str as $uid | .tweets[] | select( .entities.hashtags | length > 0) | "\(.entities.hashtags[].text)\t\($uid)\t\(.id_str)\t\(.created_at)"' >

$BASEN



awk 'NR==1 { next } FNR==NR { a[$1]=$2; next } $1 in a { $1=a[$1] }1' TABLE OLD_FILE

NR==1 { next }            # simply skip processing the first line (header) of
                          # the first file in the arguments list (TABLE)

FNR==NR { ... }           # This is a construct that only returns true for the
                          # first file in the arguments list (TABLE)

a[$1]=$2                  # So when we loop through the TABLE file, we add the
                          # column one to an associative array, and we assign
                          # this key the value of column two

next                      # This simply skips processing the remainder of the
                          # code by forcing awk to read the next line of input

$1 in a { ... }           # Now when awk has finished processing the TABLE file,
                          # it will begin reading the second file in the
                          # arguments list which is OLD_FILE. So this construct
                          # is a condition that returns true literally if column
                          # one exists in the array

$1=a[$1]                  # re-assign column one's value to be the value held
                          # in the array

1                         # The 1 on the end simply enables default printing. It
                          # would be like saying: $1 in a { $1=a[$1]; print $0 }'


awk 'BEGIN { FS = "\t" } ; FNR==NR { uid[$1]=1; next } $1 in uid { print }' /Volumes/pci_ssd/twitter_patrick/bidirected_us_edges/success_plus_users.txt ~/Expire/first1000.txt



 bzcat /Volumes/Starbuck/class/twitter_data/modified_essential/US_GB_CA_AU_NZ_SG/part-01424.bz2 | head -n100 | awk 'BEGIN { FS = "\t" } ; FNR==NR { uid[$1]=1; next } $1 in uid { print $1 }' /Volumes/pci_ssd/twitter_patrick/bidirected_us_edges/success_plus_users.txt -


awk 'BEGIN { FS = "\t" } ; FNR==NR { uid[$1]=1; next } $1 in uid { print $1 }' /Volumes/pci_ssd/twitter_patrick/bidirected_us_edges/success_plus_users.txt $(bzcat /Volumes/Starbuck/class/twitter_data/modified_essential/US_GB_CA_AU_NZ_SG/part-01424.bz2 | head -n1000)


prefilted_postfiltered_json_to_tsv.sh /Volumes/Starbuck/class/twitter_data/modified_essential/US_GB_CA_AU_NZ_SG/part-01424.bz2
