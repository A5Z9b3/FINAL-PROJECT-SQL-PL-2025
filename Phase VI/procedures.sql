
-- =========================================
-- HMMS Phase VI: PROCEDURES
-- =========================================

-- Add new maintenance record
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

-- Update equipment status
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

-- Log an alert
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
