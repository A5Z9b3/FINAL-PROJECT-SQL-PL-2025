-- =========================================
-- HMMS Phase VI: TESTING PROCEDURES/FUNCTIONS
-- =========================================

-- Test procedure: add_maintenance
DECLARE
    v_maint_id NUMBER;
BEGIN
    add_maintenance(1,1,250,'Test maintenance', v_maint_id);
    DBMS_OUTPUT.PUT_LINE('New maintenance ID: ' || v_maint_id);
END;
/

-- Test function: get_total_maintenance_cost
DECLARE
    v_total NUMBER;
BEGIN
    v_total := get_total_maintenance_cost(1);
    DBMS_OUTPUT.PUT_LINE('Total maintenance cost for EquipmentID 1: ' || v_total);
END;
/

-- Test package procedures
BEGIN
    equipment_pkg.update_status(1,'Working');
    equipment_pkg.log_equipment_alert(1,'Routine check');
    DBMS_OUTPUT.PUT_LINE('Total maintenance via package: ' || equipment_pkg.total_maintenance(1));
END;
/

-- Test cursor for pending alerts
DECLARE
    CURSOR c IS SELECT AlertID, EquipmentID FROM Alerts WHERE Status='Pending';
    v_row c%ROWTYPE;
BEGIN
    OPEN c;
    LOOP
        FETCH c INTO v_row;
        EXIT WHEN c%NOTFOUND;
        DBMS_OUTPUT.PUT_LINE('Pending Alert ID: ' || v_row.AlertID || ' EquipmentID: ' || v_row.EquipmentID);
    END LOOP;
    CLOSE c;
END;
/
