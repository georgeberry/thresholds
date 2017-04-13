/*
 * Distinct tasks:
 * 1. Get all updates for each ego
 * 2. Get ego first usage of relevant hashtags
 * 3. Get alter first usages of relevant hashtags
 */

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
insert into TestRelevantHashtags
select
  hashtag
from
  ordered_hashtags
where
  count < 15000
limit 10;

-- Preprocessing: list of egos that used hashtags

-- req: TestRelevantHashtags
insert into TestRelevantHashtagEgos
select distinct
  uid as src
from SuccessTweets
where hashtag in (select hashtag from TestRelevantHashtags);

-- 1. Get *all* updates for each ego

-- req: TestRelevantHashtags, TestRelevantHashtagEgos
-- don't need again till final step
insert into TestEgoUpdates
select
  uid as src,
  array_sort(array_agg(created_at))
from SuccessTweets
where uid in (select src from TestRelevantHashtagEgos)
group by uid;

-- 2. Get ego first usage of all relevant hashtags

-- req: TestRelevantHashtags, TestRelevantHashtagEgos
-- don't need again till final step
insert into TestEgoFirstUsages
select
  uid as src,
  hashtag,
  created_at
from NeighborTags
where
  hashtag in (select hashtag from TestRelevantHashtags) and
  uid in (select src from TestRelevantHashtagEgos);

-- 3. Get alter first usages of relevant hashtags

-- req: TestRelevantHashtags, TestRelevantHashtagEgos
insert into TestRelevantEdges
select
  src,
  dst
from Edges
where src in (select src from TestRelevantHashtagEgos);

-- req: TestRelevantHashtags, TestRelevantHashtagEgos, TestRelevantEdges
insert into TestAlterFirstUsages
select
  a.dst,
  b.hashtag,
  b.created_at
from (select distinct dst from TestRelevantEdges) a
left join NeighborTags b
on a.dst = b.uid
where b.hashtag in (select hashtag from TestRelevantHashtags);

-- req: TestRelevantHashtags, TestRelevantHashtagEgos, TestRelevantEdges, TestAlterFirstUsages
insert into TestEdgeHashtagTimes
select
  a.src,
  a.dst,
  b.hashtag,
  b.created_at
from TestRelevantEdges a
inner join TestAlterFirstUsages b
on a.dst = b.dst;

-- req: TestRelevantHashtags, TestRelevantHashtagEgos, TestRelevantEdges, TestAlterFirstUsages, TestEdgeHashtagTimes
insert into EdgeWithAlterUsages
select
  src,
  hashtag,
  array_agg(created_at) AS first_usages
from TestEdgeHashtagTimes
group by src, hashtag;

-- 4. aggregate

-- read off the EgoUpdate table when needed, don't store it repeatedly
insert into TestAggregatedFirstUsages
select
  a.src,
  a.hashtag,
  a.created_at AS ego_activation,
  array_sort(b.first_usages) AS alter_usages
from TestEgoFirstUsages a
join EdgeWithAlterUsages b
on
  a.src = b.src and
  a.hashtag = b.hashtag;


-- 5. analyze
