--------------------------- BEGIN BASIC DATA TABLES ---------------------------

create table if not exists Edges (
  src bigint,
  dst bigint
);
-- create index edge_idx on Edges (src, dst);
-- cluster Edges using edge_idx;

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
  hasthag varchar(140)
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

insert into AllSrcIds
select distinct src
from Tweets;

-- Build ego update vectors for everyone (entire timeline)
create table if not exists Updates(
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
create table if not exists FirstUsages(
  src bigint,
  hashtag varchar(140),
  first_usage timestamp
);

insert into FirstUsages
select distinct on (created_at) -- postgres magic to select first row
  src,
  hashtag,
  created_at
from Tweets
where hashtag in (select hashtag from FocalHashtags)
group by src, hashtag
order by created_at desc;

-- Each edge by each src first usage of a focal hashtag
create table if not exists FirstUsageEdges(
  src bigint,
  dst bigint,
  hashtag varchar(140),
  src_first_usage timestamp,
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
create table if not exists FirstUsageEdgesPlusDst(
  src bigint,
  dst bigint,
  hashtag varchar(140),
  src_first_usage timestamp,
  dst_first_usage timestamp
);

insert into FirstUsageEdgesPlusDst
select
  a.src,
  b.dst,
  a.hashtag,
  a.src_first_usage,
  b.first_usage as dst_first_usage
from FirstUsageEdges a
inner join FirstUsages b -- only want cases where dst has used hashtag
on
  a.dst = b.src and
  a.hashtag = b.hashtag;

-- Group dst activations by src, htag
create table if not exists AggregatedEdges(
  src bigint,
  hashtag varchar(140),
  src_first_usage timestamp,
  dst_first_usage_arr timestamp[]
);

insert into AggregatedEdges
select
  src,
  hashtag
  src_first_usage,
  array_sort(array_agg(dst_first_usage))
from FirstUsageEdgesPlusDst
group by src, hashtag;

-- Run the function
create table if not exists Measurements(
  src bigint,
  hashtag varchar(140),
  exposure int,
  in_interval int,
  src_update_count int
);

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
  from AggregatedEdges a
  inner join Updates b
  on
    a.src = b.src
) c;
