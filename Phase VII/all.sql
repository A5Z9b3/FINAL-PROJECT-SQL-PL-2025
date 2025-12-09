-- ------------------------------------------------------------
-- PLSQL_CAPSTONE_PROJECT - Table Creation, Data Insertion,
-- Procedures, Functions, Package, and Validation Queries
-- Oracle-compatible SQL
-- Created: 2025-11-16 (adapt as needed)
-- ------------------------------------------------------------
SET SERVEROUTPUT ON SIZE 1000000;
-- Optional: run as a user with adequate privileges, or create a dedicated schema

-- ===========================
-- 1. Clean up existing (safe re-run)
-- ===========================
BEGIN
  EXECUTE IMMEDIATE 'DROP TABLE ALERTS PURGE';
EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN
  EXECUTE IMMEDIATE 'DROP TABLE MAINTENANCE_HISTORY PURGE';
EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN
  EXECUTE IMMEDIATE 'DROP TABLE MAINTENANCE PURGE';
EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN
  EXECUTE IMMEDIATE 'DROP TABLE EQUIPMENT PURGE';
EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN
  EXECUTE IMMEDIATE 'DROP TABLE TECHNICIANS PURGE';
EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN
  EXECUTE IMMEDIATE 'DROP TABLE DEPARTMENTS PURGE';
EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN
  EXECUTE IMMEDIATE 'DROP SEQUENCE seq_deptid';
EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN
  EXECUTE IMMEDIATE 'DROP SEQUENCE seq_equipid';
EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN
  EXECUTE IMMEDIATE 'DROP SEQUENCE seq_techid';
EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN
  EXECUTE IMMEDIATE 'DROP SEQUENCE seq_maintid';
EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN
  EXECUTE IMMEDIATE 'DROP SEQUENCE seq_histid';
EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN
  EXECUTE IMMEDIATE 'DROP SEQUENCE seq_alertid';
EXCEPTION WHEN OTHERS THEN NULL; END;
/

-- ===========================
-- 2. Sequences for primary keys
-- ===========================
CREATE SEQUENCE seq_deptid START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_equipid START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_techid START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_maintid START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_histid START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_alertid START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;

-- ===========================
-- 3. Table creation
-- ===========================
-- Departments table
CREATE TABLE DEPARTMENTS (
  DEPTID       NUMBER PRIMARY KEY,
  DEPTNAME     VARCHAR2(100) NOT NULL UNIQUE,
  LOCATION     VARCHAR2(150),
  HEADOFDEPT   VARCHAR2(120)
);

-- Technicians table
CREATE TABLE TECHNICIANS (
  TECHID       NUMBER PRIMARY KEY,
  FULLNAME     VARCHAR2(120) NOT NULL,
  CONTACT      VARCHAR2(50),
  SPECIALTY    VARCHAR2(100),
  HIRE_DATE    DATE DEFAULT SYSDATE,
  CONSTRAINT chk_contact_format CHECK (LENGTH(NVL(CONTACT,'0')) <= 50)
);

-- Equipment table
CREATE TABLE EQUIPMENT (
  EQUIPMENTID       NUMBER PRIMARY KEY,
  NAME              VARCHAR2(150) NOT NULL,
  CATEGORY          VARCHAR2(100) NOT NULL,
  PURCHASEDATE      DATE,
  WARRANTYEXPIRY    DATE,
  STATUS            VARCHAR2(30) DEFAULT 'Operational' NOT NULL,
  DEPARTMENTID      NUMBER,
  CONSTRAINT fk_equ_dept FOREIGN KEY (DEPARTMENTID) REFERENCES DEPARTMENTS(DEPTID)
    ON DELETE SET NULL,
  CONSTRAINT chk_status CHECK (STATUS IN ('Operational','Under Maintenance','Out of Service','Decommissioned'))
);

-- Maintenance table (planned / performed maintenance records)
CREATE TABLE MAINTENANCE (
  MAINTENANCEID   NUMBER PRIMARY KEY,
  EQUIPMENTID     NUMBER NOT NULL,
  TECHNICIANID    NUMBER,
  MAINTENANCEDATE DATE DEFAULT SYSDATE NOT NULL,
  COST            NUMBER(12,2) DEFAULT 0,
  DESCRIPTION     VARCHAR2(4000),
  CONSTRAINT fk_maint_equip FOREIGN KEY (EQUIPMENTID) REFERENCES EQUIPMENT(EQUIPMENTID)
    ON DELETE CASCADE,
  CONSTRAINT fk_maint_tech FOREIGN KEY (TECHNICIANID) REFERENCES TECHNICIANS(TECHID)
);

