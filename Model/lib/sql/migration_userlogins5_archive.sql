ALTER TABLE userlogins5_archive.categories DISABLE CONSTRAINT "categories_fk01";
ALTER TABLE userlogins5_archive.categories DISABLE CONSTRAINT "categories_fk01";
ALTER TABLE userlogins5_archive.categories DISABLE CONSTRAINT "categories_fk01";
ALTER TABLE userlogins5_archive.categories DISABLE CONSTRAINT "categories_fk01";
ALTER TABLE userlogins5_archive.steps DISABLE CONSTRAINT "steps_fk01";
ALTER TABLE userlogins5_archive.strategies DISABLE CONSTRAINT "strategies_fk02";
ALTER TABLE userlogins5_archive.datasets DISABLE CONSTRAINT "datasets_fk01";
ALTER TABLE userlogins5_archive.user_baskets DISABLE CONSTRAINT "user_baskets_fk01";
ALTER TABLE userlogins5_archive.favorites DISABLE CONSTRAINT "favorites_fk01";
ALTER TABLE userlogins5_archive.preferences DISABLE CONSTRAINT "preferences_fk01";
ALTER TABLE userlogins5_archive.user_roles DISABLE CONSTRAINT "user_roles_fk01";


TRUNCATE TABLE userlogins5_archive.categories;
TRUNCATE TABLE userlogins5_archive.config;
TRUNCATE TABLE userlogins5_archive.steps;
TRUNCATE TABLE userlogins5_archive.strategies;
TRUNCATE TABLE userlogins5_archive.dataset_values;
TRUNCATE TABLE userlogins5_archive.datasets;
TRUNCATE TABLE userlogins5_archive.user_baskets;
TRUNCATE TABLE userlogins5_archive.favorites;
TRUNCATE TABLE userlogins5_archive.preferences;
TRUNCATE TABLE userlogins5_archive.user_roles;
TRUNCATE TABLE userlogins5_archive.users;


ALTER TABLE userlogins5_archive.categories ENABLE CONSTRAINT "categories_fk01";
ALTER TABLE userlogins5_archive.categories ENABLE CONSTRAINT "categories_fk01";
ALTER TABLE userlogins5_archive.categories ENABLE CONSTRAINT "categories_fk01";
ALTER TABLE userlogins5_archive.categories ENABLE CONSTRAINT "categories_fk01";
ALTER TABLE userlogins5_archive.steps ENABLE CONSTRAINT "steps_fk01";
ALTER TABLE userlogins5_archive.strategies ENABLE CONSTRAINT "strategies_fk02";
ALTER TABLE userlogins5_archive.datasets ENABLE CONSTRAINT "datasets_fk01";
ALTER TABLE userlogins5_archive.user_baskets ENABLE CONSTRAINT "user_baskets_fk01";
ALTER TABLE userlogins5_archive.favorites ENABLE CONSTRAINT "favorites_fk01";
ALTER TABLE userlogins5_archive.preferences ENABLE CONSTRAINT "preferences_fk01";
ALTER TABLE userlogins5_archive.user_roles ENABLE CONSTRAINT "user_roles_fk01";


---------------- config ------------------
INSERT INTO userlogins5_archive.config (config_name, config_value)
SELECT config_name, config_value FROM userlogins5.config;

---------------- users ------------------
DROP TABLE users5;
DROP TABLE users4;
DROP TABLE users3;
DROP TABLE users3_archive;
DROP TABLE users3_archive_south;

CREATE TABLE users5 AS 
SELECT user_id FROM userlogins5.users 
WHERE is_guest = 0 OR user_id IN (SELECT user_id FROM userlogins5.steps);

ALTER TABLE users5 ADD CONSTRAINT user5_pk PRIMARY KEY(user_id);


CREATE TABLE users4 AS 
SELECT user_id FROM userlogins4.users 
WHERE user_id NOT IN (SELECT user_id FROM users5)
  AND (is_guest = 0 OR user_id IN (SELECT user_id FROM userlogins4.steps));

ALTER TABLE users4 ADD CONSTRAINT user4_pk PRIMARY KEY(user_id);


CREATE TABLE users3 AS 
SELECT user_id FROM userlogins3.users 
WHERE user_id NOT IN (SELECT user_id FROM users5 
                      UNION 
                      SELECT user_id FROM users4)
  AND (is_guest = 0 OR user_id IN (SELECT user_id FROM userlogins3.steps));

