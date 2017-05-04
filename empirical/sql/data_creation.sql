/*
 * Distinct tasks:
 * 1. Get all updates for each ego
 * 2. Get ego first usage of relevant hashtags
 * 3. Get alter first usages of relevant hashtags
 */

-- Array sort function, sorts desc
CREATE OR REPLACE FUNCTION array_sort (ANYARRAY)
RETURNS ANYARRAY LANGUAGE SQL
AS $$
SELECT ARRAY(SELECT unnest($1) ORDER BY 1 DESC)
$$;

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
  count < 100000
limit 100;

-- Preprocessing: list of egos that used hashtags
-- req: RelevantHashtags
insert into RelevantHashtagEgos
select distinct
  uid as src
from SuccessTweets
where hashtag in (select hashtag from RelevantHashtags);

-- 1. Get *all* updates for each ego

-- req: RelevantHashtags, RelevantHashtagEgos
-- don't need again till final step
insert into EgoUpdates
select
  uid as src,
  array_sort(array_agg(created_at))
from SuccessTweets
where uid in (select src from RelevantHashtagEgos)
group by uid;

-- 2. Get ego first usage of all relevant hashtags

-- req: RelevantHashtags, RelevantHashtagEgos
-- don't need again till final step
insert into EgoFirstUsages
select
  uid as src,
  hashtag,
  created_at
from NeighborTags
where
  hashtag in (select hashtag from RelevantHashtags) and
  uid in (select src from RelevantHashtagEgos);

-- 3. Get alter first usages of relevant hashtags

-- req: RelevantHashtags, RelevantHashtagEgos
insert into RelevantEdges
select
  src,
  dst
from Edges
where src in (select src from RelevantHashtagEgos);

-- req: RelevantHashtags, RelevantHashtagEgos, RelevantEdges
insert into AlterFirstUsages
select
  a.dst,
  b.hashtag,
  b.created_at
from (select distinct dst from RelevantEdges) a
left join NeighborTags b
on a.dst = b.uid
where b.hashtag in (select hashtag from RelevantHashtags);

-- need to uniqify

-- req: RelevantHashtags, RelevantHashtagEgos, RelevantEdges, AlterFirstUsages
insert into EdgeHashtagTimes
select
  a.src,
  a.dst,
  b.hashtag,
  b.created_at
from RelevantEdges a
inner join AlterFirstUsages b
on a.dst = b.dst;

-- req: RelevantHashtags, RelevantHashtagEgos, RelevantEdges, AlterFirstUsages, EdgeHashtagTimes
insert into EdgeWithAlterUsages
select
  src,
  hashtag,
  array_sort(array_agg(created_at)) AS first_usages
from EdgeHashtagTimes
group by src, hashtag;

-- 4. aggregate

-- read off the EgoUpdate table when needed, don't store it repeatedly
insert into AggregatedFirstUsages
select
  a.src,
  a.hashtag,
  a.created_at AS ego_activation,
  b.first_usages AS alter_usages
from EgoFirstUsages a
join EdgeWithAlterUsages b
on
  a.src = b.src and
  a.hashtag = b.hashtag;

-- 5. analyze

insert into ThresholdTable
select
  c.src,
  c.hashtag,
  c.arr[1] as exposure,
  c.arr[2] as in_interval,
  c.ego_update_count
from (
  select
    a.src,
    a.hashtag,
    activations_in_interval(
      a.ego_activation, b.ego_updates, a.alter_usages
    ) as arr,
    array_length(b.ego_updates, 1) as ego_update_count
  from AggregatedFirstUsages a
  inner join EgoUpdates b
  on
    a.src = b.src
) c;
