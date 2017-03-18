/*
We need to
  1. get a set of hashtags
  2. get ego windows for first usage of those hashtags
  3. get all alter usages of those hashtags
  4. compute how many alters used a hashtag in the window
  5. compute total number of alters that used hashtag before ego first usage

*/


-- 1. Get relevant hashtags

-- 2. Get windows for first usage of relevant hashtags
-- To speed this up, store tweets by htag_users sorted by uid, created_at desc
with htag_users as (
  select distinct uid from successtweets where hashtag = 'xfiles'
), update_tweets as (
select
  uid,
  tid,
  created_at,
  hashtag,
  -- Takes up to 11 rows (10 intervals)
  -- Gives json array with up to 11 items in descending time order
  jsonb_agg(created_at) over (
    partition by uid
    order by created_at desc
    rows between current row and 10 following
  ) as prev_update
from successtweets
where uid in (select uid from htag_users)
)
select
  uid,
  first_value(tid),
  first_value(created_at),
  hashtag,
  first_value(prev_update)
from update_tweets
where hashtag = 'xfiles'
window as w (
  partition by uid, hashtag
  order by created_at asc
);

-- 3. Get all alter usages of relevant hashtags
with htag_users as (
  select distinct uid from successtweets where hashtag = 'xfiles'
), htag_edges as (
  select src, dst from edges where src in (select uid from htag_users)
), first_usages as (
  select
    uid AS nid,
    first_value(created_at) over w AS first_use,
    hashtag
  from neighbortags
  where hashtag = 'xfiles'
  window w as (partition by uid, hashtag order by created_at asc)
)
select
  a.src,
  a.dst,
  b.hashtag,
  b.first_use
from htag_edges a
inner join first_usages b
on
  a.dst = b.nid
order by src, first_use asc;

-- 4 & 5.

-- go through each interval in query 2., count number of tweets from query 3.
-- are in that interval. if > 0, bail out and return number, if 0, keep going
