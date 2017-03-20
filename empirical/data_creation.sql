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
select distinct
  uid,
  created_at,
  hashtag,
  -- Takes up to 11 rows (10 intervals)
  -- Gives json array with up to 11 items in descending time order
  array_agg(created_at) over (
    partition by uid
    order by created_at desc
    rows between current row and 10 following
  ) as prev_updates
from successtweets
where uid in (select uid from htag_users)
-- Can't do a where hashtag = 'tag' here because where is applied before window
)
insert into TestEgoUpdates
select distinct on (uid) -- if ties, pick an arbitrary one
  uid,
  first_value(created_at) over w,
  hashtag,
  first_value(prev_updates) over w
from update_tweets
where hashtag = 'xfiles' -- This is the correct place for this filter
window w as (
  partition by uid, hashtag
  order by created_at asc
);

-- 3. Get all alter usages of relevant hashtags
with htag_users as (
  select distinct uid from successtweets where hashtag = 'xfiles'
), htag_edges as (
  select src, dst from edges where src in (select uid from htag_users)
), alter_first_usages as (
  select
    uid AS nid,
    first_value(created_at) over w AS first_usage,
    hashtag
  from neighbortags
  where hashtag = 'xfiles'
    and uid in (select distinct dst from htag_edges)
  window w as (partition by uid, hashtag order by created_at asc)
), edges_with_alter_usages as (
select
  a.src,
  a.dst,
  b.hashtag,
  b.first_usage
from htag_edges a
inner join alter_first_usages b
on
  a.dst = b.nid
order by src, first_usage desc
)
insert into TestAlterUsages
select
  src,
  hashtag,
  array_agg(first_usage)
from edges_with_alter_usages
group by src, hashtag;


/*
with htag_users as (
  select distinct uid from successtweets where hashtag = 'xfiles'
), htag_edges as (
  select src, dst from edges where src in (select uid from htag_users)
), first_usages as (
  select
    uid AS nid,
    first_value(created_at) over w AS first_usages,
    hashtag
  from neighbortags
  where hashtag = 'xfiles'
    and uid in (select distinct dst from htag_edges)
  window w as (partition by uid, hashtag order by created_at asc)
)
select * from first_usages;
 */

-- Interlude: combine the previous two queries into one table
insert into TestUpdateTimes
select
  a.uid,
  a.hashtag,
  a.prev_updates as ego_updates,
  b.first_usages as alter_first_usages
from TestEgoUpdates a
inner join TestAlterUsages b
on a.uid = b.src;

-- 4 & 5.

-- go through each interval in query 2., count number of tweets from query 3.
-- are in that interval. if > 0, bail out and return number, if 0, keep going
