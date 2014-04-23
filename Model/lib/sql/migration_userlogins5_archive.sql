DELETE FROM userlogins5_archive.categories;
DELETE FROM userlogins5_archive.config;
DELETE FROM userlogins5_archive.steps;
DELETE FROM userlogins5_archive.strategies;
DELETE FROM userlogins5_archive.dataset_values;
DELETE FROM userlogins5_archive.datasets;
DELETE FROM userlogins5_archive.user_baskets;
DELETE FROM userlogins5_archive.favorites;
DELETE FROM userlogins5_archive.preferences;
DELETE FROM userlogins5_archive.user_roles;
DELETE FROM userlogins5_archive.users;

/* users */
INSERT INTO userlogins5_archive.users 
      (USER_ID, EMAIL, PASSWD, IS_GUEST, SIGNATURE, REGISTER_TIME, LAST_ACTIVE, LAST_NAME, FIRST_NAME, MIDDLE_NAME, TITLE,
       ORGANIZATION, DEPARTMENT, ADDRESS, CITY, STATE, ZIP_CODE, PHONE_NUMBER, COUNTRY, PREV_USER_ID)
SELECT USER_ID, EMAIL, PASSWD, IS_GUEST, SIGNATURE, REGISTER_TIME, LAST_ACTIVE, LAST_NAME, FIRST_NAME, MIDDLE_NAME, TITLE,
       ORGANIZATION, DEPARTMENT, ADDRESS, CITY, STATE, ZIP_CODE, PHONE_NUMBER, COUNTRY, PREV_USER_ID
FROM userlogins4.users 
WHERE is_guest = 0 OR user_id IN (SELECT user_id FROM userlogins4.steps);

INSERT INTO userlogins5_archive.users 
      (USER_ID, EMAIL, PASSWD, IS_GUEST, SIGNATURE, REGISTER_TIME, LAST_ACTIVE, LAST_NAME, FIRST_NAME, MIDDLE_NAME, TITLE,
       ORGANIZATION, DEPARTMENT, ADDRESS, CITY, STATE, ZIP_CODE, PHONE_NUMBER, COUNTRY, PREV_USER_ID)
SELECT USER_ID, EMAIL, PASSWD, IS_GUEST, SIGNATURE, REGISTER_TIME, LAST_ACTIVE, LAST_NAME, FIRST_NAME, MIDDLE_NAME, TITLE,
       ORGANIZATION, DEPARTMENT, ADDRESS, CITY, STATE, ZIP_CODE, PHONE_NUMBER, COUNTRY, PREV_USER_ID
FROM userlogins3.users 
WHERE user_id NOT IN (SELECT user_id FROM userlogins5_archive.users)
  AND (is_guest = 0 OR user_id IN (SELECT user_id FROM userlogins3.steps));

INSERT INTO userlogins5_archive.users 
      (USER_ID, EMAIL, PASSWD, IS_GUEST, SIGNATURE, REGISTER_TIME, LAST_ACTIVE, LAST_NAME, FIRST_NAME, MIDDLE_NAME, TITLE,
       ORGANIZATION, DEPARTMENT, ADDRESS, CITY, STATE, ZIP_CODE, PHONE_NUMBER, COUNTRY, PREV_USER_ID)
SELECT USER_ID, EMAIL, PASSWD, IS_GUEST, SIGNATURE, REGISTER_TIME, LAST_ACTIVE, LAST_NAME, FIRST_NAME, MIDDLE_NAME, TITLE,
       ORGANIZATION, DEPARTMENT, ADDRESS, CITY, STATE, ZIP_CODE, PHONE_NUMBER, COUNTRY, PREV_USER_ID
FROM userlogins3_archive.users 
WHERE user_id NOT IN (SELECT user_id FROM userlogins5_archive.users)
  AND (is_guest = 0 OR user_id IN (SELECT user_id FROM userlogins3_archive.steps));