-- Maintenance history (detailed history of fixes)
CREATE TABLE MAINTENANCE_HISTORY (
  HISTORYID     NUMBER PRIMARY KEY,
  EQUIPMENTID    NUMBER NOT NULL,
  TECHNICIANID   NUMBER,
  ACTIONTAKEN    VARCHAR2(2000),
  DATEFIXED      DATE,
  COST           NUMBER(12,2) DEFAULT 0,
  CONSTRAINT fk_hist_equip FOREIGN KEY (EQUIPMENTID) REFERENCES EQUIPMENT(EQUIPMENTID)
    ON DELETE CASCADE,
  CONSTRAINT fk_hist_tech FOREIGN KEY (TECHNICIANID) REFERENCES TECHNICIANS(TECHID)
);

-- Alerts table
CREATE TABLE ALERTS (
  ALERTID         NUMBER PRIMARY KEY,
  EQUIPMENTID     NUMBER NOT NULL,
  ISSUEDESCRIPTION VARCHAR2(2000) NOT NULL,
  DATEREPORTED    DATE DEFAULT SYSDATE NOT NULL,
  STATUS          VARCHAR2(30) DEFAULT 'Open' NOT NULL,
  CONSTRAINT fk_alert_equip FOREIGN KEY (EQUIPMENTID) REFERENCES EQUIPMENT(EQUIPMENTID)
    ON DELETE CASCADE,
  CONSTRAINT chk_alert_status CHECK (STATUS IN ('Open','Investigating','Resolved','Dismissed'))
);

-- ===========================
-- 4. Indexes (non-unique)
-- ===========================
CREATE INDEX idx_equip_category ON EQUIPMENT(CATEGORY);
CREATE INDEX idx_equip_status ON EQUIPMENT(STATUS);
CREATE INDEX idx_maint_date ON MAINTENANCE(MAINTENANCEDATE);
CREATE INDEX idx_alert_status ON ALERTS(STATUS);
CREATE INDEX idx_tech_specialty ON TECHNICIANS(SPECIALTY);

-- ===========================
-- 5. Referential integrity samples (done above with FK)
-- ===========================

-- ===========================
-- 6. Bulk data insertion using PL/SQL (realistic test data)
--    Adjust counts by changing constants below
-- ===========================
DECLARE
  -- counts: change these to scale dataset
  NUM_DEPTS CONSTANT PLS_INTEGER := 10;      -- departments
  NUM_TECHS CONSTANT PLS_INTEGER := 60;      -- technicians
  NUM_EQUIP CONSTANT PLS_INTEGER := 300;     -- equipment (meets 100–500)
  NUM_MAINT CONSTANT PLS_INTEGER := 800;     -- maintenance records
  NUM_HIST  CONSTANT PLS_INTEGER := 700;     -- maintenance history
  NUM_ALERTS CONSTANT PLS_INTEGER := 350;    -- alerts

  v_deptid NUMBER;
  v_equipid NUMBER;
  v_techid NUMBER;
  v_date DATE;
  v_warranty DATE;
  v_cost NUMBER;
  v_cat_list SYS.OdciVarchar2List := SYS.OdciVarchar2List(
    'Imaging','Lab','IT','HVAC','Power','Surgical','Furniture','Transport','Diagnostics','Other'
  );
  v_status_list SYS.OdciVarchar2List := SYS.OdciVarchar2List(
    'Operational','Under Maintenance','Out of Service','Decommissioned'
  );
  v_alert_status SYS.OdciVarchar2List := SYS.OdciVarchar2List('Open','Investigating','Resolved','Dismissed');

  CURSOR rand_names IS
    SELECT column_value AS name FROM TABLE(SYS.ODCIVARCHAR2LIST(
      'Alpha','Beta','Gamma','Delta','Epsilon','Zeta','Eta','Theta','Iota','Kappa',
      'Lamda','Mu','Nu','Xi','Omicron','Pi','Rho','Sigma','Tau','Upsilon','Phi','Chi','Psi','Omega'
    ));
