create index on social_network."user" (user_nm);
create index on social_network.attachment (path_to_file_txt);
create index on social_network.comment(comment_txt);
create index on social_network.message(message_txt);
create index on social_network.post(post_txt, author_id);