INSERT INTO userlogins5_archive.users 
      (USER_ID, EMAIL, PASSWD, IS_GUEST, SIGNATURE, REGISTER_TIME, LAST_ACTIVE, LAST_NAME, FIRST_NAME, MIDDLE_NAME, TITLE,
       ORGANIZATION, DEPARTMENT, ADDRESS, CITY, STATE, ZIP_CODE, PHONE_NUMBER, COUNTRY, PREV_USER_ID)
SELECT USER_ID, EMAIL, PASSWD, IS_GUEST, SIGNATURE, REGISTER_TIME, LAST_ACTIVE, LAST_NAME, FIRST_NAME, MIDDLE_NAME, TITLE,
       ORGANIZATION, DEPARTMENT, ADDRESS, CITY, STATE, ZIP_CODE, PHONE_NUMBER, COUNTRY, PREV_USER_ID
FROM userlogins3_archive_south.users 
WHERE user_id NOT IN (SELECT user_id FROM userlogins5_archive.users)
  AND (is_guest = 0 OR user_id IN (SELECT user_id FROM userlogins3_archive_south.steps));


/* user roles */
INSERT INTO userlogins5_archive.user_roles (USER_ID, USER_ROLE)
SELECT r.USER_ID, r.USER_ROLE 
FROM userlogins4.user_roles r, userlogins5_archive.users u
WHERE r.user_id = u.user_id;

INSERT INTO userlogins5_archive.user_roles (USER_ID, USER_ROLE)
SELECT r.USER_ID, r.USER_ROLE 
FROM userlogins3.user_roles r, userlogins5_archive.users u
WHERE r.user_id = u.user_id AND r.user_id NOT IN (SELECT user_id FROM userlogins5_archive.user_roles);

INSERT INTO userlogins5_archive.user_roles (USER_ID, USER_ROLE)
SELECT r.USER_ID, r.USER_ROLE 
FROM userlogins3_archive.user_roles r, userlogins5_archive.users u
WHERE r.user_id = u.user_id AND r.user_id NOT IN (SELECT user_id FROM userlogins5_archive.user_roles);

INSERT INTO userlogins5_archive.user_roles (USER_ID, USER_ROLE)
SELECT r.USER_ID, r.USER_ROLE 
FROM userlogins3_archive_south.user_roles r, userlogins5_archive.users u
WHERE r.user_id = u.user_id AND r.user_id NOT IN (SELECT user_id FROM userlogins5_archive.user_roles);


/* user preferences */
INSERT INTO userlogins5_archive.preferences (user_id, project_id, preference_name, preference_value)
SELECT p.user_id, project_id, preference_name, preference_value
FROM userlogins4.preferences p, userlogins5_archive.users u
WHERE p.user_id = u.user_id;

INSERT INTO userlogins5_archive.preferences (user_id, project_id, preference_name, preference_value)
SELECT p.user_id, project_id, preference_name, preference_value
FROM userlogins3.preferences p, userlogins5_archive.users u
WHERE p.user_id = u.user_id AND p.user_id NOT IN (SELECT user_id FROM userlogins5_archive.preferences);

INSERT INTO userlogins5_archive.preferences (user_id, project_id, preference_name, preference_value)
SELECT p.user_id, project_id, preference_name, preference_value
FROM userlogins3_archive.preferences p, userlogins5_archive.users u
WHERE p.user_id = u.user_id AND p.user_id NOT IN (SELECT user_id FROM userlogins5_archive.preferences);

INSERT INTO userlogins5_archive.preferences (user_id, project_id, preference_name, preference_value)
SELECT p.user_id, project_id, preference_name, preference_value
FROM userlogins3_archive_south.preferences p, userlogins5_archive.users u
WHERE p.user_id = u.user_id AND p.user_id NOT IN (SELECT user_id FROM userlogins5_archive.preferences);


/* user favorites */
INSERT INTO userlogins5_archive.favorites 
      (favorite_id, user_id, project_id, record_class, pk_column_1, pk_column_2, pk_column_3, record_note, record_group)
SELECT favorite_id, f.user_id, project_id, record_class, pk_column_1, pk_column_2, pk_column_3, record_note, record_group
FROM userlogins4.favorites f, userlogins5_archive.users u
WHERE f.user_id = u.user_id;

