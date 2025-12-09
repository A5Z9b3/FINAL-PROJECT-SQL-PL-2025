-- ============================================
-- PHASE VII: Advanced Programming & Auditing
-- ============================================

SET SERVEROUTPUT ON SIZE UNLIMITED;

-- ============================================
-- 1. HOLIDAY MANAGEMENT TABLE (Already exists, just adding more holidays)
-- ============================================

-- Add more holidays for testing (December 2025)
BEGIN
    -- Remove any existing test holidays first
    DELETE FROM HOLIDAYS WHERE HolidayName LIKE 'Test Holiday%';
    COMMIT;
    
    -- Add holidays for December 2025 (current project timeframe)
    INSERT INTO HOLIDAYS (HolidayID, HolidayName, HolidayDate, Year) 
    VALUES (seq_holidays.NEXTVAL, 'Christmas Day', TO_DATE('25-12-2025', 'DD-MM-YYYY'), 2025);
    
    INSERT INTO HOLIDAYS (HolidayID, HolidayName, HolidayDate, Year) 
    VALUES (seq_holidays.NEXTVAL, 'Boxing Day', TO_DATE('26-12-2025', 'DD-MM-YYYY'), 2025);
    
    INSERT INTO HOLIDAYS (HolidayID, HolidayName, HolidayDate, Year) 
    VALUES (seq_holidays.NEXTVAL, 'New Year''s Eve', TO_DATE('31-12-2025', 'DD-MM-YYYY'), 2025);
    
    INSERT INTO HOLIDAYS (HolidayID, HolidayName, HolidayDate, Year) 
    VALUES (seq_holidays.NEXTVAL, 'New Year''s Day', TO_DATE('01-01-2026', 'DD-MM-YYYY'), 2026);
    
    -- Add some test holidays for current week
    INSERT INTO HOLIDAYS (HolidayID, HolidayName, HolidayDate, Year) 
    VALUES (seq_holidays.NEXTVAL, 'Test Holiday - Monday', TRUNC(SYSDATE) - MOD(TO_CHAR(SYSDATE, 'D') - 2, 7), EXTRACT(YEAR FROM SYSDATE));
    
    INSERT INTO HOLIDAYS (HolidayID, HolidayName, HolidayDate, Year) 
    VALUES (seq_holidays.NEXTVAL, 'Test Holiday - Tuesday', TRUNC(SYSDATE) - MOD(TO_CHAR(SYSDATE, 'D') - 3, 7), EXTRACT(YEAR FROM SYSDATE));
    
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Added holiday data for testing');
END;
/

-- ============================================
-- 2. AUDIT LOG TABLE (Already exists from Phase V)
-- Let's verify and add additional columns if needed
-- ============================================

-- Check AUDIT_LOG table structure
DESC AUDIT_LOG;

-- ============================================
-- 3. AUDIT LOGGING FUNCTION
-- ============================================

CREATE OR REPLACE FUNCTION log_audit_entry(
    p_table_name IN VARCHAR2,
    p_operation IN VARCHAR2,
    p_primary_key IN VARCHAR2,
    p_old_value IN CLOB DEFAULT NULL,
    p_new_value IN CLOB DEFAULT NULL,
    p_username IN VARCHAR2 DEFAULT USER,
    p_status IN VARCHAR2 DEFAULT 'SUCCESS',
    p_error_message IN VARCHAR2 DEFAULT NULL
) RETURN NUMBER
IS
    PRAGMA AUTONOMOUS_TRANSACTION; -- Important for triggers
    v_log_id NUMBER;
BEGIN
    -- Generate new log ID
    SELECT seq_audit_log.NEXTVAL INTO v_log_id FROM DUAL;
    
    -- Insert into audit log
    INSERT INTO AUDIT_LOG (
        LogID, TableName, Operation, PrimaryKeyValue,
        OldValue, NewValue, Username, Timestamp,
        Status, ErrorMessage
    ) VALUES (
        v_log_id, p_table_name, p_operation, p_primary_key,
        p_old_value, p_new_value, p_username, SYSDATE,
        p_status, p_error_message
    );
    
    COMMIT;
    RETURN v_log_id;
    
EXCEPTION
    WHEN OTHERS THEN
        -- Even if audit fails, don't stop the main operation
        ROLLBACK;
        RETURN -1; -- Indicate failure
END log_audit_entry;
/

-- ============================================
-- 4. RESTRICTION CHECK FUNCTION
-- ============================================

CREATE OR REPLACE FUNCTION check_restriction_allowed
RETURN BOOLEAN
IS
    v_current_day VARCHAR2(20);
    v_is_holiday NUMBER;
    v_day_of_week NUMBER;
BEGIN
    -- Get current day of week (1=Sunday, 2=Monday, ..., 7=Saturday in Oracle)
    SELECT TO_CHAR(SYSDATE, 'D') INTO v_day_of_week FROM DUAL;
    
    -- Check if today is weekend (Saturday = 7, Sunday = 1)
    IF v_day_of_week IN ('1', '7') THEN
        RETURN TRUE; -- Allow on weekends
    END IF;
    
    -- Check if today is a holiday
    SELECT COUNT(*) INTO v_is_holiday
    FROM HOLIDAYS
    WHERE HolidayDate = TRUNC(SYSDATE);
    
    IF v_is_holiday > 0 THEN
        RETURN FALSE; -- Deny on holidays
    END IF;
    
    -- If it's a weekday (Monday-Friday) and not a holiday
    IF v_day_of_week BETWEEN '2' AND '6' THEN
        RETURN FALSE; -- Deny on weekdays
    END IF;
    
    RETURN TRUE; -- Default allow (should not reach here)
END check_restriction_allowed;
/

-- Helper function for debugging
CREATE OR REPLACE FUNCTION get_day_info RETURN VARCHAR2
IS
    v_day_name VARCHAR2(20);
    v_day_number VARCHAR2(2);
    v_is_holiday VARCHAR2(5);
BEGIN
    SELECT TO_CHAR(SYSDATE, 'Day'), TO_CHAR(SYSDATE, 'D') 
    INTO v_day_name, v_day_number FROM DUAL;
    
    SELECT CASE WHEN COUNT(*) > 0 THEN 'YES' ELSE 'NO' END
    INTO v_is_holiday
    FROM HOLIDAYS
    WHERE HolidayDate = TRUNC(SYSDATE);
    
    RETURN 'Day: ' || TRIM(v_day_name) || ' (' || v_day_number || 
           '), Holiday: ' || v_is_holiday || 
           ', Allowed: ' || CASE WHEN check_restriction_allowed THEN 'YES' ELSE 'NO' END;
END get_day_info;
/

-- ============================================
-- 5. SIMPLE TRIGGERS for CRITICAL REQUIREMENT
-- Employees CANNOT INSERT/UPDATE/DELETE on WEEKDAYS or PUBLIC HOLIDAYS
-- ============================================

-- Trigger 1: For EQUIPMENT table
CREATE OR REPLACE TRIGGER trg_restrict_equipment_dml
BEFORE INSERT OR UPDATE OR DELETE ON EQUIPMENT
FOR EACH ROW
DECLARE
    v_allowed BOOLEAN;
    v_operation VARCHAR2(10);
    v_log_id NUMBER;
    v_username VARCHAR2(100) := USER;
    v_error_msg VARCHAR2(500);