ALTER TABLE users3 ADD CONSTRAINT user3_pk PRIMARY KEY(user_id);


CREATE TABLE users3_archive AS 
SELECT user_id FROM userlogins3_archive.users 
WHERE user_id NOT IN (SELECT user_id FROM users5 
                      UNION 
                      SELECT user_id FROM users4
                      UNION
                      SELECT user_id FROM users3)
  AND (is_guest = 0 OR user_id IN (SELECT user_id FROM userlogins3_archive.steps));

ALTER TABLE users3_archive ADD CONSTRAINT user3_archive_pk PRIMARY KEY(user_id);


CREATE TABLE users3_archive_south AS 
SELECT user_id FROM userlogins3_archive_south.users 
WHERE user_id NOT IN (SELECT user_id FROM users5 
                      UNION 
                      SELECT user_id FROM users4
                      UNION
                      SELECT user_id FROM users3
                      UNION
                      SELECT user_id FROM users3_archive)
  AND (is_guest = 0 OR user_id IN (SELECT user_id FROM userlogins3_archive_south.steps));

ALTER TABLE users3_archive_south ADD CONSTRAINT users3_archive_south_pk PRIMARY KEY(user_id);


INSERT INTO userlogins5_archive.users 
      (USER_ID, EMAIL, PASSWD, IS_GUEST, SIGNATURE, REGISTER_TIME, LAST_ACTIVE, LAST_NAME, FIRST_NAME, MIDDLE_NAME, TITLE,
       ORGANIZATION, DEPARTMENT, ADDRESS, CITY, STATE, ZIP_CODE, PHONE_NUMBER, COUNTRY, PREV_USER_ID)
SELECT USER_ID, EMAIL, PASSWD, IS_GUEST, SIGNATURE, REGISTER_TIME, LAST_ACTIVE, LAST_NAME, FIRST_NAME, MIDDLE_NAME, TITLE,
       ORGANIZATION, DEPARTMENT, ADDRESS, CITY, STATE, ZIP_CODE, PHONE_NUMBER, COUNTRY, PREV_USER_ID
FROM userlogins5.users WHERE user_id IN (SELECT user_id FROM users5);

INSERT INTO userlogins5_archive.users 
      (USER_ID, EMAIL, PASSWD, IS_GUEST, SIGNATURE, REGISTER_TIME, LAST_ACTIVE, LAST_NAME, FIRST_NAME, MIDDLE_NAME, TITLE,
       ORGANIZATION, DEPARTMENT, ADDRESS, CITY, STATE, ZIP_CODE, PHONE_NUMBER, COUNTRY, PREV_USER_ID)
SELECT USER_ID, EMAIL, PASSWD, IS_GUEST, SIGNATURE, REGISTER_TIME, LAST_ACTIVE, LAST_NAME, FIRST_NAME, MIDDLE_NAME, TITLE,
       ORGANIZATION, DEPARTMENT, ADDRESS, CITY, STATE, ZIP_CODE, PHONE_NUMBER, COUNTRY, PREV_USER_ID
FROM userlogins4.users WHERE user_id IN (SELECT user_id FROM users4);

INSERT INTO userlogins5_archive.users 
      (USER_ID, EMAIL, PASSWD, IS_GUEST, SIGNATURE, REGISTER_TIME, LAST_ACTIVE, LAST_NAME, FIRST_NAME, MIDDLE_NAME, TITLE,
       ORGANIZATION, DEPARTMENT, ADDRESS, CITY, STATE, ZIP_CODE, PHONE_NUMBER, COUNTRY, PREV_USER_ID)
SELECT USER_ID, EMAIL, PASSWD, IS_GUEST, SIGNATURE, REGISTER_TIME, LAST_ACTIVE, LAST_NAME, FIRST_NAME, MIDDLE_NAME, TITLE,
       ORGANIZATION, DEPARTMENT, ADDRESS, CITY, STATE, ZIP_CODE, PHONE_NUMBER, COUNTRY, PREV_USER_ID
FROM userlogins3.users WHERE user_id IN (SELECT user_id FROM users3);

INSERT INTO userlogins5_archive.users 
      (USER_ID, EMAIL, PASSWD, IS_GUEST, SIGNATURE, REGISTER_TIME, LAST_ACTIVE, LAST_NAME, FIRST_NAME, MIDDLE_NAME, TITLE,
       ORGANIZATION, DEPARTMENT, ADDRESS, CITY, STATE, ZIP_CODE, PHONE_NUMBER, COUNTRY, PREV_USER_ID)
