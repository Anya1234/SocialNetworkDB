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
select user_nm as author_nm, post_id, comments_cnt from
social_network."user" inner join
(select author_id, reply_to_post_id as post_id, count(comment_id) as comments_cnt
from social_network.comment
where date(comment_dttm) = date(now())
group by author_id, reply_to_post_id
order by max(comment_dttm) desc) as data on (author_id = user_id and valid_to_dttm >= now());

/*
 * найдем людей с >= чем 3 подписками
 */

select user_nm , count(to_who_subscribed_id) as subscriptions_num
      from social_network.user
               inner join social_network.subscription
                          on (subscription.who_subscribed_id = "user".user_id and "user".valid_to_dttm > now() and
                              subscription.valid_to_dttm >= now())
group by subscription.who_subscribed_id, user_nm having count(to_who_subscribed_id) >=3