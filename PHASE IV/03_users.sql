
-- ===========================================================
-- Phase IV: User Setup
-- HEMMS Project
-- ===========================================================

-- Using existing user hemms_admin (already created with PDB)
-- If needed, reset password
ALTER USER hemms_admin IDENTIFIED BY philimin;

-- Grant full privileges
GRANT ALL PRIVILEGES TO hemms_admin;
