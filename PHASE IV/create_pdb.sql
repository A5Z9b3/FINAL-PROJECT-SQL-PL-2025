
-- ===========================================================
-- Phase IV: Database Creation
-- Project: HEMMS (Hospital Equipment Maintenance Management System)
-- Student: Habanabashaka Philimin
-- PDB Name Format: GrpName_StudentId_FirstName_ProjectName_DB
-- Example: A_27487_philimin_HEMMS_db
-- ===========================================================

-- 1. CREATE PLUGGABLE DATABASE
CREATE PLUGGABLE DATABASE A_27487_PHILIMIN_HEMMS_DB
    ADMIN USER hemms_admin IDENTIFIED BY philimin
    ROLES = (DBA)
    DEFAULT TABLESPACE USERS
    DATAFILE 'C:\APP\ORADATA\XE\A_27487_PHILIMIN_HEMMS_DB\users01.dbf'
        SIZE 250M AUTOEXTEND ON NEXT 50M MAXSIZE UNLIMITED
    FILE_NAME_CONVERT = (
        'C:\APP\ORADATA\XE\PDBSEED\',
        'C:\APP\ORADATA\XE\A_27487_PHILIMIN_HEMMS_DB\'
    )
    STORAGE (MAXSIZE UNLIMITED);

-- 2. OPEN THE PDB
ALTER PLUGGABLE DATABASE A_27487_PHILIMIN_HEMMS_DB OPEN;
ALTER PLUGGABLE DATABASE A_27487_PHILIMIN_HEMMS_DB SAVE STATE;

-- 3. SWITCH TO THE NEW PDB
ALTER SESSION SET CONTAINER = A_27487_PHILIMIN_HEMMS_DB;

-- 4. CREATE TABLESPACES FOR DATA & INDEXES
CREATE TABLESPACE hemms_data
    DATAFILE 'C:\APP\ORADATA\XE\A_27487_PHILIMIN_HEMMS_DB\hemms_data01.dbf'
    SIZE 200M AUTOEXTEND ON NEXT 50M MAXSIZE UNLIMITED;

CREATE TABLESPACE hemms_index
    DATAFILE 'C:\APP\ORADATA\XE\A_27487_PHILIMIN_HEMMS_DB\hemms_index01.dbf'
    SIZE 100M AUTOEXTEND ON NEXT 50M MAXSIZE UNLIMITED;

-- 5. CREATE TEMPORARY TABLESPACE
CREATE TEMPORARY TABLESPACE hemms_temp
    TEMPFILE 'C:\APP\ORADATA\XE\A_27487_PHILIMIN_HEMMS_DB\hemms_temp01.dbf'
    SIZE 50M AUTOEXTEND ON NEXT 50M MAXSIZE UNLIMITED;

-- 6. ALTER DEFAULT TEMPORARY TABLESPACE
ALTER DATABASE DEFAULT TEMPORARY TABLESPACE hemms_temp;

-- 7. CREATE SUPER ADMIN USER
CREATE USER hemms_admin IDENTIFIED BY philimin
    DEFAULT TABLESPACE USERS
    TEMPORARY TABLESPACE hemms_temp
    QUOTA UNLIMITED ON USERS;

GRANT ALL PRIVILEGES TO hemms_admin;

-- 8. ARCHIVE LOGGING
-- Note: Not supported in Oracle XE; this step is skipped.

-- 9. MEMORY PARAMETERS (SGA/PGA) for XE
-- Oracle XE limits SGA/PGA, but example syntax:
-- ALTER SYSTEM SET sga_target=500M SCOPE=SPFILE;
-- ALTER SYSTEM SET pga_aggregate_target=200M SCOPE=SPFILE;

-- ===========================================================
-- Phase IV script complete – ready for GitHub submission
-- ===========================================================
