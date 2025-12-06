
CREATE OR REPLACE PACKAGE audit_pkg IS
    v_test_date DATE := NULL;

    PROCEDURE log_audit(
        p_username   IN VARCHAR2,
        p_operation  IN VARCHAR2,
        p_table_name IN VARCHAR2,
        p_row_pk     IN VARCHAR2,
        p_allowed    IN CHAR,
        p_reason     IN VARCHAR2,
        p_sql_text   IN CLOB
    );

    FUNCTION is_dml_allowed RETURN VARCHAR2;
    FUNCTION my_now RETURN DATE;
END audit_pkg;
/

CREATE OR REPLACE PACKAGE BODY audit_pkg IS

    FUNCTION my_now RETURN DATE IS
    BEGIN
        RETURN NVL(v_test_date, SYSDATE);
    END;

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
            AUDIT_ID, USERNAME, OPERATION, TABLE_NAME, ROW_ID_VALUE,
            ATTEMPT_TIME, ALLOWED, REASON, SQL_TEXT
        )
        VALUES (
            SEQ_AUDIT_ID.NEXTVAL,
            NVL(p_username,'UNKNOWN'),
            p_operation,
            p_table_name,
            p_row_pk,
            my_now,
            p_allowed,
            p_reason,
            p_sql_text
        );
    EXCEPTION WHEN OTHERS THEN NULL;
    END log_audit;

    FUNCTION is_dml_allowed RETURN VARCHAR2 IS
        v_now DATE := my_now;
        v_day VARCHAR2(20);
        v_hcount INTEGER;
        v_reason VARCHAR2(4000);
    BEGIN
        v_day := UPPER(RTRIM(TO_CHAR(v_now,'DAY','NLS_DATE_LANGUAGE=ENGLISH')));

        IF v_day IN ('MONDAY','TUESDAY','WEDNESDAY','THURSDAY','FRIDAY') THEN
            v_reason := 'Operation disallowed: Weekday (Mon-Fri)';
            RETURN 'N:' || v_reason;
        END IF;

        SELECT COUNT(*) INTO v_hcount FROM HOLIDAYS WHERE TRUNC(HOLIDAY_DATE) = TRUNC(v_now);
        IF v_hcount > 0 THEN
            SELECT DESCRIPTION INTO v_reason FROM HOLIDAYS
            WHERE TRUNC(HOLIDAY_DATE) = TRUNC(v_now) AND ROWNUM = 1;
            v_reason := 'Operation disallowed: Public holiday (' || v_reason || ')';
            RETURN 'N:' || v_reason;
        END IF;

        RETURN 'Y:Allowed';
    EXCEPTION WHEN OTHERS THEN
        RETURN 'N:Error checking rules: ' || SUBSTR(SQLERRM,1,2000);
    END is_dml_allowed;

END audit_pkg;
/
