
-- Equipment Trigger
CREATE OR REPLACE TRIGGER trg_equipment_audit
BEFORE INSERT OR UPDATE OR DELETE ON Equipment
FOR EACH ROW
DECLARE
    v_res VARCHAR2(4000);
    v_allowed CHAR(1);
    v_reason VARCHAR2(4000);
BEGIN
    v_res := audit_pkg.is_dml_allowed;
    IF SUBSTR(v_res,1,2) = 'Y:' THEN
        v_allowed := 'Y';
        v_reason := SUBSTR(v_res,3);
    ELSE
        v_allowed := 'N';
        v_reason := SUBSTR(v_res,3);
    END IF;

    audit_pkg.log_audit(USER, CASE WHEN INSERTING THEN 'INSERT'
                                   WHEN UPDATING THEN 'UPDATE'
                                   ELSE 'DELETE' END,
                        'Equipment', 'ID='||NVL(:NEW.EquipmentID,:OLD.EquipmentID),
                        v_allowed, v_reason, NULL);

    IF v_allowed='N' THEN
        RAISE_APPLICATION_ERROR(-20001,'DML blocked: '||v_reason);
    END IF;
END;
/