BEGIN
  DBMS_OUTPUT.PUT_LINE('Inserting departments...');
  FOR i IN 1..NUM_DEPTS LOOP
    v_deptid := seq_deptid.NEXTVAL;
    INSERT INTO DEPARTMENTS(DEPTID, DEPTNAME, LOCATION, HEADOFDEPT)
    VALUES(
      v_deptid,
      'Department ' || TO_CHAR(v_deptid),
      'Building ' || CHR(64 + MOD(v_deptid, 26) + 1) || ', Floor ' || TO_CHAR(1 + MOD(v_deptid,5)),
      'Dr. ' || CASE MOD(v_deptid,5) WHEN 0 THEN 'A. Mugenzi' WHEN 1 THEN 'B. Nshimiyimana' WHEN 2 THEN 'C. Uwase' WHEN 3 THEN 'D. Habimana' ELSE 'E. Kayitesi' END
    );
  END LOOP;

  DBMS_OUTPUT.PUT_LINE('Inserting technicians...');
  FOR i IN 1..NUM_TECHS LOOP
    v_techid := seq_techid.NEXTVAL;
    INSERT INTO TECHNICIANS(TECHID, FULLNAME, CONTACT, SPECIALTY, HIRE_DATE)
    VALUES(
      v_techid,
      CASE WHEN MOD(v_techid,5)=0 THEN 'John '||v_techid WHEN MOD(v_techid,5)=1 THEN 'Jane '||v_techid WHEN MOD(v_techid,5)=2 THEN 'Sam '||v_techid WHEN MOD(v_techid,5)=3 THEN 'Lina '||v_techid ELSE 'Alex '||v_techid END,
      CASE WHEN MOD(v_techid,7)=0 THEN NULL ELSE '+2507' || LPAD(TRUNC(DBMS_RANDOM.VALUE(100000,999999)),6,'0') END,
      CASE MOD(v_techid,6) WHEN 0 THEN 'Electrical' WHEN 1 THEN 'Mechanical' WHEN 2 THEN 'Biomedical' WHEN 3 THEN 'IT' WHEN 4 THEN 'HVAC' ELSE 'General' END,
      TRUNC(SYSDATE - DBMS_RANDOM.VALUE(30,2000))
    );
  END LOOP;

  DBMS_OUTPUT.PUT_LINE('Inserting equipment...');
  FOR i IN 1..NUM_EQUIP LOOP
    v_equipid := seq_equipid.NEXTVAL;
    v_date := TRUNC(SYSDATE - DBMS_RANDOM.VALUE(30, 3650)); -- purchase date 1 month to 10 years ago
    v_warranty := CASE WHEN MOD(i,7)=0 THEN NULL ELSE ADD_MONTHS(v_date, 12 * (2 + MOD(i,5))) END;
    INSERT INTO EQUIPMENT(EQUIPMENTID, NAME, CATEGORY, PURCHASEDATE, WARRANTYEXPIRY, STATUS, DEPARTMENTID)
    VALUES(
      v_equipid,
      CASE
        WHEN MOD(i,10)=0 THEN 'Ultrasound ' || v_equipid
        WHEN MOD(i,10)=1 THEN 'X-Ray ' || v_equipid
        WHEN MOD(i,10)=2 THEN 'ECG ' || v_equipid
        WHEN MOD(i,10)=3 THEN 'Ventilator ' || v_equipid
        WHEN MOD(i,10)=4 THEN 'Microscope ' || v_equipid
        WHEN MOD(i,10)=5 THEN 'Server ' || v_equipid
        WHEN MOD(i,10)=6 THEN 'AC Unit ' || v_equipid
        WHEN MOD(i,10)=7 THEN 'Generator ' || v_equipid
        WHEN MOD(i,10)=8 THEN 'Infusion Pump ' || v_equipid
        ELSE 'Misc ' || v_equipid
      END,
      v_cat_list(1 + MOD(i, v_cat_list.COUNT)),
      v_date,
      v_warranty,
      v_status_list(1 + MOD(v_equipid, v_status_list.COUNT)),
      1 + MOD(v_equipid, NUM_DEPTS)
    );
  END LOOP;

  DBMS_OUTPUT.PUT_LINE('Inserting maintenance records (bulk) ...');
  FOR i IN 1..NUM_MAINT LOOP
    INSERT INTO MAINTENANCE(MAINTENANCEID, EQUIPMENTID, TECHNICIANID, MAINTENANCEDATE, COST, DESCRIPTION)
    VALUES(
      seq_maintid.NEXTVAL,
      1 + MOD(TRUNC(DBMS_RANDOM.VALUE(1, NUM_EQUIP+1)), NUM_EQUIP),
      CASE WHEN MOD(i,10)=0 THEN NULL ELSE 1 + MOD(TRUNC(DBMS_RANDOM.VALUE(1, NUM_TECHS+1)), NUM_TECHS) END,
      TRUNC(SYSDATE - DBMS_RANDOM.VALUE(1, 1500)),
      ROUND(DBMS_RANDOM.VALUE(0, 5000),2),
      'Maintenance activity ' || TO_CHAR(i) || ' - ' || CASE WHEN MOD(i,3)=0 THEN 'Preventive' ELSE 'Corrective' END
    );
  END LOOP;

  DBMS_OUTPUT.PUT_LINE('Inserting maintenance history records...');
  FOR i IN 1..NUM_HIST LOOP
    INSERT INTO MAINTENANCE_HISTORY(HISTORYID, EQUIPMENTID, TECHNICIANID, ACTIONTAKEN, DATEFIXED, COST)
    VALUES(
      seq_histid.NEXTVAL,
      1 + MOD(TRUNC(DBMS_RANDOM.VALUE(1, NUM_EQUIP+1)), NUM_EQUIP),
      CASE WHEN MOD(i,8)=0 THEN NULL ELSE 1 + MOD(TRUNC(DBMS_RANDOM.VALUE(1, NUM_TECHS+1)), NUM_TECHS) END,
      'Action taken ' || i || ' — replaced part / calibration / software update',
      TRUNC(SYSDATE - DBMS_RANDOM.VALUE(1, 1500)),
      ROUND(DBMS_RANDOM.VALUE(0, 3000),2)
    );
  END LOOP;

  DBMS_OUTPUT.PUT_LINE('Inserting alerts...');
  FOR i IN 1..NUM_ALERTS LOOP
    INSERT INTO ALERTS(ALERTID, EQUIPMENTID, ISSUEDESCRIPTION, DATEREPORTED, STATUS)
    VALUES(
      seq_alertid.NEXTVAL,
      1 + MOD(TRUNC(DBMS_RANDOM.VALUE(1, NUM_EQUIP+1)), NUM_EQUIP),
      CASE WHEN MOD(i,5)=0 THEN 'Intermittent failure - detailed investigation required' ELSE 'Sensor reading out of range' END,
      TRUNC(SYSDATE - DBMS_RANDOM.VALUE(0, 365)),
      v_alert_status(1 + MOD(i, v_alert_status.COUNT))
    );
  END LOOP;

  COMMIT;
  DBMS_OUTPUT.PUT_LINE('Data insertion complete.');
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Error during data insertion: ' || SQLERRM);
    ROLLBACK;
