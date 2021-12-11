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



/*
 * Функция, возвращающая дату текущего пользователя по его id
 */
create or replace function get_current_valid_date_from(id integer) returns timestamp
as
$$
declare
    date   timestamp := now();
    result timestamp := null;
begin
    for date in
        select valid_from_dttm from social_network.user where valid_to_dttm >= now() and user_id = id
        loop
            result = date;
        end loop;
    return result;
end;
$$
    language plpgsql;


/*
 * Процедура, пересылающая сообщение вместе с вложениями
 */
create or replace procedure forward_message(id integer, from_usr integer, to_usr integer)
as
$$
declare
    message_text   text         := NULL;
    new_message_id int          := NULL;
    max_value      int          := 0;
    type_code      varchar(20)  := NULL;
    path_to_file   varchar(255) := NULL;
    post_id        integer      := NULL;

begin
    for message_text in select message_txt from social_network.message where message_id = id
        loop
            insert into social_network.message (from_id, to_id, from_user_valid_from, to_user_valid_from, message_txt)
            values (from_usr, to_usr, null, null, message_text);
        end loop;


    for max_value in select max(message_id) from social_network.message group by id
        loop
            new_message_id = max_value;
        end loop;

    for type_code, path_to_file, post_id in select attachment_type_code, path_to_file_txt, attached_post_id
                                            from social_network.attachment
                                            where attach_to_message_id = id
        loop
            insert into social_network.attachment (attach_to_code, attach_to_post_id, attach_to_message_id,
                                                   attachment_type_code, path_to_file_txt, attached_post_id)
            values ('message', null, new_message_id, type_code, path_to_file, post_id);
        end loop;


end;
$$
    language plpgsql;



/*
 * при вставке новой версии юзера обновляем время в старой версии
 */
create or replace function update_or_insert_user() returns trigger
as
$$
begin
    update social_network.user
    set valid_to_dttm = new.valid_from_dttm
    where user_id = new.user_id
      and valid_to_dttm > new.valid_from_dttm;
    return new;
end;
$$
    language plpgsql;

create trigger user_insert
    before insert
    on social_network.user
    for each row
execute procedure update_or_insert_user();


/*
 * при вставке комментария к комментарию автоматически заполняем post_id, а если он уже заполнен, то проверяем,
 * к одному ли и тому же посту относятся комментарии
 */
create or replace function comment_insert() returns trigger
as
$$
declare
    parent_post_id integer := null;
begin
    if new.reply_to_code = 'comment' then

        if new.reply_to_post_id is null then

            for parent_post_id in select reply_to_post_id
                                  from social_network.comment
                                  where comment_id = new.reply_to_comment_id
                loop
                    new.reply_to_post_id = parent_post_id;
                end loop;

        else
            for parent_post_id in select reply_to_post_id
                                  from social_network.comment
                                  where comment_id = new.reply_to_comment_id
                loop
                    if (parent_post_id != new.reply_to_post_id) then
                        raise exception 'id поста комментария и родительского комментрария не совпадают'
                            using hint = 'проверьте id поста, на который комментарий является ответом';
                    end if;
                end loop;
        end if;
    end if;
    return new;
end;
$$
    language plpgsql;

create trigger comment_insert
    before insert
    on social_network.comment
    for each row
execute procedure comment_insert();


/*
 * Следующие триггеры нужны, чтобы автоматически заполнять версию пользователя в таблицах, к которым отсылает пользователь
 */

/*
 * для post и message
 */
create or replace function auto_complete_from_dttm() returns trigger
as
$$
begin
    if new.author_valid_from is null then
        new.author_valid_from = get_current_valid_date_from(new.author_id);
    end if;
    return new;
end;
$$
    language plpgsql;

create trigger auto_user_date
    before insert
    on social_network.post
    for each row
execute procedure auto_complete_from_dttm();

create trigger auto_user_date
    before insert
    on social_network.comment
    for each row
execute procedure auto_complete_from_dttm();


/*
 * для liked_post
 */

create or replace function auto_complete_from_dttm_liked_posts() returns trigger
as
$$
begin
    if new.user_valid_from is null then
        new.user_valid_from = get_current_valid_date_from(new.user_id);
    end if;
    return new;