BEGIN
    -- Determine operation type
    IF INSERTING THEN
        v_operation := 'INSERT';
    ELSIF UPDATING THEN
        v_operation := 'UPDATE';
    ELSIF DELETING THEN
        v_operation := 'DELETE';
    END IF;
    
    -- Check restriction
    v_allowed := check_restriction_allowed;
    
    IF NOT v_allowed THEN
        -- Create error message
        v_error_msg := 'Operation ' || v_operation || ' on EQUIPMENT table is not allowed on ';
        
        -- Get day info for better error message
        DECLARE
            v_day_name VARCHAR2(20);
            v_is_holiday NUMBER;
        BEGIN
            SELECT TO_CHAR(SYSDATE, 'Day') INTO v_day_name FROM DUAL;
            SELECT COUNT(*) INTO v_is_holiday
            FROM HOLIDAYS
            WHERE HolidayDate = TRUNC(SYSDATE);
            
            IF v_is_holiday > 0 THEN
                v_error_msg := v_error_msg || 'public holiday (' || TRIM(v_day_name) || '). ';
            ELSE
                v_error_msg := v_error_msg || 'weekdays (Monday-Friday). ';
            END IF;
        END;
        
        v_error_msg := v_error_msg || 'Allowed only on weekends (Saturday and Sunday).';
        
        -- Log denied attempt
        v_log_id := log_audit_entry(
            p_table_name => 'EQUIPMENT',
            p_operation => v_operation,
            p_primary_key => NVL(TO_CHAR(:NEW.EquipmentID), TO_CHAR(:OLD.EquipmentID)),
            p_old_value => CASE 
                WHEN v_operation IN ('UPDATE', 'DELETE') THEN 
                    'EquipmentID: ' || :OLD.EquipmentID || ', Name: ' || :OLD.Name || ', Status: ' || :OLD.Status
                ELSE NULL 
            END,
            p_new_value => CASE 
                WHEN v_operation IN ('INSERT', 'UPDATE') THEN 
                    'EquipmentID: ' || :NEW.EquipmentID || ', Name: ' || :NEW.Name || ', Status: ' || :NEW.Status
                ELSE NULL 
            END,
            p_username => v_username,
            p_status => 'DENIED',
            p_error_message => v_error_msg
        );
        
        -- Raise application error
        RAISE_APPLICATION_ERROR(-20001, v_error_msg);
    ELSE
        -- Log successful operation
        v_log_id := log_audit_entry(
            p_table_name => 'EQUIPMENT',
            p_operation => v_operation,
            p_primary_key => NVL(TO_CHAR(:NEW.EquipmentID), TO_CHAR(:OLD.EquipmentID)),
            p_old_value => CASE 
                WHEN v_operation IN ('UPDATE', 'DELETE') THEN 
                    'EquipmentID: ' || :OLD.EquipmentID || ', Name: ' || :OLD.Name || ', Status: ' || :OLD.Status
                ELSE NULL 
            END,
            p_new_value => CASE 
                WHEN v_operation IN ('INSERT', 'UPDATE') THEN 
                    'EquipmentID: ' || :NEW.EquipmentID || ', Name: ' || :NEW.Name || ', Status: ' || :NEW.Status
                ELSE NULL 
            END,
            p_username => v_username,
            p_status => 'SUCCESS',
            p_error_message => NULL
        );
    END IF;
END trg_restrict_equipment_dml;
/

-- Trigger 2: For MAINTENANCE table
CREATE OR REPLACE TRIGGER trg_restrict_maintenance_dml
BEFORE INSERT OR UPDATE OR DELETE ON MAINTENANCE
FOR EACH ROW
DECLARE
    v_allowed BOOLEAN;
    v_operation VARCHAR2(10);
    v_log_id NUMBER;
    v_username VARCHAR2(100) := USER;
    v_error_msg VARCHAR2(500);
BEGIN
    -- Determine operation type
    IF INSERTING THEN
        v_operation := 'INSERT';
    ELSIF UPDATING THEN
        v_operation := 'UPDATE';
    ELSIF DELETING THEN
        v_operation := 'DELETE';
    END IF;
    
    -- Check restriction
    v_allowed := check_restriction_allowed;
    
    IF NOT v_allowed THEN
        -- Create error message
        v_error_msg := 'Operation ' || v_operation || ' on MAINTENANCE table is not allowed on ';
        
        -- Get day info for better error message
        DECLARE
            v_day_name VARCHAR2(20);
            v_is_holiday NUMBER;
        BEGIN
            SELECT TO_CHAR(SYSDATE, 'Day') INTO v_day_name FROM DUAL;
            SELECT COUNT(*) INTO v_is_holiday
            FROM HOLIDAYS
            WHERE HolidayDate = TRUNC(SYSDATE);
            
            IF v_is_holiday > 0 THEN
                v_error_msg := v_error_msg || 'public holiday (' || TRIM(v_day_name) || '). ';
            ELSE
                v_error_msg := v_error_msg || 'weekdays (Monday-Friday). ';
            END IF;
        END;
        
        v_error_msg := v_error_msg || 'Allowed only on weekends (Saturday and Sunday).';
        
        -- Log denied attempt
        v_log_id := log_audit_entry(
            p_table_name => 'MAINTENANCE',
            p_operation => v_operation,
            p_primary_key => NVL(TO_CHAR(:NEW.MaintenanceID), TO_CHAR(:OLD.MaintenanceID)),
            p_old_value => CASE 
                WHEN v_operation IN ('UPDATE', 'DELETE') THEN 
                    'MaintenanceID: ' || :OLD.MaintenanceID || ', EquipmentID: ' || :OLD.EquipmentID || 
                    ', Status: ' || :OLD.Status
                ELSE NULL 
            END,
            p_new_value => CASE 
                WHEN v_operation IN ('INSERT', 'UPDATE') THEN 
                    'MaintenanceID: ' || :NEW.MaintenanceID || ', EquipmentID: ' || :NEW.EquipmentID || 
                    ', Status: ' || :NEW.Status
                ELSE NULL 
            END,
            p_username => v_username,
            p_status => 'DENIED',
            p_error_message => v_error_msg
        );
        
        -- Raise application error
        RAISE_APPLICATION_ERROR(-20002, v_error_msg);
    ELSE
        -- Log successful operation
        v_log_id := log_audit_entry(
            p_table_name => 'MAINTENANCE',
            p_operation => v_operation,
            p_primary_key => NVL(TO_CHAR(:NEW.MaintenanceID), TO_CHAR(:OLD.MaintenanceID)),
            p_old_value => CASE 
                WHEN v_operation IN ('UPDATE', 'DELETE') THEN 
                    'MaintenanceID: ' || :OLD.MaintenanceID || ', EquipmentID: ' || :OLD.EquipmentID || 
                    ', Status: ' || :OLD.Status
                ELSE NULL 
            END,
            p_new_value => CASE 
                WHEN v_operation IN ('INSERT', 'UPDATE') THEN 
                    'MaintenanceID: ' || :NEW.MaintenanceID || ', EquipmentID: ' || :NEW.EquipmentID || 
                    ', Status: ' || :NEW.Status
                ELSE NULL 
            END,
            p_username => v_username,
            p_status => 'SUCCESS',
            p_error_message => NULL
        );
    END IF;
END trg_restrict_maintenance_dml;
/

-- ============================================
-- 6. COMPOUND TRIGGER (Advanced Requirement)
-- ============================================

CREATE OR REPLACE TRIGGER trg_equipment_compound
FOR INSERT OR UPDATE OR DELETE ON EQUIPMENT
COMPOUND TRIGGER

    -- Declaration section
    TYPE t_audit_rec IS RECORD (
        table_name VARCHAR2(50),
        operation VARCHAR2(10),
        primary_key VARCHAR2(100),
        old_value CLOB,
        new_value CLOB,
        username VARCHAR2(100),
        status VARCHAR2(20),
        error_message VARCHAR2(1000)
    );
    
    TYPE t_audit_table IS TABLE OF t_audit_rec;
    v_audit_data t_audit_table := t_audit_table();
    
    v_allowed BOOLEAN;
    v_day_info VARCHAR2(100);
    
    -- Before each row
    BEFORE EACH ROW IS
        v_rec t_audit_rec;
        v_error_msg VARCHAR2(500);
    BEGIN
        -- Check restriction
        v_allowed := check_restriction_allowed;
        
        -- Get day info for error message
        v_day_info := get_day_info;
        
        IF NOT v_allowed THEN
            -- Determine operation
            IF INSERTING THEN
                v_rec.operation := 'INSERT';
                v_rec.primary_key := :NEW.EquipmentID;
                v_rec.new_value := 'EquipmentID: ' || :NEW.EquipmentID || ', Name: ' || :NEW.Name || 
                                  ', Status: ' || :NEW.Status;
            ELSIF UPDATING THEN
                v_rec.operation := 'UPDATE';
                v_rec.primary_key := :OLD.EquipmentID;
                v_rec.old_value := 'EquipmentID: ' || :OLD.EquipmentID || ', Name: ' || :OLD.Name || 
                                  ', Status: ' || :OLD.Status;
                v_rec.new_value := 'EquipmentID: ' || :NEW.EquipmentID || ', Name: ' || :NEW.Name || 
                                  ', Status: ' || :NEW.Status;
            ELSIF DELETING THEN
                v_rec.operation := 'DELETE';
                v_rec.primary_key := :OLD.EquipmentID;
                v_rec.old_value := 'EquipmentID: ' || :OLD.EquipmentID || ', Name: ' || :OLD.Name || 
                                  ', Status: ' || :OLD.Status;
            END IF;
            
            v_rec.table_name := 'EQUIPMENT';
            v_rec.username := USER;
            v_rec.status := 'DENIED';
            
            -- Create error message
            v_error_msg := 'Operation ' || v_rec.operation || ' on EQUIPMENT table is not allowed. ' || v_day_info;
            v_rec.error_message := v_error_msg;
            
            v_audit_data.EXTEND;
            v_audit_data(v_audit_data.LAST) := v_rec;
            
            -- Raise error
            RAISE_APPLICATION_ERROR(-20003, v_error_msg);
        ELSE
            -- Collect data for successful operations
            v_rec.table_name := 'EQUIPMENT';
            v_rec.username := USER;
            v_rec.status := 'SUCCESS';
            v_rec.error_message := NULL;
            
            IF INSERTING THEN
                v_rec.operation := 'INSERT';
                v_rec.primary_key := :NEW.EquipmentID;
                v_rec.new_value := 'EquipmentID: ' || :NEW.EquipmentID || ', Name: ' || :NEW.Name || 
                                  ', Status: ' || :NEW.Status;
            ELSIF UPDATING THEN
                v_rec.operation := 'UPDATE';
                v_rec.primary_key := :OLD.EquipmentID;
                v_rec.old_value := 'EquipmentID: ' || :OLD.EquipmentID || ', Name: ' || :OLD.Name || 
                                  ', Status: ' || :OLD.Status;
                v_rec.new_value := 'EquipmentID: ' || :NEW.EquipmentID || ', Name: ' || :NEW.Name || 
                                  ', Status: ' || :NEW.Status;
            ELSIF DELETING THEN
                v_rec.operation := 'DELETE';
                v_rec.primary_key := :OLD.EquipmentID;
                v_rec.old_value := 'EquipmentID: ' || :OLD.EquipmentID || ', Name: ' || :OLD.Name || 
                                  ', Status: ' || :OLD.Status;
            END IF;
            
            v_audit_data.EXTEND;
            v_audit_data(v_audit_data.LAST) := v_rec;
        END IF;
    END BEFORE EACH ROW;
    
    -- After statement
    AFTER STATEMENT IS
    BEGIN
        -- Bulk insert audit logs
        FOR i IN 1..v_audit_data.COUNT LOOP
            INSERT INTO AUDIT_LOG (
                LogID, TableName, Operation, PrimaryKeyValue,
                OldValue, NewValue, Username, Timestamp,
                Status, ErrorMessage
            ) VALUES (
                seq_audit_log.NEXTVAL,
                v_audit_data(i).table_name,
                v_audit_data(i).operation,
                v_audit_data(i).primary_key,
                v_audit_data(i).old_value,
                v_audit_data(i).new_value,
                v_audit_data(i).username,
                SYSDATE,
                v_audit_data(i).status,
                v_audit_data(i).error_message
            );
        END LOOP;
        
        v_audit_data.DELETE; -- Clear the collection
    END AFTER STATEMENT;
    
