--------------------------- BEGIN BASIC DATA TABLES ----------------------------

create table if not exists Edges (
  src bigint,
  dst bigint
);
-- create index edge_idx on Edges (src, dst);
-- cluster Edges using edge_idx;

-- this table holds all the edges
create table if not exists ExpandedEdges (
  src bigint,
  dst bigint
);

-- Has all tweets for people who used one of the 50 hashtags at least once
create table if not exists Tweets (
  src bigint,
  tid varchar(20),
  created_at timestamp,
  tweet_text text,
  hashtag varchar(140)
);
-- create index twt_idx on Tweets (src);
-- cluster Tweets using twt_idx;
-- create index twt_htag_idx on Tweets (hashtag);

create table if not exists FocalHashtags(
  hashtag varchar(140)
);

insert into FocalHashtags (hashtag)
values
  ('obama2012'),
  ('election2012'),
  ('kony2012'),
  ('romney'),
  ('rippaulwalker'),
  ('teamobama'),
  ('bringbackourgirls'),
  ('trayvonmartin'),
  ('hurricanesandy'),
  ('cantbreathe'),
  ('miley'),
  ('olympics2014'),
  ('prayfornewtown'),
  ('goodbyebreakingbad'),
  ('governmentshutdown'),
  ('riprobinwilliams'),
  ('romneyryan2012'),
  ('harlemshake'),
  ('euro2012'),
  ('marriageequality'),
  ('benghazi'),
  ('debate2012'),
  ('newtown'),
  ('linsanity'),
  ('zimmerman'),
  ('betawards2014'),
  ('justicefortrayvon'),
  ('samelove'),
  ('worldcupfinal'),
  ('prayersforboston'),
  ('nobama'),
  ('ferguson'),
  ('springbreak2014'),
  ('drawsomething'),
  ('nfldraft2014'),
  ('romney2012'),
  ('snowden'),
  ('replaceashowtitlewithtwerk'),
  ('inaug2013'),
  ('ivoted'),
  ('trayvon'),
  ('ios6'),
  ('voteobama'),
  ('jodiarias'),
  ('windows8'),
  ('mentionsomebodyyourethankfulfor'),
  ('sharknado2'),
  ('gop2012'),
  ('whatdoesthefoxsay'),
  ('firstvine');

-------------------------- SIMPLE SORTING FUNCTION -----------------------------

-- Array sort function, sorts desc
CREATE OR REPLACE FUNCTION array_sort (ANYARRAY)
RETURNS ANYARRAY LANGUAGE SQL
AS $$
SELECT ARRAY(SELECT unnest($1) ORDER BY 1 DESC)
$$;

--------------------------- BEGIN DERIVED TABLES -------------------------------

-- All source ids
create table if not exists AllSrcIds (
  src bigint
);
-- create index all_src_idx on AllSrcIds (src);

insert into AllSrcIds
select distinct src
from Tweets;

-- total htag counts, not just first usages
create table if not exists TotalHashtagCounts (
  hashtag varchar(140),
  count bigint
);

insert into TotalHashtagCounts
select
  hashtag,
  count(*) as count
from Tweets
where hashtag in (select hashtag from FocalHashtags)
group by hashtag;

-- Build ego update vectors for everyone (entire timeline)
create table if not exists Updates (
  src bigint,
  src_updates timestamp[]
);

insert into Updates
select
  src,
  array_sort(array_agg(created_at))
from Tweets
group by src;

-- Get first usages of focal hashtags for everyone
create table if not exists FirstUsages (
  src bigint,
  hashtag varchar(140),
  first_usage timestamp
);

insert into FirstUsages
select distinct on (src, hashtag) -- postgres magic, takes first row in group
  src,
  hashtag,
  created_at
from Tweets
where hashtag in (select hashtag from FocalHashtags)
order by src, hashtag, created_at asc nulls last;

-- Hashtag counts
create table if not exists FirstUsageCounts (
  hashtag varchar(140),
  count bigint
);