end;
$$
    language plpgsql;

create trigger auto_user_date
    before insert
    on social_network.liked_posts
    for each row
execute procedure auto_complete_from_dttm_liked_posts();

/*
 * для message
 */
create or replace function auto_complete_from_dttm_message() returns trigger
as
$$
begin
    if new.from_user_valid_from is null then
        new.from_user_valid_from = get_current_valid_date_from(new.from_id);
    end if;
    if new.to_user_valid_from is null then
        new.to_user_valid_from = get_current_valid_date_from(new.to_id);
    end if;
    return new;
end;
$$
    language plpgsql;

create trigger auto_user_date
    before insert
    on social_network.message
    for each row
execute procedure auto_complete_from_dttm_message();


/*
 * для subscription
 */
create or replace function auto_complete_from_dttm_subscription() returns trigger
as
$$
begin
    if new.to_who_valid_from is null then
        new.to_who_valid_from = get_current_valid_date_from(new.to_who_subscribed_id);
    end if;
    if new.who_valid_from is null then
        new.who_valid_from = get_current_valid_date_from(new.who_subscribed_id);
    end if;
    return new;
end;
$$
    language plpgsql;

create trigger auto_user_date
    before insert
    on social_network.subscription
    for each row
execute procedure auto_complete_from_dttm_subscription();

/*индексы*/

create index on social_network."user" (user_nm);
create index on social_network.attachment (path_to_file_txt);
create index on social_network.comment (comment_txt);
create index on social_network.message (message_txt);
create index on social_network.post (post_txt, author_id);

/*
 * INSERTS TO USERS
 */

/*нужно поменять адрес для считывания csv*/
set datestyle = 'DMY';
copy social_network.user
    from '/Users/anasedova/Downloads/users_data.csv' WITH CSV HEADER;

insert into social_network.user (user_id, user_nm, description_txt, path_to_photo_txt, valid_from_dttm, valid_to_dttm)
values (6, 'воробьева анна', 'студентка МФТИ', null, default, default);

insert into social_network.user (user_id, user_nm, description_txt, path_to_photo_txt, valid_from_dttm, valid_to_dttm)
values (8, 'Мещерякова Дарья', null, null, default, default),
       (9, 'Фролов Эрик', null, null, default, default),
       (10, 'Лобанов Артём', null, null, default, default);
/*
 * INSERTS TO POSTS
 */

insert into social_network.post (author_id, author_valid_from, post_txt)
values (1, null, 'Хотите узнать о том, как прошел мой день? Смотрите видео!'),
       (6, null, 'Только посмотрите на эти фотографии котика'),
       (7, null, 'Сегодня я приехал в мск, если кто-то хочет погулять, зовите'),
       (5, null, null);


/*
 * INSERTS TO COMMENTS
 */

insert into social_network.comment (author_id, author_valid_from, reply_to_code,
                                    reply_to_post_id, reply_to_comment_id, comment_txt)
values (2, null, 'post', 1, null, 'очень интересно!'),
       (3, null, 'comment', null, 1, 'отстой, а не видео'),
       (4, null, 'post', 2, null, 'какой красивый котик'),
       (5, null, 'comment', null, 3, 'котик-огонь!'),
       (2, null, 'comment', null, 3, 'да, но мой все равно красивее');

/*
 * INSERTS TO MESSAGES
 */

insert into social_network.message (from_id, to_id, from_user_valid_from, to_user_valid_from, message_txt, message_dttm)
values (1, 2, null, null, 'Привет) Как жизнь?', default),
       (2, 1, null, null, 'Привет) Хорошо', default),
       (2, 1, null, null, 'Чем занимаешься?', default),
       (1, 2, null, null, 'Доделываю домашнее задание', default),
       (2, 3, null, null, 'ща приду', default),
       (2, 3, null, null, null, default),
       (3, 2, null, null, 'петух', default),
       (3, 2, null, null, 'Прошу прощения если слишком токсично', default)