END;
/
-- ===========================
-- 7. PL/SQL Procedures, Functions, Cursors, Window function examples, Package
-- ===========================

-- 7.1 Utility: error logging table
BEGIN
  EXECUTE IMMEDIATE 'CREATE TABLE ERROR_LOG (
    ERRID NUMBER GENERATED BY DEFAULT ON NULL AS IDENTITY PRIMARY KEY,
    ERR_TIME TIMESTAMP DEFAULT SYSTIMESTAMP,
    ERR_SOURCE VARCHAR2(200),
    ERR_MSG VARCHAR2(2000)
  )';
EXCEPTION WHEN OTHERS THEN NULL; END;
/

-- 7.2 Procedure: register_alert (IN params) and return ALERTID via OUT
CREATE OR REPLACE PROCEDURE register_alert(
  p_equipmentid IN NUMBER,
  p_issuedescription IN VARCHAR2,
  p_status IN VARCHAR2 DEFAULT 'Open',
  p_alertid OUT NUMBER
) IS
BEGIN
  IF p_equipmentid IS NULL THEN
    RAISE_APPLICATION_ERROR(-20001, 'Equipment ID cannot be null');
  END IF;

  IF p_status NOT IN ('Open','Investigating','Resolved','Dismissed') THEN
    p_status := 'Open';
  END IF;

  p_alertid := seq_alertid.NEXTVAL;
  INSERT INTO ALERTS(ALERTID, EQUIPMENTID, ISSUEDESCRIPTION, DATEREPORTED, STATUS)
  VALUES(p_alertid, p_equipmentid, p_issuedescription, SYSDATE, p_status);

  COMMIT;
