# Give hashtag list
# Run through all timelines
# Preserve entire timelines where a hashtag in the list occurs
# Output a nice .tsv
#

cat test0.json | cut -f1 | jq -c '.' > test1.json

# "for every line, apply {name: .name} to first element of the user list"
cat test1.json | jq '.user[0] | {name: .name}'

# for every line apply to each element of every tweet list
cat test1.json | jq '.tweets[] | select(.entities.hashtags | length > 1) | .text'

# if you have 2+ hashtags, it preserves both
# test with hashtag #LongRun (co-occurs with #IWorkout)
cat test1.json | jq '.tweets[] | select(.entities.hashtags[].text | contains("LongRun"))'



# Timelines where any tweet contains
# TODO: Need to add hashtags
cat test1.json | jq '.
| .user[0].id_str as $uid
| select(.tweets[].entities.hashtags[].text | contains("LongRun"))
| .tweets[]
| "\(.text)\t\($uid)\t\(.id_str)\t\(.created_at)"' > test1.tsv

cat test1.json | jq '.
| .user[0].id_str as $uid
| select([.tweets[].entities.hashtags[].text == "LongRun"] | any)
| .tweets[]
| "\(.text)\t\($uid)\t\(.id_str)\t\(.created_at)"' > test1.tsv

cat test1.json | jq '.
| .user[0].id_str as $uid
| select(.tweets[].entities.hashtags[].text as $values
  | ["blue", "yellow"]
  | map([$values[] == .] | any)
  | all)
| .tweets[]
| "\(.text)\t\($uid)\t\(.id_str)\t\(.created_at)"' > test1.tsv


# How many users have at least one tweet with the term?
bzcat part-00000.bz2 | cut -f2 | jq '.
| .user[0].id_str as $uid
| select(any(.tweets[].entities.hashtags[].text | contains("tbt")))
| "\($uid)"' > ~/test2.tsv
