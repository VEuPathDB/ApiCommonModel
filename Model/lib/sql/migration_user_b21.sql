DELETE FROM userlogins5.categories;
DELETE FROM userlogins5.favorites;
DELETE FROM userlogins5.user_baskets;
DELETE FROM userlogins5.strategies;
DELETE FROM userlogins5.steps;
DELETE FROM userlogins5.dataset_values;
DELETE FROM userlogins5.datasets;
DELETE FROM userlogins5.preferences;
DELETE FROM userlogins5.user_roles;
DELETE FROM userlogins5.users;
DELETE FROM userlogins5.config;

INSERT INTO userlogins5.users 
      (user_id, email, passwd, is_guest, signature, register_time, last_active, last_name, first_name, middle_name,
       title, organization, department, address, city, state, zip_code, phone_number, country, PREV_USER_ID, migration_id)
SELECT user_id, email, passwd, is_guest, signature, register_time, last_active, last_name, first_name, middle_name,
       title, organization, department, address, city, state, zip_code, phone_number, country, PREV_USER_ID, migration_id
FROM userlogins4.users
WHERE is_guest = 0;

INSERT INTO userlogins5.user_roles (user_id, user_role, migration_id)
SELECT user_id, user_role, migration_id 
FROM userlogins4.user_roles
WHERE user_id IN (SELECT user_id FROM userlogins5.users);

INSERT INTO userlogins5.preferences 
      (user_id, project_id, preference_name, preference_value, migration_id)
SELECT p.user_id, project_id, preference_name, preference_value, p.migration_id
FROM userlogins4.preferences p, userlogins5.users u
WHERE p.user_id = u.user_id;

-- the display_params will need to be repacked.
INSERT INTO userlogins5.steps 
      (step_id, user_id, left_child_id, right_child_id, create_time, last_run_time, estimate_size, answer_filter,
       custom_name, is_deleted, is_valid, collapsed_name, is_collapsible, assigned_weight, project_id, project_version, question_name,
       strategy_id, display_params, result_message, prev_step_id, migration_id)
SELECT step_id, s.user_id, left_child_id, right_child_id, create_time, last_run_time, estimate_size, answer_filter,
       custom_name, is_deleted, is_valid, collapsed_name, is_collapsible, assigned_weight, project_id, project_version, question_name,
       strategy_id, display_params, result_message, prev_step_id, s.migration_id
FROM userlogins4.steps s, userlogins5.users u
WHERE s.user_id = u.user_id;

INSERT INTO userlogins5.strategies
      (strategy_id, user_id, root_step_id, project_id, version, is_saved, create_time, last_view_time, last_modify_time, description,
       signature, name, saved_name, is_deleted, is_public, prev_strategy_id, migration_id)
SELECT strategy_id, s.user_id, root_step_id, project_id, version, is_saved, create_time, last_view_time, last_modify_time, description,
       s.signature, name, saved_name, is_deleted, is_public, prev_strategy_id, s.migration_id
FROM userlogins4.strategies s, userlogins5.users u
WHERE s.user_id = u.user_id
  AND s.is_deleted = 0;

-- the content checksum will need to be recomputed, and content will need to be generated in this pass
INSERT INTO userlogins5.datasets 
      (dataset_id, user_id, dataset_name, dataset_size, content_checksum, created_time, 
       upload_file, parser, category_id, content, prev_dataset_id, migration_id)
SELECT ud.user_dataset_id AS dataset_id, ud.user_id, 'dataset#' || ud.user_dataset_id AS dataset_name, di.dataset_size, 
       'stub'|| ud.user_dataset_id AS content_checksum, ud.create_time AS created_time, 
       ud.upload_file, 'list' AS parser, null AS category_id, null AS content, ud.prev_user_dataset_id AS prev_dataset_id, ud.migration_id
FROM userlogins4.user_datasets2 ud, wdkengine.dataset_indices di, userlogins5.users u
WHERE ud.user_id = u.user_id 
  AND ud.dataset_id = di.dataset_id;

INSERT INTO userlogins5.dataset_values (dataset_value_id, dataset_id, data1, data2, data3, prev_dataset_value_id, migration_id)
SELECT userlogins5.dataset_values_pkseq.nextval AS dataset_value_id, d.dataset_id,
       dv.pk_column_1 AS data1, dv.pk_column_2 AS data2, dv.pk_column_2 AS data3, null AS prev_dataset_value_id, dv.migration_id
FROM userlogins5.datasets d, userlogins4.user_datasets2 ud, wdkengine.dataset_values dv
WHERE d.dataset_id= ud.user_dataset_id 
  AND ud.dataset_id = dv.dataset_id
  AND dv.pk_column_1 IS NOT NULL;
  
INSERT INTO userlogins5.user_baskets
      (basket_id, user_id, basket_name, project_id, record_class, is_default, category_id, 
       pk_column_1, pk_column_2, pk_column_3, prev_basket_id, migration_id)
SELECT basket_id, b.user_id, null AS basket_name, project_id, record_class, null AS is_default, null AS category_id, 
       pk_column_1, pk_column_2, pk_column_3, null AS prev_basket_id, null AS migration_id
FROM userlogins4.user_baskets b, userlogins5.users u
WHERE b.user_id = u.user_id;
  
INSERT INTO userlogins5.favorites
      (favorite_id, user_id, project_id, record_class, pk_column_1, pk_column_2, pk_column_3, 
       record_note, record_group, prev_favorite_id, migration_id)
SELECT favorite_id, f.user_id, project_id, record_class, pk_column_1, pk_column_2, pk_column_3, 
       record_note, record_group, null AS prev_favorite_id, null AS migration_id
FROM userlogins4.favorites f, userlogins5.users u
WHERE f.user_id = u.user_id;