EXCEPTION
  WHEN OTHERS THEN
    ROLLBACK;
    INSERT INTO ERROR_LOG(ERR_SOURCE, ERR_MSG) VALUES('register_alert', SQLERRM);
    RAISE;
END register_alert;
/

-- 7.3 Procedure: schedule_maintenance (IN equipment, tech, date, cost)
CREATE OR REPLACE PROCEDURE schedule_maintenance(
  p_equipmentid IN NUMBER,
  p_technicianid IN NUMBER,
  p_maintdate IN DATE DEFAULT SYSDATE,
  p_cost IN NUMBER DEFAULT 0,
  p_out_maintid OUT NUMBER
) IS
BEGIN
  IF NOT EXISTS (SELECT 1 FROM EQUIPMENT WHERE EQUIPMENTID = p_equipmentid) THEN
    RAISE_APPLICATION_ERROR(-20002, 'Equipment does not exist: '||NVL(TO_CHAR(p_equipmentid),'NULL'));
  END IF;

  p_out_maintid := seq_maintid.NEXTVAL;
  INSERT INTO MAINTENANCE(MAINTENANCEID, EQUIPMENTID, TECHNICIANID, MAINTENANCEDATE, COST, DESCRIPTION)
  VALUES(p_out_maintid, p_equipmentid, p_technicianid, p_maintdate, p_cost, 'Scheduled maintenance');

  COMMIT;
EXCEPTION
  WHEN OTHERS THEN
    ROLLBACK;
    INSERT INTO ERROR_LOG(ERR_SOURCE, ERR_MSG) VALUES('schedule_maintenance', SQLERRM);
    RAISE;
END schedule_maintenance;
/

-- 7.4 Procedure: record_fix (adds to maintenance_history and optionally updates equipment status)
CREATE OR REPLACE PROCEDURE record_fix(
  p_equipmentid IN NUMBER,
  p_technicianid IN NUMBER,
  p_action IN VARCHAR2,
  p_datefixed IN DATE DEFAULT SYSDATE,
  p_cost IN NUMBER DEFAULT 0
) IS
  v_historyid NUMBER;
BEGIN
  v_historyid := seq_histid.NEXTVAL;
  INSERT INTO MAINTENANCE_HISTORY(HISTORYID, EQUIPMENTID, TECHNICIANID, ACTIONTAKEN, DATEFIXED, COST)
  VALUES(v_historyid, p_equipmentid, p_technicianid, p_action, p_datefixed, p_cost);

  -- If cost > threshold update status to 'Operational'
  IF p_cost > 0 THEN
    UPDATE EQUIPMENT SET STATUS = 'Operational' WHERE EQUIPMENTID = p_equipmentid;
  END IF;

  COMMIT;
EXCEPTION
  WHEN OTHERS THEN
    ROLLBACK;
    INSERT INTO ERROR_LOG(ERR_SOURCE, ERR_MSG) VALUES('record_fix', SQLERRM);
    RAISE;
END record_fix;
/

-- 7.5 Function: calc_total_maintenance_cost (for an equipment)
CREATE OR REPLACE FUNCTION calc_total_maintenance_cost(p_equipmentid IN NUMBER) RETURN NUMBER IS
  v_total NUMBER;
BEGIN
  SELECT NVL(SUM(COST),0) INTO v_total FROM MAINTENANCE WHERE EQUIPMENTID = p_equipmentid;
  RETURN v_total;
EXCEPTION
  WHEN NO_DATA_FOUND THEN RETURN 0;
  WHEN OTHERS THEN
    INSERT INTO ERROR_LOG(ERR_SOURCE, ERR_MSG) VALUES('calc_total_maintenance_cost', SQLERRM);
    RETURN NULL;
END calc_total_maintenance_cost;
/

-- 7.6 Function: validate_equipment_status (returns 'Y' if status valid)
CREATE OR REPLACE FUNCTION validate_equipment_status(p_status IN VARCHAR2) RETURN CHAR IS
BEGIN
  IF p_status IN ('Operational','Under Maintenance','Out of Service','Decommissioned') THEN
    RETURN 'Y';
  ELSE
    RETURN 'N';
  END IF;
