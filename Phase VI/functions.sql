
-- =========================================
-- HMMS Phase VI: FUNCTIONS
-- =========================================

-- Total maintenance cost for equipment
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

-- Validate equipment existence
CREATE OR REPLACE FUNCTION is_equipment_exists(
    p_equipment_id NUMBER
) RETURN BOOLEAN AS
    v_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_count FROM Equipment WHERE EquipmentID = p_equipment_id;
    RETURN (v_count > 0);
END;
/

-- Get technician specialty
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