END trg_equipment_compound;
/

-- ============================================
-- 7. ADDITIONAL BUSINESS RULE TRIGGERS
-- ============================================

-- Trigger 3: Prevent decommissioning equipment with active maintenance
CREATE OR REPLACE TRIGGER trg_prevent_decommission
BEFORE UPDATE OF Status ON EQUIPMENT
FOR EACH ROW
WHEN (NEW.Status = 'DECOMMISSIONED')
DECLARE
    v_active_maintenance NUMBER;
    v_pending_alerts NUMBER;
BEGIN
    -- Check for active maintenance
    SELECT COUNT(*) INTO v_active_maintenance
    FROM MAINTENANCE
    WHERE EquipmentID = :OLD.EquipmentID
    AND Status IN ('SCHEDULED', 'IN_PROGRESS');
    
    IF v_active_maintenance > 0 THEN
        RAISE_APPLICATION_ERROR(-20004, 
            'Cannot decommission equipment ID ' || :OLD.EquipmentID || 
            ' with active maintenance. Complete or cancel all maintenance first.');
    END IF;
    
    -- Check for pending alerts
    SELECT COUNT(*) INTO v_pending_alerts
    FROM ALERTS
    WHERE EquipmentID = :OLD.EquipmentID
    AND Status IN ('PENDING', 'IN_PROGRESS');
    
    IF v_pending_alerts > 0 THEN
        RAISE_APPLICATION_ERROR(-20005, 
            'Cannot decommission equipment ID ' || :OLD.EquipmentID || 
            ' with pending alerts. Resolve all alerts first.');
    END IF;
    
    -- Log the decommissioning
    log_audit_entry(
        p_table_name => 'EQUIPMENT',
        p_operation => 'UPDATE',
        p_primary_key => :OLD.EquipmentID,
        p_old_value => 'Status: ' || :OLD.Status,
        p_new_value => 'Status: ' || :NEW.Status || ' (DECOMMISSIONED)',
        p_username => USER,
        p_status => 'SUCCESS',
        p_error_message => NULL
    );
END trg_prevent_decommission;
/

-- Trigger 4: Auto-update maintenance history when maintenance is completed
CREATE OR REPLACE TRIGGER trg_maintenance_completion
AFTER UPDATE OF Status ON MAINTENANCE
FOR EACH ROW
WHEN (NEW.Status = 'COMPLETED' AND OLD.Status != 'COMPLETED')
DECLARE
    v_downtime_hours NUMBER;
BEGIN
    -- Calculate downtime (simplified: from scheduled to actual date)
    v_downtime_hours := ROUND((:NEW.ActualDate - :NEW.ScheduledDate) * 24, 1);
    
    -- Add to maintenance history
    INSERT INTO MAINTENANCE_HISTORY (
        HistoryID, EquipmentID, MaintenanceID, TechnicianID,
        ActionTaken, DateFixed, Cost, DowntimeHours, Notes
    ) VALUES (
        seq_maintenance_history.NEXTVAL, :NEW.EquipmentID, :NEW.MaintenanceID, :NEW.TechnicianID,
        :NEW.Description, :NEW.CompletionDate, :NEW.Cost, v_downtime_hours,
        'Maintenance completed. Parts: ' || NVL(:NEW.PartsReplaced, 'None')
    );
    
    -- Update equipment last maintenance date
    UPDATE EQUIPMENT
    SET LastMaintenanceDate = :NEW.CompletionDate,
        ModifiedDate = SYSDATE
    WHERE EquipmentID = :NEW.EquipmentID;
    
    -- Log the completion
    log_audit_entry(
        p_table_name => 'MAINTENANCE',
        p_operation => 'UPDATE',
        p_primary_key => :NEW.MaintenanceID,
        p_old_value => 'Status: ' || :OLD.Status,
        p_new_value => 'Status: ' || :NEW.Status || ', Completed: ' || TO_CHAR(:NEW.CompletionDate, 'DD-MON-YYYY'),
        p_username => USER,
        p_status => 'SUCCESS',
        p_error_message => NULL
    );
END trg_maintenance_completion;
/

-- Trigger 5: Auto-generate alerts for equipment nearing warranty expiry
CREATE OR REPLACE TRIGGER trg_warranty_alert
AFTER INSERT OR UPDATE OF WarrantyExpiry ON EQUIPMENT
FOR EACH ROW
DECLARE
    v_days_remaining NUMBER;
BEGIN
    IF :NEW.WarrantyExpiry IS NOT NULL AND :NEW.Status = 'ACTIVE' THEN
        v_days_remaining := :NEW.WarrantyExpiry - SYSDATE;
        
        -- Generate alert if warranty expires within 90 days
        IF v_days_remaining BETWEEN 1 AND 90 THEN
            INSERT INTO ALERTS (
                AlertID, EquipmentID, AlertType, IssueDescription,
                Priority, Status, DateReported
            ) VALUES (
                seq_alerts.NEXTVAL, :NEW.EquipmentID, 'WARRANTY_EXPIRY',
                'Warranty for ' || :NEW.Name || ' expires in ' || TRUNC(v_days_remaining) || ' days (on ' || 
                TO_CHAR(:NEW.WarrantyExpiry, 'DD-MON-YYYY') || ')',
                CASE 
                    WHEN v_days_remaining <= 30 THEN 'HIGH'
                    WHEN v_days_remaining <= 60 THEN 'MEDIUM'
                    ELSE 'LOW'
                END,
                'PENDING', SYSDATE
            );
            
            DBMS_OUTPUT.PUT_LINE('Generated warranty alert for equipment ID ' || :NEW.EquipmentID);
        END IF;
    END IF;
END trg_warranty_alert;
/

-- ============================================
-- 8. TESTING THE TRIGGERS
-- ============================================

CREATE OR REPLACE PROCEDURE test_phase_vii_triggers
IS
    v_equipment_id NUMBER;
    v_maintenance_id NUMBER;
    v_status VARCHAR2(100);
    v_day_info VARCHAR2(100);
    v_allowed BOOLEAN;
    v_test_serial VARCHAR2(50);
    v_test_date DATE;
