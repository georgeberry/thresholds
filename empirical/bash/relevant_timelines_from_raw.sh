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



# Timelines where at least one tweet contains a hashtag in the list
# Best candidate
cat test1.json | jq '.
| .user[0].id_str as $uid
| select(
  [.tweets[].entities.hashtags[].text | in({"nofilter": 1})]
  | any)
| .tweets[]
| "\(.text)\t\($uid)\t\(.id_str)\t\(.created_at)"' > test1.tsv







## more testing ##

cat test1.json | jq '.
| .user[0].id_str as $uid
| .tweets[].entities.hashtags[].text
| select(map(in({"nofilter": 1})) | any)
| .tweets[]
| "\(.text)\t\($uid)\t\(.id_str)\t\(.created_at)"' > test1.tsv

# slower
cat test1.json | jq '.
| .user[0].id_str as $uid
| .tweets[]
| {uid: $uid, text: .text, created_at: .created_at, hashtag: .entities.hashtags[].text}
| "\(.text)\t\($uid)\t\(.id_str)\t\(.created_at)"' > test1.tsv

cat test1.json | jq '.
| .user[0].id_str as $uid
| select(
  [.tweets[].entities.hashtags[].text | in({"nofilter": 1})]
  | any)
| .tweets[]
| "\(.text)\t\($uid)\t\(.id_str)\t\(.created_at)"' > test1.tsv





# 57s
time bzcat part-00000.bz2 | head -n1000 | cut -f2 | jq '.
| .user[0].id_str as $uid
| select(
  [.tweets[].entities.hashtags[].text | in({"nofilter": 1})]
  | any)
| .tweets[]
| "\(.text)\t\($uid)\t\(.id_str)\t\(.created_at)"' > ~/test1.tsv

time bzcat part-00000.bz2 | head -n1000 | cut -f2 | jq '.
| .user[0].id_str as $uid
| select(
  [.tweets[].entities.hashtags[].text | in({"nofilter": 1})]
  | any)' > ~/test1.tsv


# 1m1s
time bzcat part-00000.bz2 | head -n1000 | cut -f2 | jq '.
| .user[0].id_str as $uid
| .tweets[]
| {uid: $uid, text: .text, created_at: .created_at, hashtag: .entities.hashtags[].text}
| "\(.text)\t\($uid)\t\(.id_str)\t\(.created_at)"' > ~/test1.tsv


# 1m1s
time bzcat part-00000.bz2 | head -n1000 | cut -f2 | jq '.
| .user[0].id_str as $uid
| .tweets[]
| {uid: $uid, text: .text, created_at: .created_at, hashtag: .entities.hashtags[].text}
| "\(.text)\t\($uid)\t\(.id_str)\t\(.created_at)"' > ~/test1.tsv
