/*
We need to
  1. get a set of hashtags
  2. get ego windows for first usage of those hashtags
  3. get all alter usages of those hashtags
  4. compute how many alters used a hashtag in the window
  5. compute total number of alters that used hashtag before ego first usage

*/


-- 1. Get relevant hashtags

with ordered_hashtags as (
  select
    hashtag,
    count
  from hashtags
  order by count desc
)
insert into TestRelevantHashtags
select
  hashtag
from
  ordered_hashtags
where
  count < 10000
limit 10;

-- 2. Get windows for first usage of relevant hashtags
-- To speed this up, store tweets by htag_users sorted by uid, created_at desc
with htag_users as (
  select distinct uid from successtweets
  where hashtag in (select hashtag from TestRelevantHashtags)
)
insert into TestEgoUpdates
select distinct on (a.uid) -- if ties, pick an arbitrary one
  a.uid,
  first_value(a.created_at) over w,
  a.hashtag,
  first_value(a.prev_updates) over w
from (
  select distinct
    uid,
    created_at,
    hashtag,
    -- Takes up to 11 rows (10 intervals)
    -- Gives json array with up to 11 items in descending time order
    array_agg(created_at) over (
      partition by uid
      order by created_at desc
      rows between current row and 200 following
    ) as prev_updates
  from successtweets
  where uid in (select uid from htag_users)
  -- Can't do a where hashtag = 'tag' here because where is applied before window
) a
-- This is the correct place for this filter
where hashtag in (select hashtag from TestRelevantHashtags)
window w as (
  partition by uid, hashtag
  order by created_at asc
);

-- 3. Get all alter usages of relevant hashtags
with htag_users as (
  select distinct uid from successtweets
  where hashtag in (select hashtag from TestRelevantHashtags)
), htag_edges as (
  select src, dst from edges where src in (select uid from htag_users)
), distinct_alters as (
  select distinct dst from htag_edges
)
insert into TestAlterUsages
select
  c.src,
  c.hashtag,
  array_agg(c.first_usage)
from (
  select
    a.src,
    a.dst,
    b.hashtag,
    b.first_usage
  from htag_edges a
  inner join (
    -- selects neighbor id, first usage, hashtag
    -- for all relevant hashtags used by neighbors
    select
      uid as nid,
      first_value(created_at) over w as first_usage,
      hashtag
    from neighbortags
    where uid in (select dst from distinct_alters)
      and hashtag in (select hashtag from TestRelevantHashtags)
    window w as (partition by uid, hashtag order by created_at asc)
  ) b
  on
    a.dst = b.nid
  order by src, first_usage desc
) c
group by src, hashtag;

-- 4.
insert into TestUpdateTimes
select
  a.uid,
  a.hashtag,
  a.prev_updates as ego_updates,
  b.first_usages as alter_first_usages
from TestEgoUpdates a
inner join TestAlterUsages b
on a.uid = b.src and
  a.hashtag = b.hashtag;

-- 5.
-- go through each interval in query 2., count number of tweets from query 3.
-- are in that interval. if > 0, bail out and return number, if 0, keep going