insert into FirstUsageCounts
select
  hashtag,
  count(*) as count
from FirstUsages
group by hashtag
order by count desc;

/*
Check that the magic works

select
  src,
  hashtag,
  created_at
from Tweets
where src = 16992416
and hashtag = 'benghazi'
order by created_at asc nulls last
limit 1;

select distinct on (src, hashtag)
  src,
  hashtag,
  created_at
from Tweets
where src = 16992416
and hashtag = 'benghazi'
order by src, hashtag, created_at asc nulls last;
 */

-- Each edge by each src first usage of a focal hashtag
create table if not exists FirstUsageEdges (
  src bigint,
  dst bigint,
  hashtag varchar(140),
  src_first_usage timestamp
);

insert into FirstUsageEdges
select
  a.src,
  b.dst,
  a.hashtag,
  a.first_usage as src_first_usage
from FirstUsages a
join Edges b
on a.src = b.src;

-- Add dst_first_usage to prevous table
create table if not exists FirstUsageEdgesPlusDst (
  src bigint,
  dst bigint,
  hashtag varchar(140),
  src_first_usage timestamp,
  dst_first_usage timestamp
);

insert into FirstUsageEdgesPlusDst
select
  a.src,
  a.dst,
  a.hashtag,
  a.src_first_usage,
  b.first_usage as dst_first_usage
from FirstUsageEdges a
inner join FirstUsages b -- only want cases where dst has used hashtag
on
  a.dst = b.src and
  a.hashtag = b.hashtag;

-- Group dst activations by src, htag
create table if not exists AggregatedEdges (
  src bigint,
  hashtag varchar(140),
  src_first_usage timestamp,
  dst_first_usage_arr timestamp[]
);

insert into AggregatedEdges
select
  src,
  hashtag,
  src_first_usage,
  array_sort(array_agg(dst_first_usage))
from FirstUsageEdgesPlusDst
group by src, hashtag, src_first_usage;

-- Run the function
create or replace function
  activations_in_interval(timestamp, timestamp[], timestamp[])
returns int[]
as 'interval_func.so', 'activations_in_interval'
language c strict;

create table if not exists Measurements (
  src bigint,
  hashtag varchar(140),
  exposure int,
  in_interval int,
  src_update_count int
);

insert into Measurements
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
      a.src_first_usage, b.src_updates, a.dst_first_usage_arr
    ) as arr,
    array_length(b.src_updates, 1) as ego_update_count
  from AggregatedEdges a
  join Updates b
  on
    a.src = b.src
) c;


-- count the isolates ----------------------------------------------------------

create table if not exists Isolates (
  src bigint,
  hashtag varchar(140)
);

insert into Isolates
select
  a.src,
  a.hashtag
from FirstUsages a
left outer join Measurements b
on
  a.src = b.src and
  a.hashtag = b.hashtag
where b.src is null;

create table if not exists IsolatesCount (
  hashtag varchar(140),
  count int
);

insert into IsolatesCount
select
  hashtag,
  count(*) as count
from Isolates
group by hashtag
order by count desc;

-- aggregate measurements, combine w isolates ----------------------------------

create table MeasurementsWithIsolates (
  src bigint,
  hashtag varchar(140),
  exposure int,
  in_interval int,
  src_update_count int
);

insert into MeasurementsWithIsolates
select * from Measurements
union
select
  c.src,
  c.hashtag,
  c.exposure,
  c.in_interval,
  c.src_update_count
from (
  select
    a.src,
    a.hashtag,
    0 as exposure,
    0 as in_interval,
    array_length(b.src_updates, 1) as src_update_count
  from Isolates a
  join Updates b
  on a.src = b.src
) c;

-- No combination w isolates
create table if not exists AggMeasurementsNoIsolates (
  hashtag varchar(140),
  exposure int,
  in_interval int,
  count int
);

insert into AggMeasurementsNoIsolates
select
  hashtag,
  exposure,
  in_interval,
  count(*) as count