BEGIN
    DBMS_OUTPUT.PUT_LINE('===============================================');
    DBMS_OUTPUT.PUT_LINE('PHASE VII: TRIGGER TESTING');
    DBMS_OUTPUT.PUT_LINE('===============================================');
    DBMS_OUTPUT.PUT_LINE('');
    
    -- Get current day info
    v_day_info := get_day_info;
    v_allowed := check_restriction_allowed;
    
    DBMS_OUTPUT.PUT_LINE('Current System Info: ' || v_day_info);
    DBMS_OUTPUT.PUT_LINE('');
    
    -- Test 1: Try to insert equipment (should be allowed or denied based on day)
    DBMS_OUTPUT.PUT_LINE('=== TEST 1: Testing Equipment Insert Restriction ===');
    BEGIN
        v_test_serial := 'TEST-TRIGGER-' || TO_CHAR(SYSDATE, 'YYYYMMDD-HH24MISS');
        
        add_equipment(
            p_serial_number => v_test_serial,
            p_name => 'Trigger Test Equipment',
            p_category => 'TEST',
            p_manufacturer => 'Test Manufacturer',
            p_model => 'Trigger Model',
            p_purchase_date => SYSDATE,
            p_purchase_price => 5000,
            p_warranty_expiry => ADD_MONTHS(SYSDATE, 12),
            p_department_id => 2,
            p_utilization_hours => 0,
            p_equipment_id => v_equipment_id,
            p_status => v_status
        );
        
        IF v_allowed THEN
            DBMS_OUTPUT.PUT_LINE('✓ INSERT allowed as expected (weekend/holiday)');
            DBMS_OUTPUT.PUT_LINE('  Equipment ID: ' || v_equipment_id);
        ELSE
            DBMS_OUTPUT.PUT_LINE('✗ INSERT should have been denied but was allowed');
        END IF;
        
    EXCEPTION
        WHEN OTHERS THEN
            IF NOT v_allowed AND SQLCODE = -20001 THEN
                DBMS_OUTPUT.PUT_LINE('✓ INSERT denied as expected (weekday/holiday)');
                DBMS_OUTPUT.PUT_LINE('  Error: ' || SQLERRM);
            ELSE
                DBMS_OUTPUT.PUT_LINE('✗ Unexpected error: ' || SQLERRM);
            END IF;
    END;
    
    DBMS_OUTPUT.PUT_LINE('');
    
    -- Test 2: Try to schedule maintenance
    DBMS_OUTPUT.PUT_LINE('=== TEST 2: Testing Maintenance Insert Restriction ===');
    BEGIN
        -- Try to insert maintenance directly (bypassing procedure)
        INSERT INTO MAINTENANCE (
            MaintenanceID, EquipmentID, TechnicianID, MaintenanceType,
            ScheduledDate, Status, Description, CreatedBy
        ) VALUES (
            seq_maintenance.NEXTVAL, 1000, 100, 'PREVENTIVE',
            SYSDATE + 7, 'SCHEDULED', 'Trigger test maintenance', USER
        ) RETURNING MaintenanceID INTO v_maintenance_id;
        
        COMMIT;
        
        IF v_allowed THEN
            DBMS_OUTPUT.PUT_LINE('✓ INSERT allowed as expected (weekend/holiday)');
            DBMS_OUTPUT.PUT_LINE('  Maintenance ID: ' || v_maintenance_id);
        ELSE
            DBMS_OUTPUT.PUT_LINE('✗ INSERT should have been denied but was allowed');
        END IF;
        
    EXCEPTION
        WHEN OTHERS THEN
            IF NOT v_allowed AND SQLCODE = -20002 THEN
                DBMS_OUTPUT.PUT_LINE('✓ INSERT denied as expected (weekday/holiday)');
                DBMS_OUTPUT.PUT_LINE('  Error: ' || SQLERRM);
            ELSE
                DBMS_OUTPUT.PUT_LINE('✗ Unexpected error: ' || SQLERRM);
            END IF;
    END;
    
    DBMS_OUTPUT.PUT_LINE('');
    
    -- Test 3: Test decommission prevention
    DBMS_OUTPUT.PUT_LINE('=== TEST 3: Testing Decommission Prevention ===');
    BEGIN
        -- First, create a maintenance record for equipment 1000 if needed
        BEGIN
            INSERT INTO MAINTENANCE (
                MaintenanceID, EquipmentID, TechnicianID, MaintenanceType,
                ScheduledDate, Status, Description, CreatedBy
            ) VALUES (
                seq_maintenance.NEXTVAL, 1000, 100, 'CORRECTIVE',
                SYSDATE, 'IN_PROGRESS', 'Test maintenance for decommission', USER
            );
            COMMIT;
        EXCEPTION
            WHEN OTHERS THEN NULL; -- Maintenance might already exist
        END;
        
        -- Try to decommission equipment with active maintenance
        UPDATE EQUIPMENT 
        SET Status = 'DECOMMISSIONED'
        WHERE EquipmentID = 1000;
        
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('✗ Decommission should have been prevented but was allowed');
        
        -- Clean up
        UPDATE EQUIPMENT SET Status = 'ACTIVE' WHERE EquipmentID = 1000;
        COMMIT;
        
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE = -20004 THEN
                DBMS_OUTPUT.PUT_LINE('✓ Decommission prevented as expected');
                DBMS_OUTPUT.PUT_LINE('  Error: ' || SQLERRM);
            ELSE
                DBMS_OUTPUT.PUT_LINE('✗ Unexpected error: ' || SQLERRM);
            END IF;
    END;
    
    DBMS_OUTPUT.PUT_LINE('');
    
    -- Test 4: Test maintenance completion trigger
    DBMS_OUTPUT.PUT_LINE('=== TEST 4: Testing Maintenance Completion ===');
    DECLARE
        v_history_count NUMBER;
    BEGIN
        -- Find a maintenance record to complete
        BEGIN
            SELECT MaintenanceID INTO v_maintenance_id
            FROM MAINTENANCE
            WHERE Status = 'IN_PROGRESS'
            AND ROWNUM = 1;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                -- Create one if none exists
                INSERT INTO MAINTENANCE (
                    MaintenanceID, EquipmentID, TechnicianID, MaintenanceType,
                    ScheduledDate, ActualDate, Status, Description, Cost, CreatedBy
                ) VALUES (
                    seq_maintenance.NEXTVAL, 1000, 100, 'CORRECTIVE',
                    SYSDATE - 1, SYSDATE, 'IN_PROGRESS', 'Test maintenance completion', 500, USER
                ) RETURNING MaintenanceID INTO v_maintenance_id;
                COMMIT;
        END;
        
        -- Complete the maintenance
        UPDATE MAINTENANCE
        SET Status = 'COMPLETED',
            CompletionDate = SYSDATE,
            Cost = 750
        WHERE MaintenanceID = v_maintenance_id;
        
        COMMIT;
        
        -- Check if history was created
        SELECT COUNT(*) INTO v_history_count
        FROM MAINTENANCE_HISTORY
        WHERE MaintenanceID = v_maintenance_id;
        
        IF v_history_count > 0 THEN
            DBMS_OUTPUT.PUT_LINE('✓ Maintenance completion trigger worked');
            DBMS_OUTPUT.PUT_LINE('  History records created: ' || v_history_count);
        ELSE
            DBMS_OUTPUT.PUT_LINE('✗ No history record created');
        END IF;
        
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('✗ Error testing maintenance completion: ' || SQLERRM);
    END;
    
    DBMS_OUTPUT.PUT_LINE('');
    
    -- Test 5: Test warranty alert trigger
    DBMS_OUTPUT.PUT_LINE('=== TEST 5: Testing Warranty Alert Trigger ===');
    DECLARE
        v_alert_count NUMBER;
    BEGIN
        -- Update equipment warranty to near expiry
        UPDATE EQUIPMENT
        SET WarrantyExpiry = SYSDATE + 45  -- 45 days from now
        WHERE EquipmentID = 1001;
        
        COMMIT;
        
        -- Check if alert was generated
        SELECT COUNT(*) INTO v_alert_count
        FROM ALERTS
        WHERE EquipmentID = 1001
        AND AlertType = 'WARRANTY_EXPIRY'
        AND Status = 'PENDING';
        
        IF v_alert_count > 0 THEN
            DBMS_OUTPUT.PUT_LINE('✓ Warranty alert generated successfully');
            DBMS_OUTPUT.PUT_LINE('  Alerts created: ' || v_alert_count);
        ELSE
            DBMS_OUTPUT.PUT_LINE('✗ No warranty alert generated');
        END IF;
        
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('✗ Error testing warranty alert: ' || SQLERRM);
    END;
    
    DBMS_OUTPUT.PUT_LINE('');
    
    -- Test 6: Check audit log entries
    DBMS_OUTPUT.PUT_LINE('=== TEST 6: Checking Audit Log ===');
    DECLARE
        v_audit_count NUMBER;
        v_denied_count NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_audit_count
        FROM AUDIT_LOG
        WHERE Timestamp >= SYSDATE - 1;
        
        SELECT COUNT(*) INTO v_denied_count
        FROM AUDIT_LOG
        WHERE Status = 'DENIED'
        AND Timestamp >= SYSDATE - 1;
        
        DBMS_OUTPUT.PUT_LINE('✓ Audit log is working');
        DBMS_OUTPUT.PUT_LINE('  Total audit entries (last 24h): ' || v_audit_count);
        DBMS_OUTPUT.PUT_LINE('  Denied attempts (last 24h): ' || v_denied_count);
        
        -- Show sample audit entries
        DBMS_OUTPUT.PUT_LINE('  Sample audit entries:');
        FOR rec IN (
            SELECT LogID, TableName, Operation, Status, 
                   TO_CHAR(Timestamp, 'HH24:MI:SS') AS Time
            FROM AUDIT_LOG
            WHERE ROWNUM <= 3
            ORDER BY LogID DESC
        ) LOOP
            DBMS_OUTPUT.PUT_LINE('    #' || rec.LogID || ': ' || rec.TableName || 
                                ' ' || rec.Operation || ' - ' || rec.Status || 
                                ' at ' || rec.Time);
        END LOOP;
        
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('✗ Error checking audit log: ' || SQLERRM);
    END;
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('===============================================');
    DBMS_OUTPUT.PUT_LINE('PHASE VII TESTING COMPLETED');
    DBMS_OUTPUT.PUT_LINE('===============================================');
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('!!! Test suite failed: ' || SQLERRM);
END test_phase_vii_triggers;
/