SELECT USER_ID, EMAIL, PASSWD, IS_GUEST, SIGNATURE, REGISTER_TIME, LAST_ACTIVE, LAST_NAME, FIRST_NAME, MIDDLE_NAME, TITLE,
       ORGANIZATION, DEPARTMENT, ADDRESS, CITY, STATE, ZIP_CODE, PHONE_NUMBER, COUNTRY, PREV_USER_ID
FROM userlogins3_archive.users WHERE user_id IN (SELECT user_id FROM users3_archive);

INSERT INTO userlogins5_archive.users 
      (USER_ID, EMAIL, PASSWD, IS_GUEST, SIGNATURE, REGISTER_TIME, LAST_ACTIVE, LAST_NAME, FIRST_NAME, MIDDLE_NAME, TITLE,
       ORGANIZATION, DEPARTMENT, ADDRESS, CITY, STATE, ZIP_CODE, PHONE_NUMBER, COUNTRY, PREV_USER_ID)
SELECT USER_ID, EMAIL, PASSWD, IS_GUEST, SIGNATURE, REGISTER_TIME, LAST_ACTIVE, LAST_NAME, FIRST_NAME, MIDDLE_NAME, TITLE,
       ORGANIZATION, DEPARTMENT, ADDRESS, CITY, STATE, ZIP_CODE, PHONE_NUMBER, COUNTRY, PREV_USER_ID
FROM userlogins3_archive_south.users 
WHERE user_id NOT IN (SELECT user_id FROM userlogins5_archive.users)
  AND (is_guest = 0 OR user_id IN (SELECT user_id FROM userlogins3_archive_south.steps));


---------------- user roles --------------------
INSERT INTO userlogins5_archive.user_roles (USER_ID, USER_ROLE)
SELECT r.USER_ID, r.USER_ROLE 
FROM userlogins5.user_roles r, users5 u WHERE r.user_id = u.user_id;

INSERT INTO userlogins5_archive.user_roles (USER_ID, USER_ROLE)
SELECT r.USER_ID, r.USER_ROLE 
FROM userlogins4.user_roles r, users4 u WHERE r.user_id = u.user_id;

INSERT INTO userlogins5_archive.user_roles (USER_ID, USER_ROLE)
SELECT r.USER_ID, r.USER_ROLE 
FROM userlogins3.user_roles r, users3 u WHERE r.user_id = u.user_id;

INSERT INTO userlogins5_archive.user_roles (USER_ID, USER_ROLE)
SELECT r.USER_ID, r.USER_ROLE 
FROM userlogins3_archive.user_roles r, users3_archive u WHERE r.user_id = u.user_id;

INSERT INTO userlogins5_archive.user_roles (USER_ID, USER_ROLE)
SELECT r.USER_ID, r.USER_ROLE 
FROM userlogins3_archive_south.user_roles r, users3_archive_south u WHERE r.user_id = u.user_id;


------------- user preferences --------------
INSERT INTO userlogins5_archive.preferences (user_id, project_id, preference_name, preference_value)
SELECT p.user_id, project_id, preference_name, preference_value
FROM userlogins5.preferences p, users5 u WHERE p.user_id = u.user_id;

INSERT INTO userlogins5_archive.preferences (user_id, project_id, preference_name, preference_value)
SELECT p.user_id, project_id, preference_name, preference_value
FROM userlogins4.preferences p, users4 u WHERE p.user_id = u.user_id;

INSERT INTO userlogins5_archive.preferences (user_id, project_id, preference_name, preference_value)
SELECT p.user_id, project_id, preference_name, preference_value
FROM userlogins3.preferences p, users3 u WHERE p.user_id = u.user_id;

INSERT INTO userlogins5_archive.preferences (user_id, project_id, preference_name, preference_value)
SELECT p.user_id, project_id, preference_name, preference_value
FROM userlogins3_archive.preferences p, users3_archive u WHERE p.user_id = u.user_id;

INSERT INTO userlogins5_archive.preferences (user_id, project_id, preference_name, preference_value)
SELECT p.user_id, project_id, preference_name, preference_value
FROM userlogins3_archive_south.preferences p, users3_archive_south u WHERE p.user_id = u.user_id;


