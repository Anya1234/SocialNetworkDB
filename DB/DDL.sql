create schema social_network;

create table social_network.user
(
    user_id           integer,
    user_nm           varchar(255) not null,
    description_txt   text,
    path_to_photo_txt varchar(255),
    valid_from_dttm   timestamp default now(),
    valid_to_dttm     timestamp default now() + interval '100 year',

    constraint version_id primary key (user_id, valid_from_dttm)
);

create table social_network.post
(
    post_id           serial primary key,
    author_id         integer,
    author_valid_from timestamp,
    post_txt          text,
    post_dttm         timestamp default now(),

    foreign key (author_id, author_valid_from) references
        social_network.user (user_id, valid_from_dttm) on delete cascade
);

create table social_network.liked_posts
(
    post_id         integer references social_network.post (post_id) on delete cascade,
    user_id         integer,
    user_valid_from timestamp,

    constraint pair_key primary key (post_id, user_id),
    foreign key (user_id, user_valid_from) references
        social_network.user (user_id, valid_from_dttm) on delete cascade
);

create table social_network.comment
(
    comment_id          serial primary key,
    author_id           integer,
    author_valid_from   timestamp,
    reply_to_code       char(7) check (reply_to_code in ('comment', 'post')),
    reply_to_post_id    integer references social_network.post (post_id) on delete cascade not null,
    reply_to_comment_id integer references social_network.comment (comment_id) on delete cascade,
    comment_txt         text                                                               not null,
    comment_dttm        timestamp default now(),

    check ((reply_to_code = 'comment' and reply_to_comment_id is not null) or
           reply_to_code = 'post'),
    foreign key (author_id, author_valid_from) references
        social_network.user (user_id, valid_from_dttm) on delete cascade
);

create table social_network.message
(
    message_id           serial primary key,
    from_id              integer,
    to_id                integer,
    from_user_valid_from timestamp,
    to_user_valid_from   timestamp,
    message_txt          text,
    message_dttm         timestamp default now(),

    foreign key (from_id, from_user_valid_from) references
        social_network.user (user_id, valid_from_dttm) on delete cascade,
    foreign key (to_id, to_user_valid_from) references
        social_network.user (user_id, valid_from_dttm) on delete cascade
);

create table social_network.attachment
(
    attachment_id        serial primary key,
    attach_to_code       char(7) check (attach_to_code in ('message', 'post')),
    attach_to_post_id    integer references social_network.post (post_id) on delete cascade,
    attach_to_message_id integer references social_network.message (message_id) on delete cascade,
    attachment_type_code varchar(20) check (attachment_type_code in
                                            ('photo', 'video', 'audio', 'post', 'file')),
    path_to_file_txt     varchar(255),
    attached_post_id     integer references social_network.post (post_id) on delete cascade,

    check ((attach_to_code = 'message' and attach_to_message_id is not null) or
           (attach_to_code = 'post' and attach_to_post_id is not null)),
    check ((attachment_type_code = 'post' and attached_post_id is not null) or
           (attachment_type_code <> 'post' and path_to_file_txt is not null)),
    check (attach_to_post_id is not null or attach_to_message_id is not null)
);

create table social_network.subscription
(
    who_subscribed_id    integer,
    who_valid_from       timestamp,
    to_who_subscribed_id integer,
    to_who_valid_from    timestamp,
    constraint subscription_key primary key (who_subscribed_id, to_who_subscribed_id),
    valid_from_dttm      timestamp default now(),
    valid_to_dttm        timestamp default now() + interval '100 year',

    foreign key (who_subscribed_id, who_valid_from) references
        social_network.user (user_id, valid_from_dttm) on delete cascade,
    foreign key (to_who_subscribed_id, to_who_valid_from) references
        social_network.user (user_id, valid_from_dttm) on delete cascade
);
