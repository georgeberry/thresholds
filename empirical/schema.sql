
--------------------------- BEGIN BASIC DATA TABLES ----------------------------

--- These data tables that should not be altered after creation and indexing ---

create table if not exists Hashtags (
    hashtag varchar(140),
    count bigint
);

-- create index htag_idx on Hashtags (hashtag);

create table if not exists SuccessTweets (
    uid bigint,
    tid varchar(22),
    raw_text text,
    created_at timestamp,
    hashtag varchar(140)
);

-- create index succtwt_idx on SuccessTweets (uid, hashtag);
-- cluster verbose SuccessTweets using succtwt_idx;
-- create index succtwt_htag_idx on SuccessTweets (hashtag);

create table if not exists NeighborTags (
  uid bigint,
  tid varchar(22),
  created_at timestamp,
  hashtag varchar(140)
);

-- create index nbrtag_idx on NeighborTags (uid, hashtag);
-- cluster verbose Neighbortags using nbrtag_idx;
-- create index nbrtag_htag_idx on NeighborTags (hashtag);

create table if not exists Edges(
    src bigint,
    dst bigint
);

-- create index src_idx on Edges (src);
-- alter table edges add constraint unique (src, dst);


--------------------------- END OF BASIC DATA TABLES ---------------------------

----------- These rely on the basic data tables but should persist -------------

drop table RelevantHashtags;
create table if not exists RelevantHashtags (
  hashtag varchar(140)
);

drop table RelevantHashtagEgos;
create table if not exists RelevantHashtagEgos (
  uid bigint,
  hashtag varchar(140)
);

drop table EgoUpdates;
create table if not exists EgoUpdates (
  uid bigint,
  ego_updates timestamp[]
);

drop table EgoFirstUsages;
create table if not exists EgoFirstUsages (
  uid bigint,
  hashtag varchar(140),
  created_at timestamp
);

drop table RelevantEdges;
create table if not exists RelevantEdges (
  src bigint,
  dst bigint
);

drop table AlterFirstUsages;
create table if not exists AlterFirstUsages (
  uid bigint,
  hashtag varchar(140),
  created_at timestamp
);

drop table EdgeHashtagTimes;
create table if not exists EdgeHashtagTimes (
  src bigint,
  dst bigint,
  hashtag varchar(140),
  created_at timestamp
);

drop table EdgeFirstUsages;
create table if not exists EdgeFirstUsages (
  src bigint,
  hashtag varchar(140),
  created_at timestamp[]
);


----------- These data tables can be freely modified and overwritten -----------

drop table TestRelevantHashtags;
create table if not exists TestRelevantHashtags (
  hashtag varchar(140)
);

drop table TestEgoUpdates;
create table if not exists TestEgoUpdates (
  uid bigint,
  created_at timestamp,
  hashtag varchar(140),
  prev_updates timestamp[]
);

drop table TestAlterUsages;
create table if not exists TestAlterUsages (
  src bigint,
  hashtag varchar(140),
  first_usages timestamp[]
);

drop table TestUpdateTimes;
create table if not exists TestUpdateTimes (
  src bigint,
  hashtag varchar(140),
  ego_updates timestamp[],
  alter_first_usages timestamp[]
);