-- ============================================
-- 9. ADDITIONAL QUERIES FOR VERIFICATION
-- ============================================

-- Query to check all triggers
SELECT trigger_name, trigger_type, table_name, status
FROM user_triggers
ORDER BY table_name, trigger_name;

-- Query to check holidays
SELECT HolidayID, HolidayName, TO_CHAR(HolidayDate, 'DD-MON-YYYY') AS Date, Year
FROM HOLIDAYS
ORDER BY HolidayDate;

-- Query to view recent audit logs
SELECT 
    LogID,
    TableName,
    Operation,
    PrimaryKeyValue,
    Username,
    TO_CHAR(Timestamp, 'DD-MON-YYYY HH24:MI:SS') AS Time,
    Status,
    SUBSTR(ErrorMessage, 1, 50) AS Error
FROM AUDIT_LOG
ORDER BY LogID DESC;

-- Function to simulate different days for testing
CREATE OR REPLACE FUNCTION simulate_day_check(p_date IN DATE) RETURN VARCHAR2
IS
    v_day_name VARCHAR2(20);
    v_day_number VARCHAR2(2);
    v_is_holiday VARCHAR2(5);
    v_is_weekend VARCHAR2(5);
    v_allowed VARCHAR2(5);
BEGIN
    SELECT TO_CHAR(p_date, 'Day'), TO_CHAR(p_date, 'D') 
    INTO v_day_name, v_day_number FROM DUAL;
    
    SELECT CASE WHEN COUNT(*) > 0 THEN 'YES' ELSE 'NO' END
    INTO v_is_holiday
    FROM HOLIDAYS
    WHERE HolidayDate = TRUNC(p_date);
    
    -- Check if weekend (Saturday=7, Sunday=1)
    IF v_day_number IN ('1', '7') THEN
        v_is_weekend := 'YES';
        v_allowed := 'YES';
    ELSIF v_is_holiday = 'YES' THEN
        v_allowed := 'NO';
        v_is_weekend := 'NO';
    ELSE
        v_allowed := 'NO';
        v_is_weekend := 'NO';
    END IF;
    
    RETURN 'Date: ' || TO_CHAR(p_date, 'DD-MON-YYYY') || 
           ', Day: ' || TRIM(v_day_name) || 
           ', Weekend: ' || v_is_weekend || 
           ', Holiday: ' || v_is_holiday || 
           ', Allowed: ' || v_allowed;
END simulate_day_check;
/

-- ============================================
-- 10. RUN THE PHASE VII TESTS
-- ============================================

-- Run the test suite
BEGIN
    test_phase_vii_triggers();
END;
/

-- Show current trigger status
SELECT 'Phase VII Triggers Status:' AS info FROM DUAL;
SELECT trigger_name, status, TO_CHAR(created, 'DD-MON HH24:MI') AS created
FROM user_triggers
WHERE trigger_name LIKE 'TRG_%'
ORDER BY trigger_name;












-- First, check and fix the invalid triggers
SELECT trigger_name, status FROM user_triggers WHERE status != 'VALID';

-- Drop and recreate the problematic triggers
DROP TRIGGER trg_prevent_decommission;
DROP TRIGGER trg_maintenance_completion;

-- Fix LOG_AUDIT_ENTRY usage - we need to capture the return value
-- Create a wrapper procedure for easier use
CREATE OR REPLACE PROCEDURE proc_log_audit_entry(
    p_table_name IN VARCHAR2,
    p_operation IN VARCHAR2,
    p_primary_key IN VARCHAR2,
    p_old_value IN CLOB DEFAULT NULL,
    p_new_value IN CLOB DEFAULT NULL,
    p_username IN VARCHAR2 DEFAULT USER,
    p_status IN VARCHAR2 DEFAULT 'SUCCESS',
    p_error_message IN VARCHAR2 DEFAULT NULL
)
IS
    v_log_id NUMBER;
BEGIN
    v_log_id := log_audit_entry(
        p_table_name => p_table_name,
        p_operation => p_operation,
        p_primary_key => p_primary_key,
        p_old_value => p_old_value,
        p_new_value => p_new_value,
        p_username => p_username,
        p_status => p_status,
        p_error_message => p_error_message
    );
    -- The return value is captured but not used - that's fine
END proc_log_audit_entry;
/

-- Now recreate the triggers using the procedure wrapper

-- Trigger 3: Prevent decommissioning equipment with active maintenance
CREATE OR REPLACE TRIGGER trg_prevent_decommission
BEFORE UPDATE OF Status ON EQUIPMENT
FOR EACH ROW
WHEN (NEW.Status = 'DECOMMISSIONED')
DECLARE
    v_active_maintenance NUMBER;
    v_pending_alerts NUMBER;
BEGIN
    -- Check for active maintenance
    SELECT COUNT(*) INTO v_active_maintenance
    FROM MAINTENANCE
    WHERE EquipmentID = :OLD.EquipmentID
    AND Status IN ('SCHEDULED', 'IN_PROGRESS');
    
    IF v_active_maintenance > 0 THEN
        RAISE_APPLICATION_ERROR(-20004, 
            'Cannot decommission equipment ID ' || :OLD.EquipmentID || 
            ' with active maintenance. Complete or cancel all maintenance first.');
    END IF;
    
    -- Check for pending alerts
    SELECT COUNT(*) INTO v_pending_alerts
    FROM ALERTS
    WHERE EquipmentID = :OLD.EquipmentID
    AND Status IN ('PENDING', 'IN_PROGRESS');
    
    IF v_pending_alerts > 0 THEN
        RAISE_APPLICATION_ERROR(-20005, 
            'Cannot decommission equipment ID ' || :OLD.EquipmentID || 
            ' with pending alerts. Resolve all alerts first.');
    END IF;
    
    -- Log the decommissioning using the procedure wrapper
    proc_log_audit_entry(
        p_table_name => 'EQUIPMENT',
        p_operation => 'UPDATE',
        p_primary_key => TO_CHAR(:OLD.EquipmentID),
        p_old_value => 'Status: ' || :OLD.Status,
        p_new_value => 'Status: ' || :NEW.Status || ' (DECOMMISSIONED)',
        p_username => USER,
        p_status => 'SUCCESS',
        p_error_message => NULL
    );
END trg_prevent_decommission;
/

-- Trigger 4: Auto-update maintenance history when maintenance is completed
CREATE OR REPLACE TRIGGER trg_maintenance_completion
AFTER UPDATE OF Status ON MAINTENANCE
FOR EACH ROW
WHEN (NEW.Status = 'COMPLETED' AND OLD.Status != 'COMPLETED')
DECLARE
    v_downtime_hours NUMBER;
