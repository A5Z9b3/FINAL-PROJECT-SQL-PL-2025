-- =========================
-- HMS Phase VII: Tables & Sequences
-- =========================

-- HOLIDAYS Table
CREATE TABLE HOLIDAYS (
    HOLIDAY_DATE DATE PRIMARY KEY,
    DESCRIPTION  VARCHAR2(100)
);

-- AUDIT_LOG Table
CREATE TABLE AUDIT_LOG (
    AUDIT_ID     NUMBER PRIMARY KEY,
    USERNAME     VARCHAR2(50),
    OPERATION    VARCHAR2(20),
    TABLE_NAME   VARCHAR2(50),
    ROW_ID_VALUE VARCHAR2(100),
    ATTEMPT_TIME DATE,
    ALLOWED      CHAR(1),
    REASON       VARCHAR2(400),
    SQL_TEXT     CLOB
);

-- SEQUENCE for AUDIT_LOG
CREATE SEQUENCE SEQ_AUDIT_ID START WITH 1 INCREMENT BY 1;

-- HMS Tables
CREATE TABLE Departments (
    DeptID NUMBER PRIMARY KEY,
    DeptName VARCHAR2(100),
    Location VARCHAR2(100),
    HeadOfDept VARCHAR2(100)
);

CREATE TABLE Equipment (
    EquipmentID NUMBER PRIMARY KEY,
    Name VARCHAR2(100) NOT NULL,
    Category VARCHAR2(50),
    PurchaseDate DATE,
    WarrantyExpiry DATE,
    Status VARCHAR2(50) CHECK (Status IN ('Working','Faulty','Under Maintenance','Decommissioned')),
    DepartmentID NUMBER REFERENCES Departments(DeptID)
);

CREATE TABLE Technicians (
    TechID NUMBER PRIMARY KEY,
    FullName VARCHAR2(100),
    Contact VARCHAR2(20),
    Specialty VARCHAR2(50)
);

CREATE TABLE Maintenance (
    MaintenanceID NUMBER PRIMARY KEY,
    EquipmentID NUMBER REFERENCES Equipment(EquipmentID),
    TechnicianID NUMBER REFERENCES Technicians(TechID),
    MaintenanceDate DATE,
    Cost NUMBER(10,2),
    Description VARCHAR2(200)
);

CREATE TABLE Maintenance_History (
    HistoryID NUMBER PRIMARY KEY,
    EquipmentID NUMBER REFERENCES Equipment(EquipmentID),
    TechnicianID NUMBER REFERENCES Technicians(TechID),
    ActionTaken VARCHAR2(200),
    DateFixed DATE,
    Cost NUMBER(10,2)
);

CREATE TABLE Alerts (
    AlertID NUMBER PRIMARY KEY,
    EquipmentID NUMBER REFERENCES Equipment(EquipmentID),
    IssueDescription VARCHAR2(200),
    DateReported DATE,
    Status VARCHAR2(50)
);