---------------------- user favorites -----------------------
INSERT INTO userlogins5_archive.favorites 
      (favorite_id, user_id, project_id, record_class, pk_column_1, pk_column_2, pk_column_3, record_note, record_group)
SELECT favorite_id, f.user_id, project_id, record_class, pk_column_1, pk_column_2, pk_column_3, record_note, record_group
FROM userlogins5.favorites f, users5 u WHERE f.user_id = u.user_id;

INSERT INTO userlogins5_archive.favorites 
      (favorite_id, user_id, project_id, record_class, pk_column_1, pk_column_2, pk_column_3, record_note, record_group)
SELECT favorite_id, f.user_id, project_id, record_class, pk_column_1, pk_column_2, pk_column_3, record_note, record_group
FROM userlogins4.favorites f, users4 u WHERE f.user_id = u.user_id;

INSERT INTO userlogins5_archive.favorites 
      (favorite_id, user_id, project_id, record_class, pk_column_1, pk_column_2, pk_column_3, record_note, record_group)
SELECT (SELECT max(favorite_id) FROM userlogins5_archive.favorites) + rownum AS favorite_id, f.user_id, project_id, 
       record_class, pk_column_1, pk_column_2, pk_column_3, record_note, record_group
FROM userlogins3.favorites f, users3 u WHERE f.user_id = u.user_id;

INSERT INTO userlogins5_archive.favorites 
      (favorite_id, user_id, project_id, record_class, pk_column_1, pk_column_2, pk_column_3, record_note, record_group)
SELECT (SELECT max(favorite_id) FROM userlogins5_archive.favorites) + rownum AS favorite_id, f.user_id, project_id, 
       record_class, pk_column_1, pk_column_2, pk_column_3, record_note, record_group
FROM userlogins3_archive.favorites f, users3_archive u WHERE f.user_id = u.user_id;

INSERT INTO userlogins5_archive.favorites 
      (favorite_id, user_id, project_id, record_class, pk_column_1, pk_column_2, pk_column_3, record_note, record_group)
SELECT (SELECT max(favorite_id) FROM userlogins5_archive.favorites) + rownum AS favorite_id, f.user_id, project_id, 
       record_class, pk_column_1, pk_column_2, pk_column_3, record_note, record_group
FROM userlogins3_archive_south.favorites f, users3_archive_south u WHERE f.user_id = u.user_id;


----------- user basekets ----------------------
INSERT INTO userlogins5_archive.user_baskets 
      (basket_id, user_id, project_id, record_class, pk_column_1, pk_column_2, pk_column_3)
SELECT basket_id, b.user_id, project_id, record_class, pk_column_1, pk_column_2, pk_column_3
FROM userlogins5.user_baskets b, users5 u WHERE b.user_id = u.user_id;

INSERT INTO userlogins5_archive.user_baskets 
      (basket_id, user_id, project_id, record_class, pk_column_1, pk_column_2, pk_column_3)
SELECT basket_id, b.user_id, project_id, record_class, pk_column_1, pk_column_2, pk_column_3
FROM userlogins4.user_baskets b, users4 u WHERE b.user_id = u.user_id;

INSERT INTO userlogins5_archive.user_baskets 
      (basket_id, user_id, project_id, record_class, pk_column_1, pk_column_2, pk_column_3)
SELECT (SELECT max(basket_id) FROM userlogins5_archive.user_baskets) + rownum AS basket_id, b.user_id, project_id, 
       record_class, pk_column_1, pk_column_2, pk_column_3
FROM userlogins3.user_baskets b, users3 u WHERE b.user_id = u.user_id;

INSERT INTO userlogins5_archive.user_baskets 
      (basket_id, user_id, project_id, record_class, pk_column_1, pk_column_2, pk_column_3)
SELECT (SELECT max(basket_id) FROM userlogins5_archive.user_baskets) + rownum AS basket_id, b.user_id, project_id, 
       record_class, pk_column_1, pk_column_2, pk_column_3
FROM userlogins3_archive.user_baskets b, users3_archive u WHERE b.user_id = u.user_id;

INSERT INTO userlogins5_archive.user_baskets 
      (basket_id, user_id, project_id, record_class, pk_column_1, pk_column_2, pk_column_3)
SELECT (SELECT max(basket_id) FROM userlogins5_archive.user_baskets) + rownum AS basket_id, b.user_id, project_id, 
       record_class, pk_column_1, pk_column_2, pk_column_3