END validate_equipment_status;
/

-- 7.7 Function: lookup_technician_by_specialty (returns a techid or null)
CREATE OR REPLACE FUNCTION lookup_technician_by_specialty(p_specialty IN VARCHAR2) RETURN NUMBER IS
  v_techid NUMBER;
BEGIN
  SELECT TECHID INTO v_techid FROM (
    SELECT TECHID FROM TECHNICIANS WHERE SPECIALTY = p_specialty AND CONTACT IS NOT NULL ORDER BY DBMS_RANDOM.VALUE
  ) WHERE ROWNUM = 1;
  RETURN v_techid;
EXCEPTION
  WHEN NO_DATA_FOUND THEN RETURN NULL;
  WHEN OTHERS THEN
    INSERT INTO ERROR_LOG(ERR_SOURCE, ERR_MSG) VALUES('lookup_technician_by_specialty', SQLERRM);
    RETURN NULL;
END lookup_technician_by_specialty;
/

-- 7.8 Explicit cursor example + bulk collect for optimization
CREATE OR REPLACE PROCEDURE bulk_archive_old_maintenance(p_cutoff_date IN DATE) IS
  TYPE t_maintid IS TABLE OF MAINTENANCE.MAINTENANCEID%TYPE;
  v_ids t_maintid;
BEGIN
  OPEN c1 FOR SELECT MAINTENANCEID FROM MAINTENANCE WHERE MAINTENANCEDATE < p_cutoff_date;
  FETCH c1 BULK COLLECT INTO v_ids LIMIT 1000;
  WHILE v_ids.COUNT > 0 LOOP
    -- Example action: delete old maintenance and insert into history as archive (simple example)
    FORALL i IN 1..v_ids.COUNT
      DELETE FROM MAINTENANCE WHERE MAINTENANCEID = v_ids(i);
    COMMIT;
    FETCH c1 BULK COLLECT INTO v_ids LIMIT 1000;
  END LOOP;
  CLOSE c1;
EXCEPTION
  WHEN OTHERS THEN
    IF c1%ISOPEN THEN CLOSE c1; END IF;
    INSERT INTO ERROR_LOG(ERR_SOURCE, ERR_MSG) VALUES('bulk_archive_old_maintenance', SQLERRM);
    ROLLBACK;
    RAISE;
END bulk_archive_old_maintenance;
/

-- Because Oracle requires cursor declaration, create it
DECLARE
  CURSOR c1 IS SELECT MAINTENANCEID FROM MAINTENANCE WHERE MAINTENANCEDATE < SYSDATE - 3650;
BEGIN
  NULL;
END;
/

-- 7.9 Package example grouping related operations
CREATE OR REPLACE PACKAGE equipment_pkg IS
  FUNCTION get_equipment_status(p_equipmentid NUMBER) RETURN VARCHAR2;
  PROCEDURE set_equipment_status(p_equipmentid NUMBER, p_status VARCHAR2);
  FUNCTION get_top_expensive_maintenance(p_limit NUMBER) RETURN SYS.ODCINUMBERLIST; -- returns maintenance ids
END equipment_pkg;
/

CREATE OR REPLACE PACKAGE BODY equipment_pkg IS

  FUNCTION get_equipment_status(p_equipmentid NUMBER) RETURN VARCHAR2 IS
    v_status VARCHAR2(30);
  BEGIN
    SELECT STATUS INTO v_status FROM EQUIPMENT WHERE EQUIPMENTID = p_equipmentid;
    RETURN v_status;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN RETURN NULL;
    WHEN OTHERS THEN
      INSERT INTO ERROR_LOG(ERR_SOURCE, ERR_MSG) VALUES('equipment_pkg.get_equipment_status', SQLERRM);
      RETURN NULL;
  END;

  PROCEDURE set_equipment_status(p_equipmentid NUMBER, p_status VARCHAR2) IS
  BEGIN
    IF p_status NOT IN ('Operational','Under Maintenance','Out of Service','Decommissioned') THEN
      RAISE_APPLICATION_ERROR(-20003, 'Invalid status: ' || p_status);
    END IF;
    UPDATE EQUIPMENT SET STATUS = p_status WHERE EQUIPMENTID = p_equipmentid;
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      INSERT INTO ERROR_LOG(ERR_SOURCE, ERR_MSG) VALUES('equipment_pkg.set_equipment_status', SQLERRM);
      ROLLBACK;
      RAISE;
  END;

  FUNCTION get_top_expensive_maintenance(p_limit NUMBER) RETURN SYS.ODCINUMBERLIST IS
    v_list SYS.ODCINUMBERLIST := SYS.ODCINUMBERLIST();
  BEGIN
    FOR r IN (SELECT MAINTENANCEID FROM MAINTENANCE ORDER BY COST DESC FETCH FIRST NVL(p_limit,10) ROWS ONLY) LOOP
      v_list.EXTEND;
      v_list(v_list.COUNT) := r.MAINTENANCEID;
    END LOOP;
    RETURN v_list;
  EXCEPTION
    WHEN OTHERS THEN
      INSERT INTO ERROR_LOG(ERR_SOURCE, ERR_MSG) VALUES('equipment_pkg.get_top_expensive_maintenance', SQLERRM);
      RETURN SYS.ODCINUMBERLIST();
  END;

