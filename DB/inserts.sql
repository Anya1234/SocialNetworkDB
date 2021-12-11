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
