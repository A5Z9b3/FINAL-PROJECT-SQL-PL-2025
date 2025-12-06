-- =========================================================================
-- PHASE VII — HMMS: Advanced Programming & Auditing
-- Use your exact tables (Equipment, Departments, Maintenance, Maintenance_History,
-- Technicians, Alerts). Run as script (F5) in SQL Developer.
-- =========================================================================

SET SERVEROUTPUT ON SIZE 1000000;

-- =========================
-- 0. Create supporting objects if missing (safe: ignore errors)
-- =========================

BEGIN
  -- sequence for audit id (if not exists)
  BEGIN
    EXECUTE IMMEDIATE('CREATE SEQUENCE seq_audit_id START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE');
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  -- HOLIDAYS table
  BEGIN
    EXECUTE IMMEDIATE('CREATE TABLE HOLIDAYS (
      HOLIDAY_DATE DATE PRIMARY KEY,
      DESCRIPTION  VARCHAR2(200),
      CREATED_AT   DATE DEFAULT SYSDATE
    )');
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  -- AUDIT_LOG table
  BEGIN
    EXECUTE IMMEDIATE('CREATE TABLE AUDIT_LOG (
      AUDIT_ID     NUMBER PRIMARY KEY,
      USERNAME     VARCHAR2(100),
      OPERATION    VARCHAR2(10),
      TABLE_NAME   VARCHAR2(100),
      ROW_PK       VARCHAR2(4000),
      ATTEMPT_AT   DATE,
      ALLOWED_FLAG CHAR(1),
      REASON       VARCHAR2(4000),
      SQL_TEXT     CLOB
    )');
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  -- Ensure seq_audit_id used if AUDIT_ID isn't identity-capable
  BEGIN
    EXECUTE IMMEDIATE('ALTER TABLE AUDIT_LOG ADD (AUDIT_ID_TMP NUMBER)');
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  -- Create HMMS tables only if they don't exist (simple columns per your spec)
  BEGIN
    EXECUTE IMMEDIATE('CREATE TABLE DEPARTMENTS (
      DEPTID NUMBER PRIMARY KEY,
      DEPTNAME VARCHAR2(100),
      LOCATION VARCHAR2(200),
      HEADOFDEPT VARCHAR2(100)
    )');
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  BEGIN
    EXECUTE IMMEDIATE('CREATE TABLE EQUIPMENT (
      EQUIPMENTID NUMBER PRIMARY KEY,
      NAME VARCHAR2(200),
      CATEGORY VARCHAR2(100),
      PURCHASEDATE DATE,
      WARRANTYEXPIRY DATE,
      STATUS VARCHAR2(50),
      DEPARTMENTID NUMBER
    )');
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  BEGIN
    EXECUTE IMMEDIATE('CREATE TABLE TECHNICIANS (
      TECHID NUMBER PRIMARY KEY,
      FULLNAME VARCHAR2(200),
      CONTACT VARCHAR2(50),
      SPECIALTY VARCHAR2(100)
    )');
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  BEGIN
    EXECUTE IMMEDIATE('CREATE TABLE MAINTENANCE (
      MAINTENANCEID NUMBER PRIMARY KEY,
      EQUIPMENTID NUMBER,
      TECHNICIANID NUMBER,
      MAINTENANCEDATE DATE,
      COST NUMBER(12,2),
      DESCRIPTION VARCHAR2(400)
    )');
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  BEGIN
    EXECUTE IMMEDIATE('CREATE TABLE MAINTENANCE_HISTORY (
      HISTORYID NUMBER PRIMARY KEY,
      EQUIPMENTID NUMBER,
      TECHNICIANID NUMBER,
      ACTIONTAKEN VARCHAR2(400),
      DATEFIXED DATE,
      COST NUMBER(12,2)
    )');
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  BEGIN
    EXECUTE IMMEDIATE('CREATE TABLE ALERTS (
      ALERTID NUMBER PRIMARY KEY,
      EQUIPMENTID NUMBER,
      ISSUEDESCRIPTION VARCHAR2(400),
      DATEREPORTED DATE,
      STATUS VARCHAR2(50)
    )');
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  COMMIT;
END;
/

-- make sure seq exists
BEGIN
  -- create seq_audit_id if doesn't exist (safe fallback)
  EXECUTE IMMEDIATE('CREATE SEQUENCE seq_audit_id START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE');
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

-- =========================
-- 1. audit_pkg: spec + body
--    - v_test_date: override for testing (NULL => SYSDATE)
--    - is_dml_allowed returns 'Y:...' or 'N:reason...'
--    - log_audit inserts to AUDIT_LOG using seq_audit_id
-- =========================