INSERT INTO userlogins5_archive.favorites 
      (favorite_id, user_id, project_id, record_class, pk_column_1, pk_column_2, pk_column_3, record_note, record_group)
SELECT (SELECT max(favorite_id) FROM userlogins5_archive.favorites) + rownum AS favorite_id, f.user_id, project_id, 
       record_class, pk_column_1, pk_column_2, pk_column_3, record_note, record_group
FROM userlogins3.favorites f, userlogins5_archive.users u
WHERE f.user_id = u.user_id AND f.user_id NOT IN (SELECT user_id FROM userlogins5_archive.favorites);

INSERT INTO userlogins5_archive.favorites 
      (favorite_id, user_id, project_id, record_class, pk_column_1, pk_column_2, pk_column_3, record_note, record_group)
SELECT (SELECT max(favorite_id) FROM userlogins5_archive.favorites) + rownum AS favorite_id, f.user_id, project_id, 
       record_class, pk_column_1, pk_column_2, pk_column_3, record_note, record_group
FROM userlogins3_archive.favorites f, userlogins5_archive.users u
WHERE f.user_id = u.user_id AND f.user_id NOT IN (SELECT user_id FROM userlogins5_archive.favorites);

INSERT INTO userlogins5_archive.favorites 
      (favorite_id, user_id, project_id, record_class, pk_column_1, pk_column_2, pk_column_3, record_note, record_group)
SELECT (SELECT max(favorite_id) FROM userlogins5_archive.favorites) + rownum AS favorite_id, f.user_id, project_id, 
       record_class, pk_column_1, pk_column_2, pk_column_3, record_note, record_group
FROM userlogins3_archive_south.favorites f, userlogins5_archive.users u
WHERE f.user_id = u.user_id AND f.user_id NOT IN (SELECT user_id FROM userlogins5_archive.favorites);


/* user basekets */
INSERT INTO userlogins5_archive.user_baskets 
      (basket_id, user_id, project_id, record_class, pk_column_1, pk_column_2, pk_column_3)
SELECT basket_id, b.user_id, project_id, record_class, pk_column_1, pk_column_2, pk_column_3
FROM userlogins4.user_baskets b, userlogins5_archive.users u
WHERE b.user_id = u.user_id;

INSERT INTO userlogins5_archive.user_baskets 
      (basket_id, user_id, project_id, record_class, pk_column_1, pk_column_2, pk_column_3)
SELECT (SELECT max(basket_id) FROM userlogins5_archive.user_baskets) + rownum AS basket_id, b.user_id, project_id, 
       record_class, pk_column_1, pk_column_2, pk_column_3
FROM userlogins3.user_baskets b, userlogins5_archive.users u
WHERE b.user_id = u.user_id AND b.user_id NOT IN (SELECT user_id FROM userlogins5_archive.user_baskets);

INSERT INTO userlogins5_archive.user_baskets 
      (basket_id, user_id, project_id, record_class, pk_column_1, pk_column_2, pk_column_3)
SELECT (SELECT max(basket_id) FROM userlogins5_archive.user_baskets) + rownum AS basket_id, b.user_id, project_id, 
       record_class, pk_column_1, pk_column_2, pk_column_3
FROM userlogins3_archive.user_baskets b, userlogins5_archive.users u
WHERE b.user_id = u.user_id AND b.user_id NOT IN (SELECT user_id FROM userlogins5_archive.user_baskets);

INSERT INTO userlogins5_archive.user_baskets 
      (basket_id, user_id, project_id, record_class, pk_column_1, pk_column_2, pk_column_3)
SELECT (SELECT max(basket_id) FROM userlogins5_archive.user_baskets) + rownum AS basket_id, b.user_id, project_id, 
       record_class, pk_column_1, pk_column_2, pk_column_3
FROM userlogins3_archive_south.user_baskets b, userlogins5_archive.users u
WHERE b.user_id = u.user_id AND b.user_id NOT IN (SELECT user_id FROM userlogins5_archive.user_baskets);





