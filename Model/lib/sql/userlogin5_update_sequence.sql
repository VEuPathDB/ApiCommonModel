-- Need DBA to do this
GRANT CREATE ANY SEQUENCE to userlogins5;

-- login as userlogins5, then run the following.

-- the owner of this procedure needs CREATE SEQUENCE permission granted directly to him/her.
CREATE OR REPLACE PROCEDURE update_sequence (table_name IN VARCHAR, pk_column IN VARCHAR, start_offset IN NUMBER)
IS
  sequence_name VARCHAR(1000);
  start_id NUMBER;
BEGIN
  
  EXECUTE IMMEDIATE 'SELECT nvl(max(' || pk_column || '), 1) FROM ' || table_name INTO start_id;
  
  sequence_name := table_name || '_pkseq';
  start_id := ceil(start_id / 10 + 1) * 10 + start_offset;
  
  EXECUTE IMMEDIATE 'DROP SEQUENCE ' || sequence_name;
  EXECUTE IMMEDIATE 'CREATE SEQUENCE ' || sequence_name || ' START WITH ' || start_id || ' INCREMENT BY 10';

  EXECUTE IMMEDIATE 'GRANT SELECT ON ' || sequence_name || ' TO GUS_W';
  EXECUTE IMMEDIATE 'GRANT SELECT ON ' || sequence_name || ' TO GUS_R';

END;
/

GRANT EXECUTE ON update_sequence TO GUS_R; 
GRANT EXECUTE ON update_sequence TO GUS_W; 


DECLARE
  start_seed NUMBER;
BEGIN
  start_seed := 3; -- 0 for N, 3 for S
  update_sequence('Categories', 'category_id', start_seed);
  update_sequence('CommentFile', 'file_id', start_seed);
  update_sequence('CommentReference', 'comment_reference_id', start_seed);
  update_sequence('Comments', 'comment_id', start_seed);
  update_sequence('CommentSequence', 'comment_sequence_id', start_seed);
  update_sequence('CommentStableId', 'comment_stable_id', start_seed);
  update_sequence('CommentTargetCategory', 'comment_target_category_id', start_seed);
  update_sequence('dataset_values', 'dataset_value_id', start_seed);
  update_sequence('datasets', 'dataset_id', start_seed);
  update_sequence('external_databases', 'external_database_id', start_seed);
  update_sequence('favorites', 'favorite_id', start_seed);
  update_sequence('locations', 'location_id', start_seed);
  update_sequence('steps', 'step_id', start_seed);
  update_sequence('strategies', 'strategy_id', start_seed);
  update_sequence('user_baskets', 'basket_id', start_seed);
  update_sequence('users', 'user_id', start_seed);
END;
/
