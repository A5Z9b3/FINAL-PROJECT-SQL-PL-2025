
-- =========================================
-- HMMS Phase VI: CURSORS & BULK OPERATIONS
-- =========================================

-- Explicit cursor example
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

-- Bulk delete old maintenance records
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