CREATE OR REPLACE PACKAGE audit_pkg IS
  v_test_date DATE := NULL; -- set to simulate different dates for testing
  FUNCTION my_now RETURN DATE;
  FUNCTION is_dml_allowed RETURN VARCHAR2;
  PROCEDURE log_audit(
    p_username   IN VARCHAR2,
    p_operation  IN VARCHAR2,
    p_table_name IN VARCHAR2,
    p_row_pk     IN VARCHAR2,
    p_allowed    IN CHAR,
    p_reason     IN VARCHAR2,
    p_sql_text   IN CLOB
  );
END audit_pkg;
/

CREATE OR REPLACE PACKAGE BODY audit_pkg IS

  FUNCTION my_now RETURN DATE IS
  BEGIN
    RETURN NVL(v_test_date, SYSDATE);
  END my_now;

  FUNCTION is_dml_allowed RETURN VARCHAR2 IS
    v_now DATE := my_now;
    v_day VARCHAR2(20);
    v_reason VARCHAR2(4000);
    v_hcount INTEGER;
  BEGIN
    -- get day name in English
    v_day := UPPER(RTRIM(TO_CHAR(v_now,'DAY','NLS_DATE_LANGUAGE=ENGLISH')));

    -- BLOCK Monday - Friday (per project requirement)
    IF v_day IN ('MONDAY','TUESDAY','WEDNESDAY','THURSDAY','FRIDAY') THEN
      v_reason := 'Operation disallowed: Weekday (Mon-Fri).';
      RETURN 'N:'||v_reason;
    END IF;

    -- BLOCK if today is a holiday (HOLIDAYS table)
    SELECT COUNT(*) INTO v_hcount FROM HOLIDAYS h WHERE TRUNC(h.HOLIDAY_DATE) = TRUNC(v_now);
    IF v_hcount > 0 THEN
      SELECT DESCRIPTION INTO v_reason FROM HOLIDAYS WHERE TRUNC(HOLIDAY_DATE) = TRUNC(v_now) AND ROWNUM = 1;
      v_reason := 'Operation disallowed: Public holiday ('||v_reason||').';
      RETURN 'N:'||v_reason;
    END IF;

    RETURN 'Y:Allowed';
  EXCEPTION WHEN OTHERS THEN
    RETURN 'N:Error checking rules: '||SUBSTR(SQLERRM,1,2000);
  END is_dml_allowed;

  PROCEDURE log_audit(
    p_username   IN VARCHAR2,
    p_operation  IN VARCHAR2,
    p_table_name IN VARCHAR2,
    p_row_pk     IN VARCHAR2,
    p_allowed    IN CHAR,
    p_reason     IN VARCHAR2,
    p_sql_text   IN CLOB
  ) IS
  BEGIN
    INSERT INTO AUDIT_LOG (
      AUDIT_ID, USERNAME, OPERATION, TABLE_NAME, ROW_PK, ATTEMPT_AT, ALLOWED_FLAG, REASON, SQL_TEXT
    ) VALUES (
      seq_audit_id.NEXTVAL,
      NVL(p_username,'UNKNOWN'),
      p_operation,
      p_table_name,
      p_row_pk,
      my_now,
      p_allowed,
      p_reason,
      p_sql_text
    );
    -- do NOT commit here; let caller decide
  EXCEPTION WHEN OTHERS THEN
    NULL; -- logging must not break application DML processing
  END log_audit;

END audit_pkg;
/
COMMIT;

-- =========================
-- 2. Row-level triggers for each HMMS table (Equipment, Departments, Technicians,
--    Maintenance_History, Alerts). Each logs attempt then blocks when needed.
--    For MAINTENANCE we'll use a compound trigger example (multi-row).
-- =========================

-- 2.1 EQUIPMENT trigger
CREATE OR REPLACE TRIGGER trg_equipment_audit
BEFORE INSERT OR UPDATE OR DELETE ON EQUIPMENT
FOR EACH ROW
DECLARE
  v_res VARCHAR2(4000);
  v_allowed CHAR(1);
  v_reason VARCHAR2(4000);
  v_pk VARCHAR2(4000);