END equipment_pkg;
/

-- ===========================
-- 8. Window function example (standalone query)
--    Shows top 3 costly maintenance per equipment using window functions
-- ===========================
-- Example query (run below in validation section)
-- ===========================

-- ===========================
-- 9. Testing calls and validation queries (run these to verify data)
-- ===========================
-- Basic retrieval
PROMPT ======= BASIC SELECTS =======
SELECT COUNT(*) AS total_departments FROM DEPARTMENTS;
SELECT COUNT(*) AS total_technicians FROM TECHNICIANS;
SELECT COUNT(*) AS total_equipment FROM EQUIPMENT;
SELECT COUNT(*) AS total_maintenance FROM MAINTENANCE;
SELECT COUNT(*) AS total_history FROM MAINTENANCE_HISTORY;
SELECT COUNT(*) AS total_alerts FROM ALERTS;

-- Join example: equipment with department and last maintenance date
PROMPT ======= EQUIPMENT WITH LAST MAINTENANCE =======
SELECT e.equipmentid, e.name, e.category, d.deptname, MAX(m.maintenancedate) AS last_maint
FROM equipment e
LEFT JOIN departments d ON e.departmentid = d.deptid
LEFT JOIN maintenance m ON e.equipmentid = m.equipmentid
GROUP BY e.equipmentid, e.name, e.category, d.deptname
ORDER BY last_maint NULLS LAST FETCH FIRST 20 ROWS ONLY;

-- Aggregation: total maintenance cost per department
PROMPT ======= TOTAL MAINTENANCE COST PER DEPARTMENT =======
SELECT d.deptid, d.deptname, NVL(SUM(m.cost),0) total_cost
FROM departments d
LEFT JOIN equipment e ON e.departmentid = d.deptid
LEFT JOIN maintenance m ON m.equipmentid = e.equipmentid
GROUP BY d.deptid, d.deptname
ORDER BY total_cost DESC;

-- Subquery: equipment with maintenance cost above average
PROMPT ======= EQUIPMENT ABOVE AVERAGE MAINTENANCE COST =======
SELECT e.equipmentid, e.name, (SELECT NVL(SUM(m2.cost),0) FROM maintenance m2 WHERE m2.equipmentid = e.equipmentid) total_cost
FROM equipment e
WHERE (SELECT NVL(SUM(m2.cost),0) FROM maintenance m2 WHERE m2.equipmentid = e.equipmentid) >
      (SELECT NVL(AVG(t.total_c),0) FROM (SELECT SUM(cost) total_c FROM maintenance GROUP BY equipmentid) t)
ORDER BY total_cost DESC FETCH FIRST 20 ROWS ONLY;

-- Window function query: top 3 maintenance per equipment by cost
PROMPT ======= TOP 3 MAINTENANCE ENTRIES PER EQUIPMENT (WINDOW FN) =======
SELECT *
FROM (
  SELECT m.*, ROW_NUMBER() OVER (PARTITION BY m.equipmentid ORDER BY m.cost DESC) rn
  FROM maintenance m
) WHERE rn <= 3
ORDER BY equipmentid, cost DESC
FETCH FIRST 50 ROWS ONLY;