/*
* INSERTS TO LIKED_POSTS
*/
insert into social_network.liked_posts (post_id, user_id, user_valid_from)
values (3, 2, null),
       (2, 1, null),
       (2, 5, null),
       (2, 7, null),
       (3, 7, null),
       (1, 4, null);


/*
 * INSERTS TO ATTACHMENTS
 * пути к файлам являются выдуманными
 */
insert into social_network.attachment (attach_to_code, attach_to_post_id, attach_to_message_id,
                                       attachment_type_code, path_to_file_txt, attached_post_id)
values ('message', null, 1, 'photo', '/data/attachments/1736476.jpeg', null),
       ('post', 2, null, 'photo', '/data/attachments/8946787.jpeg', null),
       ('post', 4, null, 'post', null, 2),
       ('post', 2, null, 'photo', '/data/attachments/89489375.jpeg', null),
       ('message', null, 6, 'audio', '/data/attachments/4856785.mp3', null);

/*
 * INSERTS TO SUBSCRIPTIONS
 */
insert into social_network.subscription (who_subscribed_id, to_who_subscribed_id, who_valid_from, to_who_valid_from)
values (1, 3, null, null),
       (1, 4, null, null),
       (4, 5, null, null),
       (1, 5, null, null),
       (6, 5, null, null),
       (7, 5, null, null);

create schema social_network_views;

create view social_network_views.users as
select user_nm, description_txt, path_to_photo_txt
from social_network.user
where valid_to_dttm > now();

create view social_network_views.posts as
select user_nm, post_txt, post_dttm
from social_network.post
         inner join social_network.user
                    on (post.author_id = "user".user_id and "user".valid_to_dttm > now());

/*
 * отображаем список сообщений с именами отправителей и получителей, сортируем по дате сообщения
 */
create view social_network_views.message as
select from_nm, user_nm as to_nm, middle.message_txt, middle.message_dttm
from (select user_nm as from_nm, to_id, message_txt, message_dttm
      from social_network.user
               inner join social_network.message
                          on (message.from_id = "user".user_id and "user".valid_to_dttm > now())) as middle
         inner join
     social_network.user on (middle.to_id = "user".user_id and "user".valid_to_dttm > now())
order by middle.message_dttm;

create view social_network_views.attachments_to_posts as
select attach_to_post_id, attachment_type_code
from social_network.attachment
where attach_to_code = 'post';

create view social_network_views.attachments_to_messages as
select attach_to_post_id, attachment_type_code
from social_network.attachment
where attach_to_code = 'message';

create view social_network_views.comments as
select reply_to_post_id, comment_txt
from social_network.comment;

/*
 * Чтобы постчитать количество подписок/подписчиков, делаем groupby по who_subscribed_id/to_who_subscribed_id
 * и считаем количество. С помощью joinов с таблицей user оставляем имена, а не id.
 */
create view social_network_views.subscriptions_view as
select subscr.user_nm, subscribers_cnt, subscriptions_cnt
from (select to_who_subscribed_id as user_id, count(who_subscribed_id) as subscribers_cnt
      from social_network.subscription
      group by to_who_subscribed_id) as subscribers
         right join
     (select user_nm, user_id, subscriptions_cnt
      from (select who_subscribed_id, count(to_who_subscribed_id) as subscriptions_cnt
            from social_network.subscription
            group by who_subscribed_id) as subscriptions
               right join
           social_network.user on ("user".user_id = subscriptions.who_subscribed_id and "user".valid_to_dttm > now()))
         as subscr on (subscr.user_id = subscribers.user_id);

create view social_network_views.likes_cnt as
select post_id, count(user_id)
from social_network.liked_posts
group by post_id;

/*
 * информация о регистрации и о том, что изменилось
 */
create view social_network_views.registration_date as
select user_nm, names_cnt, descriptions_cnt, registration_dttm
from (select user_id, user_nm from social_network.user where valid_to_dttm > now()) as new_data
         inner join (select user_id,
                            count(user_nm)         as names_cnt,
                            count(description_txt) as descriptions_cnt,
                            min(valid_from_dttm)   as registration_dttm
                     from social_network.user
                     group by user_id) as old_data on new_data.user_id = old_data.user_id;