BEGIN
  v_res := audit_pkg.is_dml_allowed;
  IF SUBSTR(v_res,1,2)='Y:' THEN
    v_allowed := 'Y'; v_reason := SUBSTR(v_res,3);
  ELSE
    v_allowed := 'N'; v_reason := SUBSTR(v_res,3);
  END IF;

  v_pk := NVL(TO_CHAR(:NEW.EQUIPMENTID), TO_CHAR(:OLD.EQUIPMENTID));

  audit_pkg.log_audit(USER, CASE WHEN INSERTING THEN 'INSERT' WHEN UPDATING THEN 'UPDATE' ELSE 'DELETE' END,
                      'EQUIPMENT', v_pk, v_allowed, v_reason, NULL);

  IF v_allowed='N' THEN
    RAISE_APPLICATION_ERROR(-20001, v_reason);
  END IF;
END;
/

-- 2.2 DEPARTMENTS trigger
CREATE OR REPLACE TRIGGER trg_departments_audit
BEFORE INSERT OR UPDATE OR DELETE ON DEPARTMENTS
FOR EACH ROW
DECLARE
  v_res VARCHAR2(4000);
  v_allowed CHAR(1);
  v_reason VARCHAR2(4000);
  v_pk VARCHAR2(4000);
BEGIN
  v_res := audit_pkg.is_dml_allowed;
  IF SUBSTR(v_res,1,2)='Y:' THEN
    v_allowed := 'Y'; v_reason := SUBSTR(v_res,3);
  ELSE
    v_allowed := 'N'; v_reason := SUBSTR(v_res,3);
  END IF;

  v_pk := NVL(TO_CHAR(:NEW.DEPTID), TO_CHAR(:OLD.DEPTID));

  audit_pkg.log_audit(USER, CASE WHEN INSERTING THEN 'INSERT' WHEN UPDATING THEN 'UPDATE' ELSE 'DELETE' END,
                      'DEPARTMENTS', v_pk, v_allowed, v_reason, NULL);

  IF v_allowed='N' THEN
    RAISE_APPLICATION_ERROR(-20002, v_reason);
  END IF;
END;
/

-- 2.3 TECHNICIANS trigger
CREATE OR REPLACE TRIGGER trg_technicians_audit
BEFORE INSERT OR UPDATE OR DELETE ON TECHNICIANS
FOR EACH ROW
DECLARE
  v_res VARCHAR2(4000);
  v_allowed CHAR(1);
  v_reason VARCHAR2(4000);
  v_pk VARCHAR2(4000);
BEGIN
  v_res := audit_pkg.is_dml_allowed;
  IF SUBSTR(v_res,1,2)='Y:' THEN
    v_allowed := 'Y'; v_reason := SUBSTR(v_res,3);
  ELSE
    v_allowed := 'N'; v_reason := SUBSTR(v_res,3);
  END IF;

  v_pk := NVL(TO_CHAR(:NEW.TECHID), TO_CHAR(:OLD.TECHID));

  audit_pkg.log_audit(USER, CASE WHEN INSERTING THEN 'INSERT' WHEN UPDATING THEN 'UPDATE' ELSE 'DELETE' END,
                      'TECHNICIANS', v_pk, v_allowed, v_reason, NULL);

  IF v_allowed='N' THEN
    RAISE_APPLICATION_ERROR(-20003, v_reason);
  END IF;
END;
/

-- 2.4 MAINTENANCE_HISTORY trigger
CREATE OR REPLACE TRIGGER trg_maint_history_audit
BEFORE INSERT OR UPDATE OR DELETE ON MAINTENANCE_HISTORY
FOR EACH ROW
DECLARE
  v_res VARCHAR2(4000);
  v_allowed CHAR(1);
  v_reason VARCHAR2(4000);
  v_pk VARCHAR2(4000);
BEGIN
  v_res := audit_pkg.is_dml_allowed;
  IF SUBSTR(v_res,1,2)='Y:' THEN
    v_allowed := 'Y'; v_reason := SUBSTR(v_res,3);
  ELSE
    v_allowed := 'N'; v_reason := SUBSTR(v_res,3);
  END IF;

  v_pk := NVL(TO_CHAR(:NEW.HISTORYID), TO_CHAR(:OLD.HISTORYID));

  audit_pkg.log_audit(USER, CASE WHEN INSERTING THEN 'INSERT' WHEN UPDATING THEN 'UPDATE' ELSE 'DELETE' END,
                      'MAINTENANCE_HISTORY', v_pk, v_allowed, v_reason, NULL);

  IF v_allowed='N' THEN
    RAISE_APPLICATION_ERROR(-20004, v_reason);
  END IF;
END;
/

-- 2.5 ALERTS trigger
CREATE OR REPLACE TRIGGER trg_alerts_audit
BEFORE INSERT OR UPDATE OR DELETE ON ALERTS
FOR EACH ROW
DECLARE
  v_res VARCHAR2(4000);
  v_allowed CHAR(1);
  v_reason VARCHAR2(4000);
  v_pk VARCHAR2(4000);
