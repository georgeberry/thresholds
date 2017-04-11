/*
 * Distinct tasks:
 * 1. Get all updates for each ego
 * 2. Get ego first usage of relevant hashtags
 * 3. Get alter first usages of relevant hashtags
 */


-- Preprocessing: get relevant hashtags
with ordered_hashtags as (
  select
    hashtag,
    count
  from hashtags
  order by count desc
)
insert into RelevantHashtags
select
  hashtag
from
  ordered_hashtags
where
  count < 10000
limit 10;

-- Preprocessing: list of egos that used hashtags

-- req: RelevantHashtags
insert into RelevantHashtagEgos
select distinct
  uid
from SuccessTweets
where hashtag in (select hashtag from RelevantHashtags);

-- 1. Get *all* updates for each ego

-- req: RelevantHashtags, RelevantHashtagEgos
insert into EgoUpdates
select
  uid,
  array_agg(created_at)
from SuccessTweets
where uid in (select uid from RelevantHashtagEgos)
group by uid;

-- 2. Get ego first usage of all relevant hashtags

-- req: RelevantHashtags, RelevantHashtagEgos
insert into EgoFirstUsages
select
  uid,
  hashtag,
  created_at
from NeighborTags
where
  hashtag in (select hashtag from RelevantHashtags) and
  uid in (select uid from RelevantHashtagEgos);

-- 3. Get alter first usages of relevant hashtags

-- req: RelevantHashtags, RelevantHashtagEgos
insert into RelevantEdges
select
  src,
  dst
from Edges
where src in (select uid from RelevantHashtagEgos);

-- req: RelevantHashtags, RelevantHashtagEgos, RelevantEdges
insert into AlterFirstUsages
select
  a.dst AS uid,
  b.hashtag,
  b.created_at
from (select distinct dst from RelevantEdges) a
left join NeighborTags b
on a.dst = b.uid
where b.hashtag in (select hashtag from RelevantHashtags);

-- req: RelevantHashtags, RelevantHashtagEgos, RelevantEdges, AlterFirstUsages
insert into EdgeHashtagTimes
select
  a.src,
  a.dst,
  b.hashtag,
  b.created_at
from RelevantEdges a
inner join AlterFirstUsages b
on a.dst = b.uid;

-- req: RelevantHashtags, RelevantHashtagEgos, RelevantEdges, AlterFirstUsages, EdgeHashtagTimes
insert into EdgeFirstUsages
select
  src,
  hashtag,
  array_agg(created_at) AS first_usages
from EdgeHashtagTimes
group by src, hashtag;

-- 4. aggregate