/*
 * Чтобы вывести список подписок по именам, выбираем действующие подписки и joinим их 2 раза с таблицей user
 * по who_subscribed_id и user_id и to_who_subscribed_id и user_id
 */
create view social_network_views.subscription as
select who_subscribed_nm, user_nm as to_who_subscribed_nm
from (select user_nm as who_subscribed_nm, to_who_subscribed_id
      from social_network.user
               inner join social_network.subscription
                          on (subscription.who_subscribed_id = "user".user_id and "user".valid_to_dttm > now() and
                              subscription.valid_to_dttm >= now())) as middle
         inner join
     social_network.user on (middle.to_who_subscribed_id = "user".user_id and "user".valid_to_dttm > now());

/*
 * 1 запрос - оценить, сколько пользователей приходило каждый год, и количество пользователей каждый год
 */

select user_id,
       date(registration_date),
       count(user_id)
       over (partition by extract(year from registration_date) order by date(registration_date)) as new_users_cnt,
       count(user_id) over (order by extract(year from registration_date))                       as users_cnt
from (select user_id, min(valid_from_dttm) as registration_date
      from social_network.user
      group by user_id) as registration_info;

/*
 * 2 запрос - давайте посмотрим на 'активные диалоги'
 (активными назовем диалоги, в которых общались сегодня, и посчитаем колоичество сообщений в каждом
 */
select from_nm, user_nm as to_nm, dialog_size, last_message_dttm
from social_network.user
         inner join
     (select user_nm as from_nm, to_id, dialog_size, last_message_dttm
      from (
            social_network.user
               inner join
           (select from_id, to_id, count(message_id) as dialog_size, max(message_dttm) as last_message_dttm
            from social_network.message
            group by from_id, to_id
            having date(max(message_dttm)) = date(now())
            order by max(message_dttm) desc) as message_data
           on (from_id = user_id and "user".valid_to_dttm > now()))) as with_from_name_data
     on (with_from_name_data.to_id =
         "user".user_id and "user".valid_to_dttm > now());

/*
 * 3 запрос - посчитаем среднее количество лайокв для поста автора и просто число лайков
 */

select author_id, author_nm, post_id, likes_cnt, avg(likes_cnt) over (partition by author_id)
from (select author_id, user_nm as author_nm, likes_cnt, post_id
      from social_network.user
               inner join
           (select author_id, liked_posts.post_id, count(user_id) as likes_cnt
            from social_network.liked_posts
                     inner join social_network.post on liked_posts.post_id = post.post_id
            group by liked_posts.post_id, author_id) as likes_data
           on (author_id = user_id and valid_to_dttm >= now())) as data_with_names;

/*
 * 4 запрос - посмотрим количество комментариев каждого пользователя к каждому посту за последние сутки
 */
select user_nm as author_nm, post_id, comments_cnt
from social_network."user"
         inner join
     (select author_id, reply_to_post_id as post_id, count(comment_id) as comments_cnt
      from social_network.comment
      where date(comment_dttm) = date(now())
      group by author_id, reply_to_post_id
      order by max(comment_dttm) desc) as data on (author_id = user_id and valid_to_dttm >= now());

/*
 * найдем людей с >= чем 3 подписками
 */

select user_nm, count(to_who_subscribed_id) as subscriptions_num
from social_network.user
         inner join social_network.subscription
                    on (subscription.who_subscribed_id = "user".user_id and "user".valid_to_dttm > now() and
                        subscription.valid_to_dttm >= now())
group by subscription.who_subscribed_id, user_nm
having count(to_who_subscribed_id) >= 3;


/*
 * Обычные запросы: 1) проверим, что forward message работает
 */

call forward_message(2, 1, 4);
call forward_message(1, 1, 4);

select from_id, to_id,  message_txt from social_network.message where message_txt = 'Привет) Как жизнь?'

/*
 * Проверим, что delete по посту действительно каскадный
 */
 delete from social_network.post where post_id=2;
select  comment_id from social_network.comment where reply_to_post_id=2;
select attachment_id from social_network.attachment where attach_to_post_id=2;