BEGIN
  v_res := audit_pkg.is_dml_allowed;
  IF SUBSTR(v_res,1,2)='Y:' THEN
    v_allowed := 'Y'; v_reason := SUBSTR(v_res,3);
  ELSE
    v_allowed := 'N'; v_reason := SUBSTR(v_res,3);
  END IF;

  v_pk := NVL(TO_CHAR(:NEW.ALERTID), TO_CHAR(:OLD.ALERTID));

  audit_pkg.log_audit(USER, CASE WHEN INSERTING THEN 'INSERT' WHEN UPDATING THEN 'UPDATE' ELSE 'DELETE' END,
                      'ALERTS', v_pk, v_allowed, v_reason, NULL);

  IF v_allowed='N' THEN
    RAISE_APPLICATION_ERROR(-20005, v_reason);
  END IF;
END;
/

-- 2.6 MAINTENANCE compound trigger (collect row PKs + enforce once per statement)
CREATE OR REPLACE TRIGGER trg_maintenance_compound
FOR INSERT OR UPDATE OR DELETE ON MAINTENANCE
COMPOUND TRIGGER

  TYPE t_str_tab IS TABLE OF VARCHAR2(4000);
  g_row_pk t_str_tab := t_str_tab();
  g_op    t_str_tab := t_str_tab();
  g_decision VARCHAR2(4000);

  BEFORE STATEMENT IS
  BEGIN
    g_row_pk.DELETE;
    g_op.DELETE;
    g_decision := audit_pkg.is_dml_allowed; -- 'Y:...' or 'N:...'
  END BEFORE STATEMENT;

  BEFORE EACH ROW IS
  BEGIN
    IF INSERTING THEN
      g_row_pk.EXTEND;
      g_row_pk(g_row_pk.LAST) := 'NEW.MAINTENANCEID=' || NVL(TO_CHAR(:NEW.MAINTENANCEID),'NULL');
      g_op.EXTEND;
      g_op(g_op.LAST) := 'INSERT';
    ELSIF UPDATING THEN
      g_row_pk.EXTEND;
      g_row_pk(g_row_pk.LAST) := 'OLD.MAINTENANCEID=' || NVL(TO_CHAR(:OLD.MAINTENANCEID),'NULL') || '->NEW.MAINTENANCEID=' || NVL(TO_CHAR(:NEW.MAINTENANCEID),'NULL');
      g_op.EXTEND;
      g_op(g_op.LAST) := 'UPDATE';
    ELSIF DELETING THEN
      g_row_pk.EXTEND;
      g_row_pk(g_row_pk.LAST) := 'OLD.MAINTENANCEID=' || NVL(TO_CHAR(:OLD.MAINTENANCEID),'NULL');
      g_op.EXTEND;
      g_op(g_op.LAST) := 'DELETE';
    END IF;
  END BEFORE EACH ROW;

  AFTER STATEMENT IS
  BEGIN
    -- log attempts
    FOR i IN 1 .. NVL(g_row_pk.COUNT,0) LOOP
      DECLARE
        v_allowed CHAR(1);
        v_reason VARCHAR2(4000);
      BEGIN
        IF SUBSTR(g_decision,1,2)='Y:' THEN
          v_allowed := 'Y';
          v_reason := SUBSTR(g_decision,3);
        ELSE
          v_allowed := 'N';
          v_reason := SUBSTR(g_decision,3);
        END IF;

        audit_pkg.log_audit(USER, g_op(i), 'MAINTENANCE', g_row_pk(i), v_allowed, v_reason, NULL);
      EXCEPTION WHEN OTHERS THEN NULL;
      END;
    END LOOP;

    -- block if not allowed
    IF SUBSTR(g_decision,1,2)='N:' THEN
      RAISE_APPLICATION_ERROR(-20006, 'DML restricted by business rule: ' || SUBSTR(g_decision,3));
    END IF;

    g_row_pk.DELETE;
    g_op.DELETE;
    g_decision := NULL;
  END AFTER STATEMENT;

END trg_maintenance_compound;
/
COMMIT;

-- =========================
-- 3. Sample holiday(s) — add upcoming holidays here for testing
--    (You can update to include holidays for upcoming month)
-- =========================
BEGIN
  INSERT INTO HOLIDAYS(HOLIDAY_DATE, DESCRIPTION)
  VALUES (TO_DATE('2025-12-25','YYYY-MM-DD'),'Christmas');
EXCEPTION WHEN DUP_VAL_ON_INDEX THEN NULL;
END;
/
COMMIT;

