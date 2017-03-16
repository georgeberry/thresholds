/*
We need to
  1. get a set of hashtags
  2. get ego windows for first usage of those hashtags
  3. get all alter usages of those hashtags
  4. compute how many alters used a hashtag in the window
  5. compute total number of alters that used hashtag before ego first usage

*/


-- Get relevant hashtags

-- Get windows
with htag_users as (
  select distinct uid from successtweets where hashtag = 'TeamUSA'
)
select
  uid,
  tid,
  created_at,
  lag(created_at, 1) over (partition by uid order by created_at asc) prev_update
from successtweets
where uid in (select uid from htag_users);




-- Get all alter usages of relevant hashtags
with htag_users as (
  select distinct uid from successtweets where hashtag = 'TeamUSA'
), htag_edges as (
  select src, dst from edges where src in (select uid from htag_users)
), first_usages as (
  select
    uid AS nid,
    first_value(created_at) over w AS first_use,
    hashtag
  from neighbortags
  window w as (partition by uid, hashtag order by created_at asc)
  where hashtag = 'TeamUSA'
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

--
