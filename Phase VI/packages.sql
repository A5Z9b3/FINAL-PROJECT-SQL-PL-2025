
-- =========================================
-- HMMS Phase VI: PACKAGE EXAMPLE
-- =========================================

CREATE OR REPLACE PACKAGE equipment_pkg AS
    PROCEDURE update_status(p_equipment_id IN NUMBER, p_status IN VARCHAR2);
    FUNCTION total_maintenance(p_equipment_id IN NUMBER) RETURN NUMBER;
    PROCEDURE log_equipment_alert(p_equipment_id IN NUMBER, p_desc IN VARCHAR2);
END equipment_pkg;
/

CREATE OR REPLACE PACKAGE BODY equipment_pkg AS

    PROCEDURE update_status(p_equipment_id IN NUMBER, p_status IN VARCHAR2) IS
    BEGIN
        UPDATE Equipment SET Status = p_status WHERE EquipmentID = p_equipment_id;
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
            ROLLBACK;
    END;

    FUNCTION total_maintenance(p_equipment_id IN NUMBER) RETURN NUMBER IS
        v_total NUMBER;
    BEGIN
        SELECT NVL(SUM(Cost),0) INTO v_total FROM Maintenance WHERE EquipmentID = p_equipment_id;
        RETURN v_total;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN NULL;
    END;

    PROCEDURE log_equipment_alert(p_equipment_id IN NUMBER, p_desc IN VARCHAR2) IS
    BEGIN
        INSERT INTO Alerts (AlertID, EquipmentID, IssueDescription, DateReported, Status)
        VALUES (seq_alert_id.NEXTVAL, p_equipment_id, p_desc, SYSDATE, 'Pending');
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Error logging alert: ' || SQLERRM);
            ROLLBACK;
    END;

END equipment_pkg;
/