-- =========================
-- 4. TEST SUITE — simulate weekday / weekend / holiday using audit_pkg.v_test_date
--    Run this block (F5) to see DBMS_OUTPUT and verify AUDIT_LOG entries.
-- =========================

DECLARE
  PROCEDURE show_audit IS
  BEGIN
    DBMS_OUTPUT.PUT_LINE('---- AUDIT_LOG (latest 40) ----');
    FOR r IN (
      SELECT AUDIT_ID, NVL(USERNAME,'-') USERNAME, OPERATION, TABLE_NAME, NVL(ROW_PK,'-') ROW_PK,
             TO_CHAR(ATTEMPT_AT,'YYYY-MM-DD HH24:MI:SS') ATT, ALLOWED_FLAG, NVL(REASON,'-') REASON
      FROM AUDIT_LOG
      ORDER BY ATTEMPT_AT DESC, AUDIT_ID DESC
      FETCH FIRST 40 ROWS ONLY
    ) LOOP
      DBMS_OUTPUT.PUT_LINE(r.AUDIT_ID || ' | ' || r.USERNAME || ' | ' || r.OPERATION || ' | ' || r.TABLE_NAME ||
                           ' | ' || r.ROW_PK || ' | ' || r.ATT || ' | ' || NVL(r.ALLOWED_FLAG,'-') || ' | ' || r.REASON);
    END LOOP;
  END show_audit;
BEGIN
  DBMS_OUTPUT.PUT_LINE('TEST 1: Weekday (2025-12-04) -> DENIED expected');
  audit_pkg.v_test_date := TO_DATE('2025-12-04','YYYY-MM-DD'); -- Thursday
  BEGIN
    INSERT INTO EQUIPMENT(EQUIPMENTID, NAME, CATEGORY) VALUES (99001, 'TestEqWeek','General');
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('UNEXPECTED: Insert succeeded on weekday');
  EXCEPTION WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Expected failure on weekday: ' || SQLERRM);
    ROLLBACK;
  END;
  show_audit;

  DBMS_OUTPUT.PUT_LINE('TEST 2: Weekend (2025-12-06) -> ALLOWED expected');
  audit_pkg.v_test_date := TO_DATE('2025-12-06','YYYY-MM-DD'); -- Saturday
  BEGIN
    INSERT INTO EQUIPMENT(EQUIPMENTID, NAME, CATEGORY) VALUES (99002, 'TestEqWeekend','General');
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Insert succeeded on weekend (expected).');
  EXCEPTION WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('UNEXPECTED failure on weekend: ' || SQLERRM);
    ROLLBACK;
  END;
  show_audit;

  DBMS_OUTPUT.PUT_LINE('TEST 3: Holiday (2025-12-25) -> DENIED expected');
  audit_pkg.v_test_date := TO_DATE('2025-12-25','YYYY-MM-DD'); -- Christmas
  BEGIN
    INSERT INTO EQUIPMENT(EQUIPMENTID, NAME, CATEGORY) VALUES (99003, 'TestEqHoliday','General');
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('UNEXPECTED: Insert succeeded on holiday');
  EXCEPTION WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Expected failure on holiday: ' || SQLERRM);
    ROLLBACK;
  END;
  show_audit;

  DBMS_OUTPUT.PUT_LINE('TEST 4: Maintenance insert on weekend -> ALLOWED and logged');
  audit_pkg.v_test_date := TO_DATE('2025-12-06','YYYY-MM-DD'); -- Saturday
  BEGIN
    INSERT INTO MAINTENANCE(MAINTENANCEID, EQUIPMENTID, TECHNICIANID, MAINTENANCEDATE, COST, DESCRIPTION)
    VALUES (98001, 99002, 1, audit_pkg.v_test_date, 150.00, 'Weekend maintenance');
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Maintenance insert succeeded on weekend.');
  EXCEPTION WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Maintenance insert failed unexpectedly: ' || SQLERRM);
    ROLLBACK;
  END;
  show_audit;

  DBMS_OUTPUT.PUT_LINE('TEST 5: Maintenance insert on weekday -> DENIED and logged');
  audit_pkg.v_test_date := TO_DATE('2025-12-04','YYYY-MM-DD'); -- Thursday
  BEGIN
    INSERT INTO MAINTENANCE(MAINTENANCEID, EQUIPMENTID, TECHNICIANID, MAINTENANCEDATE, COST, DESCRIPTION)
    VALUES (98002, 99002, 1, audit_pkg.v_test_date, 200.00, 'Weekday maintenance');
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('UNEXPECTED: Maintenance insert succeeded on weekday');
  EXCEPTION WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Expected maintenance insert failure on weekday: ' || SQLERRM);
    ROLLBACK;
  END;
  show_audit;

  -- reset
  audit_pkg.v_test_date := NULL;
  DBMS_OUTPUT.PUT_LINE('Tests complete. audit_pkg.v_test_date reset to NULL.');