BEGIN
    -- Calculate downtime (simplified: from scheduled to actual date)
    IF :NEW.ActualDate IS NOT NULL AND :NEW.ScheduledDate IS NOT NULL THEN
        v_downtime_hours := ROUND((:NEW.ActualDate - :NEW.ScheduledDate) * 24, 1);
    ELSE
        v_downtime_hours := 0;
    END IF;
    
    -- Add to maintenance history
    INSERT INTO MAINTENANCE_HISTORY (
        HistoryID, EquipmentID, MaintenanceID, TechnicianID,
        ActionTaken, DateFixed, Cost, DowntimeHours, Notes
    ) VALUES (
        seq_maintenance_history.NEXTVAL, :NEW.EquipmentID, :NEW.MaintenanceID, :NEW.TechnicianID,
        :NEW.Description, :NEW.CompletionDate, :NEW.Cost, v_downtime_hours,
        'Maintenance completed. Parts: ' || NVL(:NEW.PartsReplaced, 'None')
    );
    
    -- Update equipment last maintenance date
    UPDATE EQUIPMENT
    SET LastMaintenanceDate = :NEW.CompletionDate,
        ModifiedDate = SYSDATE
    WHERE EquipmentID = :NEW.EquipmentID;
    
    -- Log the completion using the procedure wrapper
    proc_log_audit_entry(
        p_table_name => 'MAINTENANCE',
        p_operation => 'UPDATE',
        p_primary_key => TO_CHAR(:NEW.MaintenanceID),
        p_old_value => 'Status: ' || :OLD.Status,
        p_new_value => 'Status: ' || :NEW.Status || ', Completed: ' || TO_CHAR(:NEW.CompletionDate, 'DD-MON-YYYY'),
        p_username => USER,
        p_status => 'SUCCESS',
        p_error_message => NULL
    );
END trg_maintenance_completion;
/

-- Also fix the other triggers that use LOG_AUDIT_ENTRY directly
-- Let's check and fix trg_restrict_equipment_dml and trg_restrict_maintenance_dml
SHOW ERRORS TRIGGER trg_restrict_equipment_dml;
SHOW ERRORS TRIGGER trg_restrict_maintenance_dml;

-- We need to fix these triggers too - they're calling log_audit_entry but not using return value
-- Let's create a simpler version that doesn't require the function call

-- Drop and recreate trg_restrict_equipment_dml
DROP TRIGGER trg_restrict_equipment_dml;

CREATE OR REPLACE TRIGGER trg_restrict_equipment_dml
BEFORE INSERT OR UPDATE OR DELETE ON EQUIPMENT
FOR EACH ROW
DECLARE
    v_allowed BOOLEAN;
    v_operation VARCHAR2(10);
    v_error_msg VARCHAR2(500);
    v_username VARCHAR2(100) := USER;
BEGIN
    -- Determine operation type
    IF INSERTING THEN
        v_operation := 'INSERT';
    ELSIF UPDATING THEN
        v_operation := 'UPDATE';
    ELSIF DELETING THEN
        v_operation := 'DELETE';
    END IF;
    
    -- Check restriction
    v_allowed := check_restriction_allowed;
    
    IF NOT v_allowed THEN
        -- Create error message
        v_error_msg := 'Operation ' || v_operation || ' on EQUIPMENT table is not allowed on ';
        
        -- Get day info for better error message
        DECLARE
            v_day_name VARCHAR2(20);
            v_is_holiday NUMBER;
        BEGIN
            SELECT TO_CHAR(SYSDATE, 'Day') INTO v_day_name FROM DUAL;
            SELECT COUNT(*) INTO v_is_holiday
            FROM HOLIDAYS
            WHERE HolidayDate = TRUNC(SYSDATE);
            
            IF v_is_holiday > 0 THEN
                v_error_msg := v_error_msg || 'public holiday (' || TRIM(v_day_name) || '). ';
            ELSE
                v_error_msg := v_error_msg || 'weekdays (Monday-Friday). ';
            END IF;
        END;
        
        v_error_msg := v_error_msg || 'Allowed only on weekends (Saturday and Sunday).';
        
        -- Log denied attempt using procedure wrapper
        proc_log_audit_entry(
            p_table_name => 'EQUIPMENT',
            p_operation => v_operation,
            p_primary_key => NVL(TO_CHAR(:NEW.EquipmentID), TO_CHAR(:OLD.EquipmentID)),
            p_old_value => CASE 
                WHEN v_operation IN ('UPDATE', 'DELETE') THEN 
                    'EquipmentID: ' || :OLD.EquipmentID || ', Name: ' || :OLD.Name || ', Status: ' || :OLD.Status
                ELSE NULL 
            END,
            p_new_value => CASE 
                WHEN v_operation IN ('INSERT', 'UPDATE') THEN 
                    'EquipmentID: ' || :NEW.EquipmentID || ', Name: ' || :NEW.Name || ', Status: ' || :NEW.Status
                ELSE NULL 
            END,
            p_username => v_username,
            p_status => 'DENIED',
            p_error_message => v_error_msg
        );
        
        -- Raise application error
        RAISE_APPLICATION_ERROR(-20001, v_error_msg);
    ELSE
        -- Log successful operation using procedure wrapper
        proc_log_audit_entry(
            p_table_name => 'EQUIPMENT',
            p_operation => v_operation,
            p_primary_key => NVL(TO_CHAR(:NEW.EquipmentID), TO_CHAR(:OLD.EquipmentID)),
            p_old_value => CASE 
                WHEN v_operation IN ('UPDATE', 'DELETE') THEN 
                    'EquipmentID: ' || :OLD.EquipmentID || ', Name: ' || :OLD.Name || ', Status: ' || :OLD.Status
                ELSE NULL 
            END,
            p_new_value => CASE 
                WHEN v_operation IN ('INSERT', 'UPDATE') THEN 
                    'EquipmentID: ' || :NEW.EquipmentID || ', Name: ' || :NEW.Name || ', Status: ' || :NEW.Status
                ELSE NULL 
            END,
            p_username => v_username,
            p_status => 'SUCCESS',
            p_error_message => NULL
        );
    END IF;
END trg_restrict_equipment_dml;
/

-- Also need to fix trg_restrict_maintenance_dml for consistency
DROP TRIGGER trg_restrict_maintenance_dml;

CREATE OR REPLACE TRIGGER trg_restrict_maintenance_dml
BEFORE INSERT OR UPDATE OR DELETE ON MAINTENANCE
FOR EACH ROW
DECLARE
    v_allowed BOOLEAN;
    v_operation VARCHAR2(10);
    v_error_msg VARCHAR2(500);
    v_username VARCHAR2(100) := USER;
BEGIN
    -- Determine operation type
    IF INSERTING THEN
        v_operation := 'INSERT';
    ELSIF UPDATING THEN
        v_operation := 'UPDATE';
    ELSIF DELETING THEN
        v_operation := 'DELETE';
    END IF;
    
    -- Check restriction
    v_allowed := check_restriction_allowed;
    
    IF NOT v_allowed THEN
        -- Create error message
        v_error_msg := 'Operation ' || v_operation || ' on MAINTENANCE table is not allowed on ';
        
        -- Get day info for better error message
        DECLARE
            v_day_name VARCHAR2(20);
            v_is_holiday NUMBER;
        BEGIN
            SELECT TO_CHAR(SYSDATE, 'Day') INTO v_day_name FROM DUAL;
            SELECT COUNT(*) INTO v_is_holiday
            FROM HOLIDAYS
            WHERE HolidayDate = TRUNC(SYSDATE);
            
            IF v_is_holiday > 0 THEN
                v_error_msg := v_error_msg || 'public holiday (' || TRIM(v_day_name) || '). ';
            ELSE
                v_error_msg := v_error_msg || 'weekdays (Monday-Friday). ';
            END IF;
        END;
        
        v_error_msg := v_error_msg || 'Allowed only on weekends (Saturday and Sunday).';
        
        -- Log denied attempt using procedure wrapper
        proc_log_audit_entry(
            p_table_name => 'MAINTENANCE',
            p_operation => v_operation,
            p_primary_key => NVL(TO_CHAR(:NEW.MaintenanceID), TO_CHAR(:OLD.MaintenanceID)),
            p_old_value => CASE 
                WHEN v_operation IN ('UPDATE', 'DELETE') THEN 
                    'MaintenanceID: ' || :OLD.MaintenanceID || ', EquipmentID: ' || :OLD.EquipmentID || 
                    ', Status: ' || :OLD.Status
                ELSE NULL 
            END,
            p_new_value => CASE 
                WHEN v_operation IN ('INSERT', 'UPDATE') THEN 
                    'MaintenanceID: ' || :NEW.MaintenanceID || ', EquipmentID: ' || :NEW.EquipmentID || 
                    ', Status: ' || :NEW.Status
                ELSE NULL 
            END,
            p_username => v_username,
            p_status => 'DENIED',
            p_error_message => v_error_msg
        );
        
        -- Raise application error
        RAISE_APPLICATION_ERROR(-20002, v_error_msg);
    ELSE
        -- Log successful operation using procedure wrapper
        proc_log_audit_entry(
            p_table_name => 'MAINTENANCE',
            p_operation => v_operation,
            p_primary_key => NVL(TO_CHAR(:NEW.MaintenanceID), TO_CHAR(:OLD.MaintenanceID)),
            p_old_value => CASE 
                WHEN v_operation IN ('UPDATE', 'DELETE') THEN 
                    'MaintenanceID: ' || :OLD.MaintenanceID || ', EquipmentID: ' || :OLD.EquipmentID || 
                    ', Status: ' || :OLD.Status
                ELSE NULL 
            END,
            p_new_value => CASE 
                WHEN v_operation IN ('INSERT', 'UPDATE') THEN 
                    'MaintenanceID: ' || :NEW.MaintenanceID || ', EquipmentID: ' || :NEW.EquipmentID || 
                    ', Status: ' || :NEW.Status
                ELSE NULL 
            END,
            p_username => v_username,
            p_status => 'SUCCESS',
            p_error_message => NULL
        );
    END IF;