-- Test functions and procedures
PROMPT ======= PROCEDURE & FUNCTION TESTS =======
DECLARE
  v_alertid NUMBER;
  v_maintid NUMBER;
  v_total_cost NUMBER;
  v_status VARCHAR2(30);
  v_tech NUMBER;
  v_list SYS.ODCINUMBERLIST;
BEGIN
  -- register an alert on equipment 1
  register_alert(1, 'Auto test alert: sensor spike', 'Open', v_alertid);
  DBMS_OUTPUT.PUT_LINE('Registered alert id: ' || v_alertid);

  -- schedule a maintenance
  schedule_maintenance(1, 2, SYSDATE + 7, 250.00, v_maintid);
  DBMS_OUTPUT.PUT_LINE('Scheduled maintenance id: ' || v_maintid);

  -- record a fix
  record_fix(1, 2, 'Replaced fuse and calibrated sensor', SYSDATE, 120.00);
  DBMS_OUTPUT.PUT_LINE('Recorded fix for equipment 1');

  -- use functions
  v_total_cost := calc_total_maintenance_cost(1);
  DBMS_OUTPUT.PUT_LINE('Total maintenance cost for equipment 1: ' || NVL(TO_CHAR(v_total_cost), 'NULL'));

  v_status := equipment_pkg.get_equipment_status(1);
  DBMS_OUTPUT.PUT_LINE('Equipment 1 status: ' || NVL(v_status,'-'));

  v_tech := lookup_technician_by_specialty('Biomedical');
  DBMS_OUTPUT.PUT_LINE('Random Biomedical tech id: ' || NVL(TO_CHAR(v_tech),'NULL'));

  v_list := equipment_pkg.get_top_expensive_maintenance(5);
  FOR i IN 1..v_list.COUNT LOOP
    DBMS_OUTPUT.PUT_LINE('Top maintenance id['||i||'] = ' || v_list(i));
  END LOOP;

  COMMIT;
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Test block error: ' || SQLERRM);
    ROLLBACK;
END;
/

-- Integrity checks: foreign key test: try inserting a maintenance with non-existent equipment (should fail)
PROMPT ======= INTEGRITY CHECK (EXPECTED ERROR) =======
BEGIN
  -- This should raise FK error
  INSERT INTO MAINTENANCE(MAINTENANCEID, EQUIPMENTID, TECHNICIANID, MAINTENANCEDATE, COST, DESCRIPTION)
  VALUES(seq_maintid.NEXTVAL, 9999999, 1, SYSDATE, 10, 'FK test - should fail');
  COMMIT;
EXCEPTION WHEN OTHERS THEN
  DBMS_OUTPUT.PUT_LINE('FK check error (expected): ' || SQLERRM);
  ROLLBACK;
END;
/

-- Spot-checks: ensure constraints (status valid)
PROMPT ======= DATA QUALITY SPOT CHECKS =======
SELECT COUNT(*) FROM EQUIPMENT WHERE STATUS NOT IN ('Operational','Under Maintenance','Out of Service','Decommissioned');
SELECT COUNT(*) FROM ALERTS WHERE STATUS NOT IN ('Open','Investigating','Resolved','Dismissed');

-- View a few rows
SELECT * FROM DEPARTMENTS FETCH FIRST 5 ROWS ONLY;
SELECT * FROM TECHNICIANS FETCH FIRST 5 ROWS ONLY;
SELECT * FROM EQUIPMENT FETCH FIRST 10 ROWS ONLY;
SELECT * FROM MAINTENANCE FETCH FIRST 10 ROWS ONLY;
SELECT * FROM MAINTENANCE_HISTORY FETCH FIRST 10 ROWS ONLY;
SELECT * FROM ALERTS FETCH FIRST 10 ROWS ONLY;

-- ===========================
-- 10. Notes / How to adapt script
-- ===========================
-- * To increase row counts: change NUM_EQUIP, NUM_MAINT, etc in the PL/SQL insertion block.
-- * If you prefer specific IDs instead of sequences, change INSERT logic accordingly.
-- * For production, consider caching/increasing sequence cache, adding partitioning for large tables, and more robust logging.
-- * Add more CHECK constraints or triggers for advanced business rules (e.g., warranty expiry must be >= purchase date).
-- * Export CREATE + INSERT scripts to GitHub as required by your deliverable.
-- ===========================
COMMIT;
PROMPT ======= SCRIPT COMPLETE =======
