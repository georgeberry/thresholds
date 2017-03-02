create table if not exists Hashtags (
    hashtag varchar(140),
    count bigint
);

create table if not exists Tweets (
    userid bigint,
    raw_text text,
    created_at timestamp,
    hashtag varchar(140) -- binary json, contains array
);

create table if not exists RawEdges(
    src bigint,
    dst bigint
);

create table if not exists TimestampEdges(
    src bigint,
    dst bigint,
    create_time timestamp
);