END;
/
COMMIT;

SELECT * FROM AUDIT_LOG ORDER BY ATTEMPT_AT DESC FETCH FIRST 100 ROWS ONLY;

INSERT INTO HOLIDAYS(HOLIDAY_DATE, DESCRIPTION) VALUES (DATE '2025-12-25','Christmas');
COMMIT;

SELECT * FROM HOLIDAYS;

SHOW ERRORS TRIGGER TRG_RESTRICTION_BLOCK;
SHOW ERRORS PACKAGE AUDIT_PKG;
SHOW ERRORS PACKAGE BODY AUDIT_PKG;
SHOW ERRORS TRIGGER TRG_RESTRICTION_BLOCK;



DROP TRIGGER trg_restriction_block;
DROP PACKAGE audit_pkg;


CREATE OR REPLACE PACKAGE audit_pkg AS
  
  -- Returns SQL text of current statement
  FUNCTION get_sql_text RETURN CLOB;

  -- Check restriction (weekday, holiday)
  PROCEDURE is_operation_allowed(
      p_allowed OUT CHAR,
      p_reason  OUT VARCHAR2
  );

  -- Write audit log
  PROCEDURE log_event(
      p_operation   VARCHAR2,
      p_table       VARCHAR2,
      p_rowpk       VARCHAR2,
      p_allowed     CHAR,
      p_reason      VARCHAR2,
      p_sql         CLOB
  );

END audit_pkg;
/


CREATE TABLE HOLIDAYS (
    HOLIDAY_DATE DATE PRIMARY KEY,
    DESCRIPTION  VARCHAR2(100)
);
DROP TABLE HOLIDAYS;

SELECT object_name, object_type 
FROM user_objects
WHERE object_name = 'HOLIDAYS';

  
  
CREATE OR REPLACE PACKAGE AUDIT_PKG AS
  
  FUNCTION get_sql_text RETURN CLOB;

  PROCEDURE check_operation_allowed(
        p_allowed OUT CHAR,
        p_reason  OUT VARCHAR2 );

  PROCEDURE log_event(
        p_username  VARCHAR2,
        p_operation VARCHAR2,
        p_table     VARCHAR2,
        p_rowid     VARCHAR2,
        p_allowed   CHAR,
        p_reason    VARCHAR2,
        p_sql       CLOB );

END AUDIT_PKG;
/



CREATE OR REPLACE PACKAGE BODY AUDIT_PKG AS

  FUNCTION get_sql_text RETURN CLOB IS
      v_sql CLOB;
  BEGIN
      v_sql := DBMS_UTILITY.format_call_stack;
      RETURN v_sql;
  END get_sql_text;


  PROCEDURE check_operation_allowed(
        p_allowed OUT CHAR,
        p_reason  OUT VARCHAR2 ) IS

      v_day VARCHAR2(10);
      v_count NUMBER;

  BEGIN
      v_day := TRIM(TO_CHAR(SYSDATE, 'DAY'));

      -- WEEKDAY BLOCK
      IF v_day IN ('MONDAY','TUESDAY','WEDNESDAY','THURSDAY','FRIDAY') THEN
          p_allowed := 'N';
          p_reason  := 'Operation blocked: WEEKDAY not allowed.';
          RETURN;
      END IF;

      -- HOLIDAY BLOCK
      SELECT COUNT(*) INTO v_count
      FROM HOLIDAYS
      WHERE HOLIDAY_DATE = TRUNC(SYSDATE);

      IF v_count > 0 THEN
          p_allowed := 'N';
          p_reason  := 'Operation blocked: PUBLIC HOLIDAY.';
          RETURN;
      END IF;

      p_allowed := 'Y';
      p_reason  := 'Allowed';

  END check_operation_allowed;



  PROCEDURE log_event(
        p_username  VARCHAR2,
        p_operation VARCHAR2,
        p_table     VARCHAR2,
        p_rowid     VARCHAR2,
        p_allowed   CHAR,
        p_reason    VARCHAR2,
        p_sql       CLOB ) IS
  BEGIN

      INSERT INTO AUDIT_LOG(
          AUDIT_ID,
          USERNAME,
          OPERATION,
          TABLE_NAME,
          ROW_ID_VALUE,
          ATTEMPT_TIME,
          ALLOWED,
          REASON,
          SQL_TEXT
      )
      VALUES(
          SEQ_AUDIT_ID.NEXTVAL,
          p_username,
          p_operation,
          p_table,
          p_rowid,
          SYSDATE,
          p_allowed,
          p_reason,
          p_sql
      );

  END log_event;