FROM userlogins3_archive_south.user_baskets b, users3_archive_south u WHERE b.user_id = u.user_id;


------------- datasets ---------------
INSERT INTO userlogins5_archive.datasets
      (DATASET_ID, USER_ID, DATASET_NAME, DATASET_SIZE, CONTENT_CHECKSUM, CREATED_TIME, UPLOAD_FILE, PARSER,
       CATEGORY_ID, CONTENT, PREV_DATASET_ID)
SELECT DATASET_ID, USER_ID, DATASET_NAME, DATASET_SIZE, CONTENT_CHECKSUM, CREATED_TIME, UPLOAD_FILE, PARSER,
       CATEGORY_ID, CONTENT, PREV_DATASET_ID
FROM userlogins5.datasets WHERE user_id IN (SELECT user_id FROM users5);

INSERT INTO userlogins5_archive.datasets
      (DATASET_ID, USER_ID, DATASET_NAME, DATASET_SIZE, CONTENT_CHECKSUM, CREATED_TIME, UPLOAD_FILE, PARSER,
       CATEGORY_ID, CONTENT, PREV_DATASET_ID)
SELECT DISTINCT ud.user_dataset_id AS dataset_id, ud.user_id, 'dataset#' || ud.user_dataset_id AS dataset_name, 
       di.dataset_size, 'stub'|| ud.user_dataset_id AS content_checksum, ud.create_time AS created_time, 
       ud.upload_file, 'list' AS parser, 0 AS category_id, 'stub' AS content, ud.prev_user_dataset_id AS prev_dataset_id 
FROM userlogins4.user_datasets2 ud, wdkengine.dataset_indices di, users4 u, userlogins4.steps s
WHERE ud.user_id = u.user_id  AND ud.dataset_id = di.dataset_id
  AND ud.user_dataset_id NOT IN (SELECT dataset_id FROM userlogins5_archive.datasets)
  AND u.user_id = s.user_id AND instr(s.display_params, '"' || ud.user_dataset_id || '"') > 0;

INSERT INTO userlogins5_archive.datasets
      (DATASET_ID, USER_ID, DATASET_NAME, DATASET_SIZE, CONTENT_CHECKSUM, CREATED_TIME, UPLOAD_FILE, PARSER,
       CATEGORY_ID, CONTENT, PREV_DATASET_ID)
SELECT DISTINCT ud.user_dataset_id AS dataset_id, ud.user_id, 'dataset#' || ud.user_dataset_id AS dataset_name, 
       di.dataset_size, 'stub'|| ud.user_dataset_id AS content_checksum, ud.create_time AS created_time, 
       ud.upload_file, 'list' AS parser, 0 AS category_id, 'stub' AS content, ud.prev_user_dataset_id AS prev_dataset_id 
FROM userlogins3.user_datasets2 ud, wdkengine.dataset_indices di, users3 u, userlogins3.steps s
WHERE ud.user_id = u.user_id  AND ud.dataset_id = di.dataset_id
  AND ud.user_dataset_id NOT IN (SELECT dataset_id FROM userlogins5_archive.datasets)
  AND u.user_id = s.user_id AND instr(s.display_params, '"' || ud.user_dataset_id || '"') > 0;


INSERT INTO userlogins5_archive.datasets
      (DATASET_ID, USER_ID, DATASET_NAME, DATASET_SIZE, CONTENT_CHECKSUM, CREATED_TIME, UPLOAD_FILE, PARSER,
       CATEGORY_ID, CONTENT, PREV_DATASET_ID)
SELECT DISTINCT ud.user_dataset_id AS dataset_id, ud.user_id, 'dataset#' || ud.user_dataset_id AS dataset_name, 
       di.dataset_size, 'stub'|| ud.user_dataset_id AS content_checksum, ud.create_time AS created_time, 
       ud.upload_file, 'list' AS parser, 0 AS category_id, 'stub' AS content, ud.prev_user_dataset_id AS prev_dataset_id 
FROM userlogins3_archive.user_datasets2 ud, userlogins3_archive.dataset_indices di, users3 u, userlogins3_archive.steps s
WHERE ud.user_id = u.user_id  AND ud.dataset_id = di.dataset_id
  AND ud.user_dataset_id NOT IN (SELECT dataset_id FROM userlogins5_archive.datasets)
  AND u.user_id = s.user_id AND instr(s.display_params, '"' || ud.user_dataset_id || '"') > 0;


