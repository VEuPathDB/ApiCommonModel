DELETE FROM userlogins5.CommentStableId;
DELETE FROM userlogins5.CommentFile;
DELETE FROM userlogins5.CommentSequence;
DELETE FROM userlogins5.CommentReference;
DELETE FROM userlogins5.CommentTargetCategory;
DELETE FROM userlogins5.TargetCategory;
DELETE FROM userlogins5.comment_external_database;
DELETE FROM userlogins5.locations;
DELETE FROM userlogins5.external_databases;
DELETE FROM userlogins5.comments;
DELETE FROM userlogins5.review_status;
DELETE FROM userlogins5.comment_target;


INSERT INTO userlogins5.comment_target (comment_target_id, comment_target_name, require_location)
SELECT comment_target_id, comment_target_name, require_location 
FROM comments2.comment_target;


INSERT INTO userlogins5.review_status (review_status_id, review_status_name)
SELECT review_status_id, review_status_name
FROM comments2.review_status;


INSERT INTO userlogins5.comments (comment_id, prev_comment_id, prev_schema, user_id, email, comment_date, comment_target_id, stable_id, conceptual,
       project_name, project_version, headline, review_status_id, accepted_version, location_string, content, organism, is_visible)
SELECT comment_id, prev_comment_id, prev_schema, user_id, email, comment_date, comment_target_id, stable_id, conceptual, 
       project_name, project_version, headline, review_status_id, accepted_version, location_string, content, organism, is_visible
FROM comments2.comments;


INSERT INTO userlogins5.external_databases (external_database_id, external_database_name, external_database_version, prev_schema, prev_external_database_id)
SELECT external_database_id, external_database_name, external_database_version, prev_schema, prev_external_database_id
FROM comments2.external_databases;


INSERT INTO userlogins5.locations (comment_id, location_id, location_start, location_end, coordinate_type, is_reverse, prev_comment_id, prev_schema)
SELECT comment_id, location_id, location_start, location_end, coordinate_type, is_reverse, prev_comment_id, prev_schema
FROM comments2.locations;


INSERT INTO userlogins5.comment_external_database (external_database_id, comment_id)
SELECT external_database_id, comment_id
FROM comments2.comment_external_database;


INSERT INTO userlogins5.TargetCategory (target_category_id, category, comment_target_id)
SELECT target_category_id, category, comment_target_id
FROM comments2.TargetCategory;


INSERT INTO userlogins5.CommentTargetCategory (comment_target_category_id, comment_id, target_category_id)
SELECT comment_target_category_id, comment_id, target_category_id
FROM comments2.CommentTargetCategory;


INSERT INTO userlogins5.CommentReference (comment_reference_id, source_id, database_name, comment_id)
SELECT comment_reference_id, source_id, database_name, comment_id
FROM comments2.CommentReference;


INSERT INTO userlogins5.CommentSequence (comment_sequence_id, sequence, comment_id)
SELECT comment_sequence_id, sequence, comment_id
FROM comments2.CommentSequence;


INSERT INTO userlogins5.CommentFile (file_id, name, notes, comment_id)
SELECT file_id, name, notes, comment_id
FROM comments2.CommentFile;


INSERT INTO userlogins5.CommentStableId (comment_stable_id, stable_id, comment_id)
SELECT comment_stable_id, stable_id, comment_id
FROM comments2.CommentStableId;