END AUDIT_PKG;
/


DESC HOLIDAYS;

-- Check if today is a holiday
SELECT COUNT(*)
INTO v_is_holiday
FROM holidays
WHERE holiday_date = TRUNC(SYSDATE);



DECLARE
    v_is_holiday NUMBER;
BEGIN
    SELECT COUNT(*)
    INTO v_is_holiday
    FROM holidays
    WHERE holiday_date = TRUNC(SYSDATE);

    IF v_is_holiday > 0 THEN
        DBMS_OUTPUT.PUT_LINE('Today is a holiday — DML not allowed.');
    ELSE
        DBMS_OUTPUT.PUT_LINE('Today is NOT a holiday — DML allowed.');
    END IF;
END;
/


-- Drop existing objects (if any)
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE AUDIT_LOG CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'DROP SEQUENCE SEQ_AUDIT_ID';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/


-- Create sequence
CREATE SEQUENCE SEQ_AUDIT_ID START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;

-- Create audit log table
CREATE TABLE AUDIT_LOG (
    AUDIT_ID      NUMBER PRIMARY KEY,
    USERNAME      VARCHAR2(50),
    OPERATION     VARCHAR2(20),
    TABLE_NAME    VARCHAR2(50),
    ROW_ID_VALUE  VARCHAR2(100),
    ATTEMPT_TIME  DATE,
    ALLOWED       CHAR(1),
    REASON        VARCHAR2(400),
    SQL_TEXT      CLOB
);




-- Drop existing holidays table
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE HOLIDAYS CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

-- Create holidays table
CREATE TABLE HOLIDAYS (
    HOLIDAY_DATE DATE PRIMARY KEY,
    DESCRIPTION  VARCHAR2(100)
);

-- Example holiday
INSERT INTO HOLIDAYS (HOLIDAY_DATE, DESCRIPTION)
VALUES (DATE '2025-12-25', 'Christmas');
COMMIT;



CREATE OR REPLACE PACKAGE AUDIT_PKG IS
    v_test_date DATE := NULL; -- for testing

    -- log audit info
    PROCEDURE LOG_EVENT(
        p_username   IN VARCHAR2,
        p_operation  IN VARCHAR2,
        p_table_name IN VARCHAR2,
        p_row_id     IN VARCHAR2,
        p_allowed    IN CHAR,
        p_reason     IN VARCHAR2,
        p_sql_text   IN CLOB
    );

    -- check if operation is allowed
    FUNCTION IS_OPERATION_ALLOWED RETURN VARCHAR2;

    -- get current date/time
    FUNCTION MY_NOW RETURN DATE;
END AUDIT_PKG;
/

CREATE OR REPLACE PACKAGE BODY AUDIT_PKG IS

    FUNCTION MY_NOW RETURN DATE IS
    BEGIN
        RETURN NVL(v_test_date, SYSDATE);
    END;

    PROCEDURE LOG_EVENT(
        p_username   IN VARCHAR2,
        p_operation  IN VARCHAR2,
        p_table_name IN VARCHAR2,
        p_row_id     IN VARCHAR2,
        p_allowed    IN CHAR,
        p_reason     IN VARCHAR2,
        p_sql_text   IN CLOB
    ) IS
    BEGIN
        INSERT INTO AUDIT_LOG(
            AUDIT_ID, USERNAME, OPERATION, TABLE_NAME,
            ROW_ID_VALUE, ATTEMPT_TIME, ALLOWED, REASON, SQL_TEXT
        ) VALUES (
            SEQ_AUDIT_ID.NEXTVAL, NVL(p_username,'UNKNOWN'),
            p_operation, p_table_name, p_row_id,
            MY_NOW, p_allowed, p_reason, p_sql_text
        );
    EXCEPTION WHEN OTHERS THEN
        NULL; -- fail silently
    END LOG_EVENT;

    FUNCTION IS_OPERATION_ALLOWED RETURN VARCHAR2 IS
        v_now DATE := MY_NOW;
        v_day VARCHAR2(20);
        v_reason VARCHAR2(400);
        v_hcount INTEGER;
    BEGIN
        v_day := UPPER(TO_CHAR(v_now,'DAY','NLS_DATE_LANGUAGE=ENGLISH'));

        -- Block Monday-Friday
        IF v_day IN ('MONDAY','TUESDAY','WEDNESDAY','THURSDAY','FRIDAY') THEN
            v_reason := 'Weekday operation not allowed';
            RETURN 'N:' || v_reason;
        END IF;

        -- Block if holiday
        SELECT COUNT(*) INTO v_hcount FROM HOLIDAYS WHERE TRUNC(HOLIDAY_DATE) = TRUNC(v_now);
        IF v_hcount > 0 THEN
            SELECT DESCRIPTION INTO v_reason FROM HOLIDAYS WHERE TRUNC(HOLIDAY_DATE)=TRUNC(v_now) AND ROWNUM=1;
            v_reason := 'Public holiday: ' || v_reason;
            RETURN 'N:' || v_reason;
        END IF;

        RETURN 'Y:Allowed';
    EXCEPTION WHEN OTHERS THEN
        RETURN 'N:Error checking rules: ' || SUBSTR(SQLERRM,1,2000);
    END IS_OPERATION_ALLOWED;

