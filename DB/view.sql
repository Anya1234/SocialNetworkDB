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