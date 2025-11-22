# HEMMS Database Project

## Project Overview
**Hospital Equipment Maintenance Management System (HEMMS)**  
This project manages hospital equipment, maintenance schedules, alerts, and technicians.

---

## Phase IV: Database Creation

### PDB Naming Convention
`GrpName_StudentId_FirstName_ProjectName_DB`  
Example: `A_27487_philimin_HEMMS_db`

### Admin User
- **Username:** hemms_admin  
- **Password:** philimin  
- **Privileges:** Super Admin (ALL PRIVILEGES)

### Tablespaces
| Tablespace     | Purpose             | File                                    | Size  | Autoextend |
|----------------|-------------------|----------------------------------------|-------|------------|
| USERS          | Default data       | users01.dbf                             | 250M  | Yes        |
| hemms_data     | Application data   | hemms_data01.dbf                         | 200M  | Yes        |
| hemms_index    | Indexes            | hemms_index01.dbf                        | 100M  | Yes        |
| hemms_temp     | Temporary work     | hemms_temp01.dbf                         | 50M   | Yes        |

### Temporary Tablespace
- **Name:** hemms_temp  
- **Used for:** Sorting, temporary operations  

### Memory Parameters
- SGA / PGA configured automatically by XE. Custom settings shown as comments in SQL.

### Archive Logging
- Not supported in Oracle XE.