INSERT INTO userlogins5_archive.datasets
      (DATASET_ID, USER_ID, DATASET_NAME, DATASET_SIZE, CONTENT_CHECKSUM, CREATED_TIME, UPLOAD_FILE, PARSER,
       CATEGORY_ID, CONTENT, PREV_DATASET_ID)
SELECT DISTINCT ud.user_dataset_id AS dataset_id, ud.user_id, 'dataset#' || ud.user_dataset_id AS dataset_name, 
       di.dataset_size, 'stub'|| ud.user_dataset_id AS content_checksum, ud.create_time AS created_time, 
       ud.upload_file, 'list' AS parser, 0 AS category_id, 'stub' AS content, ud.prev_user_dataset_id AS prev_dataset_id 
FROM userlogins3_archive_south.user_datasets2 ud, userlogins3_archive_south.dataset_indices di, users3 u, userlogins3_archive_south.steps s
WHERE ud.user_id = u.user_id  AND ud.dataset_id = di.dataset_id
  AND ud.user_dataset_id NOT IN (SELECT dataset_id FROM userlogins5_archive.datasets)
  AND u.user_id = s.user_id AND instr(s.display_params, '"' || ud.user_dataset_id || '"') > 0;
  
  
---------- dataset values ------------
INSERT INTO userlogins5_archive.dataset_values (dataset_value_id, dataset_id, data1, data2, data3)
    SELECT dv.dataset_value_id, d.dataset_id, dv.data1, dv.data2, dv.data3
    FROM userlogins5.dataset_values dv, userlogins5.datasets d, users5 u
    WHERE d.dataset_id= u.user_id AND dv.dataset_id = d.dataset_id;


INSERT INTO userlogins5_archive.dataset_values (dataset_value_id, dataset_id, data1, data2, data3)
    SELECT (SELECT max(dataset_value_id) FROM userlogins5_archive.dataset_values) + rownum AS dataset_value_id, 
           dataset_id, data1, data2, data3
    FROM (SELECT DISTINCT ud.user_dataset_id AS dataset_id, dv.pk_column_1 AS data1, dv.pk_column_2 AS data2, dv.pk_column_2 AS data3
          FROM userlogins4.user_datasets2 ud, wdkengine.dataset_values dv, 
               userlogins5_archive.datasets d, users4 u
          WHERE d.dataset_id= ud.user_dataset_id AND ud.dataset_id = dv.dataset_id
            AND ud.user_id = u.user_id AND dv.pk_column_1 IS NOT NULL
            AND ud.user_dataset_id NOT IN (SELECT dataset_id FROM userlogins5_archive.dataset_values));


INSERT INTO userlogins5_archive.dataset_values (dataset_value_id, dataset_id, data1, data2, data3)
    SELECT (SELECT max(dataset_value_id) FROM userlogins5_archive.dataset_values) + rownum AS dataset_value_id, 
           dataset_id, data1, data2, data3
    FROM (SELECT DISTINCT ud.user_dataset_id AS dataset_id, dv.pk_column_1 AS data1, dv.pk_column_2 AS data2, dv.pk_column_2 AS data3
          FROM userlogins3.user_datasets2 ud, wdkengine.dataset_values dv, 
               userlogins5_archive.datasets d, users3 u
          WHERE d.dataset_id= ud.user_dataset_id AND ud.dataset_id = dv.dataset_id
            AND ud.user_id = u.user_id AND dv.pk_column_1 IS NOT NULL
            AND ud.user_dataset_id NOT IN (SELECT dataset_id FROM userlogins5_archive.dataset_values));

-- to run
INSERT INTO userlogins5_archive.dataset_values (dataset_value_id, dataset_id, data1, data2, data3)
    SELECT (SELECT max(dataset_value_id) FROM userlogins5_archive.dataset_values) + rownum AS dataset_value_id, 
           dataset_id, data1, data2, data3
    FROM (SELECT DISTINCT ud.user_dataset_id AS dataset_id, dv.pk_column_1 AS data1, dv.pk_column_2 AS data2, dv.pk_column_2 AS data3
          FROM userlogins3_archive.user_datasets2 ud, userlogins3_archive.dataset_values dv, 
               userlogins5_archive.datasets d, users3_archive u
          WHERE d.dataset_id= ud.user_dataset_id AND ud.dataset_id = dv.dataset_id
            AND ud.user_id = u.user_id AND dv.pk_column_1 IS NOT NULL
            AND ud.user_dataset_id NOT IN (SELECT dataset_id FROM userlogins5_archive.dataset_values));      

