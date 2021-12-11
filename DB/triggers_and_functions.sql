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
 * Проверим, что работает
 */
call forward_message(2, 1, 4);
call forward_message(1, 1, 4);

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