from Measurements
group by hashtag, exposure, in_interval
order by hashtag, exposure, in_interval asc;

-- Here

create table if not exists AggMeasurementsWithIsolates (
  hashtag varchar(140),
  exposure int,
  in_interval int,
  count int
);

insert into AggMeasurementsWithIsolates
  select
    hashtag,
    exposure,
    in_interval,
    count(*) as count
  from MeasurementsWithIsolates
  group by hashtag, exposure, in_interval
  order by hashtag, exposure, in_interval asc;


------------------------- SOME ADDITIONAL ANALYSES -----------------------------

-- measurements by degree ------------------------------------------------------

-- distinctify the edges
create table if not exists ExpandedEdgesDistinct (
  src bigint,
  dst bigint
);
-- create index exp_edge_idx on ExpandedEdges (src, dst);

insert into ExpandedEdgesDistinct
select
  src,
  dst
from ExpandedEdges
group by src, dst;

-- all node degrees

create table if not exists Degrees (
  src bigint,
  degree bigint
);
-- create index deg_idx on Degrees (src);

insert into Degrees
select
  src,
  count(*) as degree
from ExpandedEdgesDistinct
group by src;

-- measurements by degree
create table if not exists MeasurementsByDegrees (
  src bigint,
  hashtag varchar(140),
  exposure int,
  in_interval int,
  src_update_count int,
  src_degree int
);

insert into MeasurementsByDegrees
select
  a.src,
  a.hashtag,
  a.exposure,
  a.in_interval,
  a.src_update_count,
  b.degree as src_degree
from MeasurementsWithIsolates a
join Degrees b
on a.src = b.src;

-- Simple question: are people who are correctly measured lower degree?
select
  exposure,
  in_interval,
  avg(src_degree),
  count(*)
from MeasurementsByDegrees
where exposure >= 0
and exposure < 20
group by exposure, in_interval
order by exposure, in_interval;


-- Exposure table for pk curves ------------------------------------------------
/*
- Get edges where only dst has adopted
- Count
 */

create table if not exists ExposedEdges (
  src bigint,
  dst bigint
);

insert into ExposedEdges
-- src should be the neighbors of adopters
-- dst should be adopters
select -- filter out adopter srcs
  c.src,
  c.dst
from (
  select -- get all neighbors of adopters, dst are adopters
    b.src,
    b.dst
  from AllSrcIds a
  join ExpandedEdgesDistinct b
  on a.src = b.dst) c
left outer join AllSrcIds d on c.src = d.src -- fake an anti join
where d.src is null; -- select cases where c.src isn't in d.src

/*
Check it

select
  *
from (
  select
    src,
    dst
  from ExposedEdges
  limit 10) a
where a.dst in (select src from AllSrcIds);
 */

create table if not exists ExposureCounts (
  src bigint,
  hashtag varchar(140),
  exposure int
);

insert into ExposureCounts
select
  c.src,
  c.hashtag,
  count(*) as exposure
from (
  select
    a.src,
    b.hashtag
  from ExposedEdges a
  join FirstUsages b
  on a.dst = b.src) c
group by c.src, c.hashtag;

-- Exposures of inactive nodes
create table if not exists InactiveExposureCounts (
  hashtag varchar(140),
  exposure int,
  freq int
);

insert into InactiveExposureCounts
select
  hashtag,
  exposure,
  count(*) as freq
from ExposureCounts
group by hashtag, exposure
order by hashtag, exposure asc;

-- Min for mismeasured nodes
create table if not exists MinAssumptionThresholds (
  hashtag varchar(140),
  exposure int,
  min_freq int
);

-- note we filter on > 1 here, since 0 intervals are also mismeasured
with min_col_added as (
  select
    hashtag,
    exposure - in_interval as exposure
  from MeasurementsWithIsolates
  where in_interval > 1
)
insert into MinAssumptionThresholds
select
  hashtag,
  exposure,
  count(*) as min_freq