-- to run
INSERT INTO userlogins5_archive.dataset_values (dataset_value_id, dataset_id, data1, data2, data3)
    SELECT (SELECT max(dataset_value_id) FROM userlogins5_archive.dataset_values) + rownum AS dataset_value_id, 
           dataset_id, data1, data2, data3
    FROM (SELECT DISTINCT ud.user_dataset_id AS dataset_id, dv.pk_column_1 AS data1, dv.pk_column_2 AS data2, dv.pk_column_2 AS data3
          FROM userlogins3_archive_south.user_datasets2 ud, userlogins3_archive_south.dataset_values dv, 
               userlogins5_archive.datasets d, users3_archive_south u
          WHERE d.dataset_id= ud.user_dataset_id AND ud.dataset_id = dv.dataset_id
            AND ud.user_id = u.user_id AND dv.pk_column_1 IS NOT NULL
            AND ud.user_dataset_id NOT IN (SELECT dataset_id FROM userlogins5_archive.dataset_values));         
      
      
-------------- steps -------------------
INSERT INTO userlogins5_archive.steps
      (step_id, user_id, left_child_id, right_child_id, create_time, last_run_time, estimate_size, 
       answer_filter, custom_name, is_deleted, is_valid, collapsed_name, is_collapsible, assigned_weight, 
       project_id, project_version, question_name, strategy_id, display_params, result_message, prev_step_id)
SELECT step_id, user_id, left_child_id, right_child_id, create_time, last_run_time, estimate_size, 
       answer_filter, custom_name, is_deleted, is_valid, collapsed_name, is_collapsible, assigned_weight, 
       project_id, project_version, question_name, strategy_id, display_params, result_message, prev_step_id
FROM userlogins5.steps WHERE user_id IN (SELECT user_id FROM users5);
      
-- to run
INSERT INTO userlogins5_archive.steps
      (step_id, user_id, left_child_id, right_child_id, create_time, last_run_time, estimate_size, 
       answer_filter, custom_name, is_deleted, is_valid, collapsed_name, is_collapsible, assigned_weight, 
       project_id, project_version, question_name, strategy_id, display_params, result_message, prev_step_id)
SELECT step_id, user_id, left_child_id, right_child_id, create_time, last_run_time, estimate_size, 
       answer_filter, custom_name, is_deleted, is_valid, collapsed_name, is_collapsible, assigned_weight, 
       project_id, project_version, question_name, strategy_id, display_params, result_message, prev_step_id
FROM userlogins4.steps 
WHERE user_id IN (SELECT user_id FROM users4)
  AND step_id NOT IN (SELECT step_id FROM userlogins5_archive.steps);

-- to run
INSERT INTO userlogins5_archive.steps
      (step_id, user_id, left_child_id, right_child_id, create_time, last_run_time, estimate_size, 
       answer_filter, custom_name, is_deleted, is_valid, collapsed_name, is_collapsible, assigned_weight, 
       project_id, project_version, question_name, strategy_id, display_params, result_message, prev_step_id)
SELECT step_id, user_id, left_child_id, right_child_id, create_time, last_run_time, estimate_size, 
       answer_filter, custom_name, is_deleted, is_valid, collapsed_name, is_collapsible, assigned_weight, 
       project_id, project_version, question_name, strategy_id, display_params, result_message, prev_step_id
FROM userlogins3.steps 
WHERE user_id IN (SELECT user_id FROM users3)
  AND step_id NOT IN (SELECT step_id FROM userlogins5_archive.steps);

-- to run
INSERT INTO userlogins5_archive.steps
      (step_id, user_id, left_child_id, right_child_id, create_time, last_run_time, estimate_size, 
       answer_filter, custom_name, is_deleted, is_valid, collapsed_name, is_collapsible, assigned_weight, 
       project_id, project_version, question_name, strategy_id, display_params, result_message, prev_step_id)
SELECT step_id, user_id, left_child_id, right_child_id, create_time, last_run_time, estimate_size, 
       answer_filter, custom_name, is_deleted, is_valid, collapsed_name, is_collapsible, assigned_weight, 
       project_id, project_version, question_name, strategy_id, display_params, result_message, prev_step_id