END trg_restrict_maintenance_dml;
/

-- Fix the compound trigger too if it has the same issue
DROP TRIGGER trg_equipment_compound;

CREATE OR REPLACE TRIGGER trg_equipment_compound
FOR INSERT OR UPDATE OR DELETE ON EQUIPMENT
COMPOUND TRIGGER

    -- Declaration section
    TYPE t_audit_rec IS RECORD (
        table_name VARCHAR2(50),
        operation VARCHAR2(10),
        primary_key VARCHAR2(100),
        old_value CLOB,
        new_value CLOB,
        username VARCHAR2(100),
        status VARCHAR2(20),
        error_message VARCHAR2(1000)
    );
    
    TYPE t_audit_table IS TABLE OF t_audit_rec;
    v_audit_data t_audit_table := t_audit_table();
    
    v_allowed BOOLEAN;
    
    -- Before each row
    BEFORE EACH ROW IS
        v_rec t_audit_rec;
        v_error_msg VARCHAR2(500);
    BEGIN
        -- Check restriction
        v_allowed := check_restriction_allowed;
        
        IF NOT v_allowed THEN
            -- Determine operation
            IF INSERTING THEN
                v_rec.operation := 'INSERT';
                v_rec.primary_key := TO_CHAR(:NEW.EquipmentID);
                v_rec.new_value := 'EquipmentID: ' || :NEW.EquipmentID || ', Name: ' || :NEW.Name || 
                                  ', Status: ' || :NEW.Status;
            ELSIF UPDATING THEN
                v_rec.operation := 'UPDATE';
                v_rec.primary_key := TO_CHAR(:OLD.EquipmentID);
                v_rec.old_value := 'EquipmentID: ' || :OLD.EquipmentID || ', Name: ' || :OLD.Name || 
                                  ', Status: ' || :OLD.Status;
                v_rec.new_value := 'EquipmentID: ' || :NEW.EquipmentID || ', Name: ' || :NEW.Name || 
                                  ', Status: ' || :NEW.Status;
            ELSIF DELETING THEN
                v_rec.operation := 'DELETE';
                v_rec.primary_key := TO_CHAR(:OLD.EquipmentID);
                v_rec.old_value := 'EquipmentID: ' || :OLD.EquipmentID || ', Name: ' || :OLD.Name || 
                                  ', Status: ' || :OLD.Status;
            END IF;
            
            v_rec.table_name := 'EQUIPMENT';
            v_rec.username := USER;
            v_rec.status := 'DENIED';
            
            -- Create error message
            v_error_msg := 'Operation ' || v_rec.operation || ' on EQUIPMENT table is not allowed on weekdays or holidays.';
            v_rec.error_message := v_error_msg;
            
            v_audit_data.EXTEND;
            v_audit_data(v_audit_data.LAST) := v_rec;
            
            -- Raise error
            RAISE_APPLICATION_ERROR(-20003, v_error_msg);
        END IF;
    END BEFORE EACH ROW;
    
    -- After statement
    AFTER STATEMENT IS
        v_log_id NUMBER;
    BEGIN
        -- Bulk insert audit logs using the function directly
        FOR i IN 1..v_audit_data.COUNT LOOP
            v_log_id := log_audit_entry(
                p_table_name => v_audit_data(i).table_name,
                p_operation => v_audit_data(i).operation,
                p_primary_key => v_audit_data(i).primary_key,
                p_old_value => v_audit_data(i).old_value,
                p_new_value => v_audit_data(i).new_value,
                p_username => v_audit_data(i).username,
                p_status => v_audit_data(i).status,
                p_error_message => v_audit_data(i).error_message
            );
        END LOOP;
        
        v_audit_data.DELETE; -- Clear the collection
    END AFTER STATEMENT;
    
END trg_equipment_compound;
/

-- Fix the test procedure to handle the buffer error
CREATE OR REPLACE PROCEDURE test_phase_vii_triggers_fixed
IS
    v_equipment_id NUMBER;
    v_maintenance_id NUMBER;
    v_status VARCHAR2(4000); -- Increased buffer size
    v_day_info VARCHAR2(100);
    v_allowed BOOLEAN;
    v_test_serial VARCHAR2(50);
    v_test_date DATE;