from min_col_added
group by hashtag, exposure
order by hashtag, exposure asc;

-- Measured summary
create table if not exists MeasuredSummary (
  hashtag varchar(140),
  exposure int,
  max_adopters int, -- number of adopters without adjustment
  min_adopters int -- correctly measured + min_freq
);

insert into MeasuredSummary
select
  a.hashtag,
  a.exposure,
  a.adopter_freq as max_adopters,
  a.correctly_measured_freq + coalesce(b.min_freq, 0) as min_adopters
from (
  select
    hashtag,
    exposure,
    count(case when in_interval = 1 then 1 end) as correctly_measured_freq,
    count(*) as adopter_freq
  from MeasurementsWithIsolates
  group by hashtag, exposure) a
join MinAssumptionThresholds b
on
  a.hashtag = b.hashtag and
  a.exposure = b.exposure
order by hashtag, exposure asc;

-- Exposures with activations
/*
Numerator = correctly measured + min/max assumption
Denominator = (active >= k) + (inactive and exposure >= k)
 */

create table if not exists PkCurves (
  hashtag varchar(140),
  exposure int,
  cum_max_exposed int,
  max_adopters int,
  cum_min_exposed int,
  min_adopters int
);

insert into PkCurves
select
  a.hashtag,
  a.exposure,
  a.cum_inactive_exposures + b.cum_max_adopters as cum_max_exposed,
  b.max_adopters,
  a.cum_inactive_exposures + b.cum_min_adopters as cum_min_exposed,
  b.min_adopters
from (
  select -- cumulative sums for inactive exposures
    hashtag,
    exposure,
    sum(freq) over (
      partition by hashtag order by exposure desc
    ) as cum_inactive_exposures
  from InactiveExposureCounts
) a
join (
  select -- cumulative sums for min/max exposures
    hashtag,
    exposure,
    max_adopters,
    min_adopters,
    sum(max_adopters) over (
      partition by hashtag order by exposure desc
    ) as cum_max_adopters,
    sum(min_adopters) over (
      partition by hashtag order by exposure desc
    ) as cum_min_adopters
  from MeasuredSummary
) b
on
  a.hashtag = b.hashtag and
  a.exposure = b.exposure
order by hashtag, exposure asc;

-- Adoptions per day for focal hashtags ----------------------------------------

create table if not exists FirstUsagesByDay (
  hashtag varchar(140),
  day date,
  count int
);

insert into FirstUsagesByDay
select
  hashtag,
  first_usage::date as day,
  count(*)
from FirstUsages
group by hashtag, first_usage::date
order by hashtag, first_usage::date;

-- Data for small graph inventory ----------------------------------------------
/*
We need the entire graph, and we've already calculated mismeasurements
So we want to get
  - all the edges of adopters for a tag
  - node, hashtag, exposure at activation, interval
 */

create table if not exists HashtagEdges (
  hashtag varchar(140),
  src bigint,
  src_first_usage timestamp,
  dst bigint,
  dst_first_usage timestamp
);

insert into HashtagEdges
select
  c.src_hashtag as hashtag,
  c.src,
  c.src_first_usage,
  c.dst,
  d.first_usage as dst_first_usage
from (
  select
    a.src,
    b.hashtag as src_hashtag,
    b.first_usage as src_first_usage,
    a.dst
  from Edges a
  join FirstUsages b
  on a.src = b.src) c
join FirstUsages d
on
  c.dst = d.src and
  c.src_hashtag = d.hashtag
order by hashtag; -- hashtag here is dst hashtag


create table if not exists NodeDataForHashtagEdges (
  src bigint,
  hashtag varchar(140),
  exposure int,
  in_interval int,
  src_update_count int
);

insert into NodeDataForHashtagEdges
select
  a.src,
  b.hashtag,
  b.exposure,
  b.in_interval,
  b.src_update_count
from (
  select distinct
    src
  from HashtagEdges) a
join Measurements b
on a.src = b.src
order by hashtag, exposure;