END AUDIT_PKG;
/



CREATE OR REPLACE TRIGGER TRG_RESTRICTION_BLOCK
BEFORE INSERT OR UPDATE OR DELETE ON EQUIPMENT
FOR EACH ROW
DECLARE
    v_result VARCHAR2(4000);
    v_allowed CHAR(1);
    v_reason VARCHAR2(400);
BEGIN
    v_result := AUDIT_PKG.IS_OPERATION_ALLOWED;

    IF SUBSTR(v_result,1,2) = 'Y:' THEN
        v_allowed := 'Y';
        v_reason := SUBSTR(v_result,3);
    ELSE
        v_allowed := 'N';
        v_reason := SUBSTR(v_result,3);
    END IF;

    AUDIT_PKG.LOG_EVENT(USER, 
                        CASE 
                          WHEN INSERTING THEN 'INSERT'
                          WHEN UPDATING THEN 'UPDATE'
                          WHEN DELETING THEN 'DELETE'
                        END,
                        'EQUIPMENT',
                        NVL(:NEW.EquipmentID, :OLD.EquipmentID),
                        v_allowed,
                        v_reason,
                        NULL);

    IF v_allowed='N' THEN
        RAISE_APPLICATION_ERROR(-20001,'Operation denied: '||v_reason);
    END IF;
END;
/




-- Test weekday insert (DENIED)
BEGIN
    AUDIT_PKG.v_test_date := TO_DATE('2025-12-04','YYYY-MM-DD'); -- Thursday
    INSERT INTO EQUIPMENT (EquipmentID, Name, Category, PurchaseDate, WarrantyExpiry, Status, DepartmentID)
    VALUES (9001, 'TEST WEEKDAY', 'CAT', SYSDATE, SYSDATE+365, 'ACTIVE', 1);
EXCEPTION WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Expected failure: ' || SQLERRM);
END;
/

-- Test weekend insert (ALLOWED)
BEGIN
    AUDIT_PKG.v_test_date := TO_DATE('2025-12-06','YYYY-MM-DD'); -- Saturday
    INSERT INTO EQUIPMENT (EquipmentID, Name, Category, PurchaseDate, WarrantyExpiry, Status, DepartmentID)
    VALUES (9002, 'TEST WEEKEND', 'CAT', SYSDATE, SYSDATE+365, 'ACTIVE', 1);
    DBMS_OUTPUT.PUT_LINE('Insert succeeded on weekend.');
END;
/

-- Test holiday insert (DENIED)
BEGIN
    AUDIT_PKG.v_test_date := TO_DATE('2025-12-25','YYYY-MM-DD'); -- Christmas
    INSERT INTO EQUIPMENT (EquipmentID, Name, Category, PurchaseDate, WarrantyExpiry, Status, DepartmentID)
    VALUES (9003, 'TEST HOLIDAY', 'CAT', SYSDATE, SYSDATE+365, 'ACTIVE', 1);
EXCEPTION WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Expected holiday failure: ' || SQLERRM);
END;
/

-- Reset test date
BEGIN
    AUDIT_PKG.v_test_date := NULL;
END;
/


SELECT constraint_name, search_condition 
FROM user_constraints 
WHERE table_name = 'EQUIPMENT' 
AND constraint_type='C';




INSERT INTO EQUIPMENT 
(EquipmentID, Name, Category, PurchaseDate, WarrantyExpiry, Status, DepartmentID)
VALUES 
(9002, 'TEST WEEKEND', 'CAT', SYSDATE, SYSDATE + 365, 'Working', 1);