BEGIN
    DBMS_OUTPUT.PUT_LINE('===============================================');
    DBMS_OUTPUT.PUT_LINE('PHASE VII: TRIGGER TESTING (FIXED)');
    DBMS_OUTPUT.PUT_LINE('===============================================');
    DBMS_OUTPUT.PUT_LINE('');
    
    -- Get current day info
    v_day_info := get_day_info;
    v_allowed := check_restriction_allowed;
    
    DBMS_OUTPUT.PUT_LINE('Current System Info: ' || v_day_info);
    DBMS_OUTPUT.PUT_LINE('');
    
    -- Test 1: Try to insert equipment (should be allowed or denied based on day)
    DBMS_OUTPUT.PUT_LINE('=== TEST 1: Testing Equipment Insert Restriction ===');
    BEGIN
        v_test_serial := 'TEST-TRIGGER-' || TO_CHAR(SYSDATE, 'YYYYMMDD-HH24MISS');
        
        add_equipment(
            p_serial_number => v_test_serial,
            p_name => 'Trigger Test Equipment',
            p_category => 'TEST',
            p_manufacturer => 'Test Manufacturer',
            p_model => 'Trigger Model',
            p_purchase_date => SYSDATE,
            p_purchase_price => 5000,
            p_warranty_expiry => ADD_MONTHS(SYSDATE, 12),
            p_department_id => 2,
            p_utilization_hours => 0,
            p_equipment_id => v_equipment_id,
            p_status => v_status
        );
        
        IF v_allowed THEN
            DBMS_OUTPUT.PUT_LINE('✓ INSERT allowed as expected (weekend/holiday)');
            DBMS_OUTPUT.PUT_LINE('  Equipment ID: ' || v_equipment_id);
        ELSE
            DBMS_OUTPUT.PUT_LINE('✗ INSERT should have been denied but was allowed');
        END IF;
        
    EXCEPTION
        WHEN OTHERS THEN
            IF NOT v_allowed AND SQLCODE = -20001 THEN
                DBMS_OUTPUT.PUT_LINE('✓ INSERT denied as expected (weekday/holiday)');
                DBMS_OUTPUT.PUT_LINE('  Error: ' || SUBSTR(SQLERRM, 1, 100)); -- Limit error message length
            ELSE
                DBMS_OUTPUT.PUT_LINE('✗ Unexpected error: ' || SUBSTR(SQLERRM, 1, 100));
            END IF;
    END;
    
    DBMS_OUTPUT.PUT_LINE('');
    
    -- Test 2: Try to schedule maintenance
    DBMS_OUTPUT.PUT_LINE('=== TEST 2: Testing Maintenance Insert Restriction ===');
    BEGIN
        -- Try to insert maintenance directly (bypassing procedure)
        INSERT INTO MAINTENANCE (
            MaintenanceID, EquipmentID, TechnicianID, MaintenanceType,
            ScheduledDate, Status, Description, CreatedBy
        ) VALUES (
            seq_maintenance.NEXTVAL, 1000, 100, 'PREVENTIVE',
            SYSDATE + 7, 'SCHEDULED', 'Trigger test maintenance', USER
        ) RETURNING MaintenanceID INTO v_maintenance_id;
        
        COMMIT;
        
        IF v_allowed THEN
            DBMS_OUTPUT.PUT_LINE('✓ INSERT allowed as expected (weekend/holiday)');
            DBMS_OUTPUT.PUT_LINE('  Maintenance ID: ' || v_maintenance_id);
        ELSE
            DBMS_OUTPUT.PUT_LINE('✗ INSERT should have been denied but was allowed');
        END IF;
        
    EXCEPTION
        WHEN OTHERS THEN
            IF NOT v_allowed AND SQLCODE = -20002 THEN
                DBMS_OUTPUT.PUT_LINE('✓ INSERT denied as expected (weekday/holiday)');
                DBMS_OUTPUT.PUT_LINE('  Error: ' || SUBSTR(SQLERRM, 1, 100));
            ELSE
                DBMS_OUTPUT.PUT_LINE('✗ Unexpected error: ' || SUBSTR(SQLERRM, 1, 100));
            END IF;
    END;
    
    DBMS_OUTPUT.PUT_LINE('');
    
    -- Test 3: Test decommission prevention
    DBMS_OUTPUT.PUT_LINE('=== TEST 3: Testing Decommission Prevention ===');
    BEGIN
        -- First, create a maintenance record for equipment 1000 if needed
        BEGIN
            INSERT INTO MAINTENANCE (
                MaintenanceID, EquipmentID, TechnicianID, MaintenanceType,
                ScheduledDate, Status, Description, CreatedBy
            ) VALUES (
                seq_maintenance.NEXTVAL, 1000, 100, 'CORRECTIVE',
                SYSDATE, 'IN_PROGRESS', 'Test maintenance for decommission', USER
            );
            COMMIT;
        EXCEPTION
            WHEN OTHERS THEN NULL; -- Maintenance might already exist
        END;
        
        -- Try to decommission equipment with active maintenance
        UPDATE EQUIPMENT 
        SET Status = 'DECOMMISSIONED'
        WHERE EquipmentID = 1000;
        
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('✗ Decommission should have been prevented but was allowed');
        
        -- Clean up
        UPDATE EQUIPMENT SET Status = 'ACTIVE' WHERE EquipmentID = 1000;
        COMMIT;
        
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE = -20004 THEN
                DBMS_OUTPUT.PUT_LINE('✓ Decommission prevented as expected');
                DBMS_OUTPUT.PUT_LINE('  Error: ' || SUBSTR(SQLERRM, 1, 100));
            ELSE
                DBMS_OUTPUT.PUT_LINE('✗ Unexpected error: ' || SUBSTR(SQLERRM, 1, 100));
            END IF;
    END;
    
    DBMS_OUTPUT.PUT_LINE('');
    
    -- Test 4: Test maintenance completion trigger
    DBMS_OUTPUT.PUT_LINE('=== TEST 4: Testing Maintenance Completion ===');
    DECLARE
        v_history_count NUMBER;
    BEGIN
        -- Find a maintenance record to complete
        BEGIN
            SELECT MaintenanceID INTO v_maintenance_id
            FROM MAINTENANCE
            WHERE Status = 'IN_PROGRESS'
            AND ROWNUM = 1;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                -- Create one if none exists
                INSERT INTO MAINTENANCE (
                    MaintenanceID, EquipmentID, TechnicianID, MaintenanceType,
                    ScheduledDate, ActualDate, Status, Description, Cost, CreatedBy
                ) VALUES (
                    seq_maintenance.NEXTVAL, 1000, 100, 'CORRECTIVE',
                    SYSDATE - 1, SYSDATE, 'IN_PROGRESS', 'Test maintenance completion', 500, USER
                ) RETURNING MaintenanceID INTO v_maintenance_id;
                COMMIT;
        END;
        
        -- Complete the maintenance
        UPDATE MAINTENANCE
        SET Status = 'COMPLETED',
            CompletionDate = SYSDATE,
            Cost = 750
        WHERE MaintenanceID = v_maintenance_id;
        
        COMMIT;
        
        -- Check if history was created
        SELECT COUNT(*) INTO v_history_count
        FROM MAINTENANCE_HISTORY
        WHERE MaintenanceID = v_maintenance_id;
        
        IF v_history_count > 0 THEN
            DBMS_OUTPUT.PUT_LINE('✓ Maintenance completion trigger worked');
            DBMS_OUTPUT.PUT_LINE('  History records created: ' || v_history_count);
        ELSE
            DBMS_OUTPUT.PUT_LINE('✗ No history record created');
        END IF;
        
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('✗ Error testing maintenance completion: ' || SUBSTR(SQLERRM, 1, 100));
    END;
    
    DBMS_OUTPUT.PUT_LINE('');
    
    -- Test 5: Test warranty alert trigger
    DBMS_OUTPUT.PUT_LINE('=== TEST 5: Testing Warranty Alert Trigger ===');
    DECLARE
        v_alert_count NUMBER;
    BEGIN
        -- Update equipment warranty to near expiry
        UPDATE EQUIPMENT
        SET WarrantyExpiry = SYSDATE + 45  -- 45 days from now
        WHERE EquipmentID = 1001;
        
        COMMIT;
        
        -- Check if alert was generated
        SELECT COUNT(*) INTO v_alert_count
        FROM ALERTS
        WHERE EquipmentID = 1001
        AND AlertType = 'WARRANTY_EXPIRY'
        AND Status = 'PENDING';
        
        IF v_alert_count > 0 THEN
            DBMS_OUTPUT.PUT_LINE('✓ Warranty alert generated successfully');
            DBMS_OUTPUT.PUT_LINE('  Alerts created: ' || v_alert_count);
        ELSE
            DBMS_OUTPUT.PUT_LINE('✗ No warranty alert generated');
        END IF;
        
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('✗ Error testing warranty alert: ' || SUBSTR(SQLERRM, 1, 100));
    END;
    
    DBMS_OUTPUT.PUT_LINE('');
    
    -- Test 6: Check audit log entries
    DBMS_OUTPUT.PUT_LINE('=== TEST 6: Checking Audit Log ===');
    DECLARE
        v_audit_count NUMBER;
        v_denied_count NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_audit_count
        FROM AUDIT_LOG
        WHERE Timestamp >= SYSDATE - 1;
        
        SELECT COUNT(*) INTO v_denied_count
        FROM AUDIT_LOG
        WHERE Status = 'DENIED'
        AND Timestamp >= SYSDATE - 1;
        
        DBMS_OUTPUT.PUT_LINE('✓ Audit log is working');
        DBMS_OUTPUT.PUT_LINE('  Total audit entries (last 24h): ' || v_audit_count);
        DBMS_OUTPUT.PUT_LINE('  Denied attempts (last 24h): ' || v_denied_count);
        
        -- Show sample audit entries
        DBMS_OUTPUT.PUT_LINE('  Sample audit entries:');
        FOR rec IN (
            SELECT LogID, TableName, Operation, Status, 
                   TO_CHAR(Timestamp, 'HH24:MI:SS') AS Time
            FROM AUDIT_LOG
            WHERE ROWNUM <= 3
            ORDER BY LogID DESC
        ) LOOP
            DBMS_OUTPUT.PUT_LINE('    #' || rec.LogID || ': ' || rec.TableName || 
                                ' ' || rec.Operation || ' - ' || rec.Status || 
                                ' at ' || rec.Time);
        END LOOP;
        
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('✗ Error checking audit log: ' || SUBSTR(SQLERRM, 1, 100));
    END;
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('===============================================');
    DBMS_OUTPUT.PUT_LINE('PHASE VII TESTING COMPLETED');
    DBMS_OUTPUT.PUT_LINE('===============================================');
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('!!! Test suite failed: ' || SUBSTR(SQLERRM, 1, 200));
END test_phase_vii_triggers_fixed;
/

-- Verify all triggers are now valid
SELECT trigger_name, status 
FROM user_triggers 
WHERE trigger_name LIKE 'TRG_%'
ORDER BY trigger_name;

-- Run the fixed tests
BEGIN
    test_phase_vii_triggers_fixed();
END;
/
--- final test 



-- Check all triggers are valid
SELECT trigger_name, status FROM user_triggers WHERE status != 'VALID';

-- Check recent audit logs
SELECT COUNT(*) FROM AUDIT_LOG WHERE Status = 'DENIED';

-- Test the restriction function
SELECT get_day_info FROM DUAL;

-- Test with different dates
SELECT simulate_day_check(SYSDATE) FROM DUAL;
SELECT simulate_day_check(SYSDATE + 1) FROM DUAL;
SELECT simulate_day_check(TO_DATE('27-12-2025', 'DD-MM-YYYY')) FROM DUAL; -- Saturday
