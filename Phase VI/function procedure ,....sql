CREATE OR REPLACE PROCEDURE add_maintenance(
    p_equipment_id IN NUMBER,
    p_technician_id IN NUMBER,
    p_cost IN NUMBER,
    p_description IN VARCHAR2,
    p_maint_id OUT NUMBER
) AS
BEGIN
    INSERT INTO Maintenance (MaintenanceID, EquipmentID, TechnicianID, MaintenanceDate, Cost, Description)
    VALUES (seq_maintenance_id.NEXTVAL, p_equipment_id, p_technician_id, SYSDATE, p_cost, p_description)
    RETURNING MaintenanceID INTO p_maint_id;

    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error adding maintenance: ' || SQLERRM);
        ROLLBACK;
END;
/

CREATE OR REPLACE PROCEDURE update_equipment_status(
    p_equipment_id IN NUMBER,
    p_status IN VARCHAR2
) AS
BEGIN
    UPDATE Equipment
    SET Status = p_status
    WHERE EquipmentID = p_equipment_id;

    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error updating equipment status: ' || SQLERRM);
        ROLLBACK;
END;
/


CREATE OR REPLACE PROCEDURE log_alert(
    p_equipment_id IN NUMBER,
    p_description IN VARCHAR2,
    p_status IN VARCHAR2 DEFAULT 'Pending'
) AS
    v_alert_id NUMBER;
BEGIN
    INSERT INTO Alerts (AlertID, EquipmentID, IssueDescription, DateReported, Status)
    VALUES (seq_alert_id.NEXTVAL, p_equipment_id, p_description, SYSDATE, p_status)
    RETURNING AlertID INTO v_alert_id;

    DBMS_OUTPUT.PUT_LINE('Alert logged with ID: ' || v_alert_id);
    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error logging alert: ' || SQLERRM);
        ROLLBACK;
END;
/

CREATE OR REPLACE FUNCTION get_total_maintenance_cost(
    p_equipment_id NUMBER
) RETURN NUMBER AS
    v_total NUMBER;
BEGIN
    SELECT NVL(SUM(Cost),0)
    INTO v_total
    FROM Maintenance
    WHERE EquipmentID = p_equipment_id;

    RETURN v_total;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN 0;
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error calculating cost: ' || SQLERRM);
        RETURN NULL;
END;
/

CREATE OR REPLACE FUNCTION is_equipment_exists(
    p_equipment_id NUMBER
) RETURN BOOLEAN AS
    v_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_count FROM Equipment WHERE EquipmentID = p_equipment_id;
    RETURN (v_count > 0);
END;
/

CREATE OR REPLACE FUNCTION get_technician_specialty(
    p_tech_id NUMBER
) RETURN VARCHAR2 AS
    v_specialty VARCHAR2(50);
BEGIN
    SELECT Specialty INTO v_specialty FROM Technicians WHERE TechID = p_tech_id;
    RETURN v_specialty;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN 'Unknown';
END;
/

DECLARE
    CURSOR c_pending_alerts IS
        SELECT AlertID, EquipmentID, IssueDescription
        FROM Alerts
        WHERE Status = 'Pending';

    v_alert c_pending_alerts%ROWTYPE;
BEGIN
    OPEN c_pending_alerts;
    LOOP
        FETCH c_pending_alerts INTO v_alert;
        EXIT WHEN c_pending_alerts%NOTFOUND;
        DBMS_OUTPUT.PUT_LINE('AlertID: ' || v_alert.AlertID || ' EquipmentID: ' || v_alert.EquipmentID);
    END LOOP;
    CLOSE c_pending_alerts;
END;
/


DECLARE
    TYPE t_maintenance IS TABLE OF Maintenance.MaintenanceID%TYPE;
    v_ids t_maintenance;

BEGIN
    SELECT MaintenanceID BULK COLLECT INTO v_ids
    FROM Maintenance
    WHERE MaintenanceDate < SYSDATE - 180;

    FORALL i IN v_ids.FIRST .. v_ids.LAST
        DELETE FROM Maintenance WHERE MaintenanceID = v_ids(i);

    COMMIT;
END;
/

-- Rank technicians by total maintenance cost
SELECT TechnicianID, SUM(Cost) AS TotalCost,
       RANK() OVER (ORDER BY SUM(Cost) DESC) AS Rank,
       DENSE_RANK() OVER (ORDER BY SUM(Cost) DESC) AS DenseRank
FROM Maintenance
GROUP BY TechnicianID;


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