FROM userlogins3_archive.steps 
WHERE user_id IN (SELECT user_id FROM users3_archive)
  AND step_id NOT IN (SELECT step_id FROM userlogins5_archive.steps);      

-- to run  
INSERT INTO userlogins5_archive.steps
      (step_id, user_id, left_child_id, right_child_id, create_time, last_run_time, estimate_size, 
       answer_filter, custom_name, is_deleted, is_valid, collapsed_name, is_collapsible, assigned_weight, 
       project_id, project_version, question_name, strategy_id, display_params, result_message, prev_step_id)
SELECT step_id, user_id, left_child_id, right_child_id, create_time, last_run_time, estimate_size, 
       answer_filter, custom_name, is_deleted, is_valid, collapsed_name, is_collapsible, assigned_weight, 
       project_id, project_version, question_name, strategy_id, display_params, result_message, prev_step_id
FROM userlogins3_archive_south.steps 
WHERE user_id IN (SELECT user_id FROM users3_archive_south)
  AND step_id NOT IN (SELECT step_id FROM userlogins5_archive.steps);      
      

------------ strategies ------------------
INSERT INTO userlogins5_archive.strategies
      (strategy_id, user_id, root_step_id, project_id, version, is_saved, create_time, last_view_time, 
       last_modify_time, description, signature, name, saved_name, is_deleted, is_public, prev_strategy_id)
SELECT strategy_id, user_id, root_step_id, project_id, version, is_saved, create_time, last_view_time, 
       last_modify_time, description, signature, name, saved_name, is_deleted, is_public, prev_strategy_id
FROM userlogins5.strategies 
WHERE user_id IN (SELECT user_id FROM users5);


-- to run
INSERT INTO userlogins5_archive.strategies
      (strategy_id, user_id, root_step_id, project_id, version, is_saved, create_time, last_view_time, 
       last_modify_time, description, signature, name, saved_name, is_deleted, is_public, prev_strategy_id)
SELECT strategy_id, user_id, root_step_id, project_id, version, is_saved, create_time, last_view_time, 
       last_modify_time, description, signature, name, saved_name, is_deleted, is_public, prev_strategy_id
FROM userlogins4.strategies 
WHERE user_id IN (SELECT user_id FROM users4)
  AND strategy_id NOT IN (SELECT strategy_id FROM userlogins5_archive.strategies);

-- to run
INSERT INTO userlogins5_archive.strategies
      (strategy_id, user_id, root_step_id, project_id, version, is_saved, create_time, last_view_time, 
       last_modify_time, description, signature, name, saved_name, is_deleted, is_public, prev_strategy_id)
SELECT strategy_id, user_id, root_step_id, project_id, version, is_saved, create_time, last_view_time, 
       last_modify_time, description, signature, name, saved_name, is_deleted, is_public, prev_strategy_id
FROM userlogins4.strategies 
WHERE user_id IN (SELECT user_id FROM users3)
  AND strategy_id NOT IN (SELECT strategy_id FROM userlogins5_archive.strategies);

-- to run
INSERT INTO userlogins5_archive.strategies
      (strategy_id, user_id, root_step_id, project_id, version, is_saved, create_time, last_view_time, 
       last_modify_time, description, signature, name, saved_name, is_deleted, is_public, prev_strategy_id)
SELECT strategy_id, user_id, root_step_id, project_id, version, is_saved, create_time, last_view_time, 
       last_modify_time, description, signature, name, saved_name, is_deleted, is_public, prev_strategy_id
FROM userlogins3_archive.strategies 
WHERE user_id IN (SELECT user_id FROM users3_archive)
  AND strategy_id NOT IN (SELECT strategy_id FROM userlogins5_archive.strategies);

-- to run
INSERT INTO userlogins5_archive.strategies
      (strategy_id, user_id, root_step_id, project_id, version, is_saved, create_time, last_view_time, 
       last_modify_time, description, signature, name, saved_name, is_deleted, is_public, prev_strategy_id)
SELECT strategy_id, user_id, root_step_id, project_id, version, is_saved, create_time, last_view_time, 
       last_modify_time, description, signature, name, saved_name, is_deleted, is_public, prev_strategy_id
FROM userlogins3_archive_south.strategies 
WHERE user_id IN (SELECT user_id FROM users3_archive_south)
  AND strategy_id NOT IN (SELECT strategy_id FROM userlogins5_archive.strategies);
      