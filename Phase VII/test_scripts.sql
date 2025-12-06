
-- Set output
SET SERVEROUTPUT ON

-- Insert HOLIDAY for testing
INSERT INTO HOLIDAYS VALUES (TO_DATE('2025-12-25','YYYY-MM-DD'),'Christmas');

-- Test INSERT on weekday (should fail)
BEGIN
    audit_pkg.v_test_date := TO_DATE('2025-12-04','YYYY-MM-DD'); -- Thursday
    INSERT INTO Equipment (EquipmentID, Name, Category, PurchaseDate, WarrantyExpiry, Status, DepartmentID)
    VALUES (9001,'Weekday Test','Test',SYSDATE,SYSDATE+365,'Working',1);
EXCEPTION WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Expected failure on weekday: ' || SQLERRM);
END;

-- Test INSERT on weekend (should succeed)
BEGIN
    audit_pkg.v_test_date := TO_DATE('2025-12-06','YYYY-MM-DD'); -- Saturday
    INSERT INTO Equipment (EquipmentID, Name, Category, PurchaseDate, WarrantyExpiry, Status, DepartmentID)
    VALUES (9002,'Weekend Test','Test',SYSDATE,SYSDATE+365,'Working',1);
    DBMS_OUTPUT.PUT_LINE('Insert succeeded on weekend.');
END;

-- Test INSERT on holiday (should fail)
BEGIN
    audit_pkg.v_test_date := TO_DATE('2025-12-25','YYYY-MM-DD'); -- Christmas
    INSERT INTO Equipment (EquipmentID, Name, Category, PurchaseDate, WarrantyExpiry, Status, DepartmentID)
    VALUES (9003,'Holiday Test','Test',SYSDATE,SYSDATE+365,'Working',1);
EXCEPTION WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Expected failure on holiday: ' || SQLERRM);
END;

-- Check Audit Log
SELECT * FROM AUDIT_LOG ORDER BY AUDIT_ID DESC;
