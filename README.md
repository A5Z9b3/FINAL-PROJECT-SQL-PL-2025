
# NAMES : HABANABASHAKA Philimin
# Id : 27487
# Hospital Equipment Maintenance Monitoring System (HEMMS)

**Student ID:** <<StudentId>>  
**Course:** INSY 8311 – Database Development with PL/SQL  
**Lecturer:** Eric Maniraguha  
**Project Completion Date:** December 7, 2025


# FINAL-PROJECT-SQL-PL-2025




# 🏥 Hospital Equipment Maintenance Monitoring System (HEMMS)

## 📌 Project Overview  
The **Hospital Equipment Maintenance Monitoring System (HEMMS)** is a digital platform designed to **track, manage, and maintain hospital equipment efficiently**.  
Most hospitals use paper/manual methods, which lead to problems such as:

- Missed maintenance schedules  
- Poor tracking of equipment  
- Long equipment downtime  
- High operational costs  
- Limited data for decision-making  

HEMMS provides a **centralized automated solution** to solve these challenges.

---

## 🎯 System Objectives  
The system aims to:
- Record and store equipment information  
- Track maintenance & repair history  
- Assign technicians to specific equipment  
- Generate alerts before maintenance deadlines  
- Improve decision-making using reports & logs  
- Increase accountability and reduce downtime  

---

## 👥 Target Users  
| User Type | Role in System |
|-----------|----------------|
| Hospital Technicians | Perform maintenance and repairs |
| Maintenance Supervisors | Monitor tasks and schedules |
| Hospital Administrators | Manage equipment and reports |
| IT/Database Officers | Maintain the database & system |

---

## 🗄️ Database Design (Oracle + PL/SQL)

The system uses **Oracle Database** with **PL/SQL procedures, triggers, and functions** for automation, validation, and alerts.

### 📌 Main Database Tables
| Table Name | Purpose |
|------------|---------|
| `Equipment` | Store equipment details |
| `Departments` | Hospital departments |
| `Technicians` | Technician data |
| `Users` | Authentication & access levels |
| `Maintenance` | Planned maintenance |
| `Maintenance_History` | Completed maintenance |
| `Alerts` | System reminders/alerts |

### 🧾 Sample Table Structures  

#### **Equipment Table**
```sql
EquipmentID (PK)
Name
Category
PurchaseDate
WarrantyExpiry
Status
DepartmentID (FK)

## Project Summary
Short paragraph (2–3 sentences) describing the problem and solution.

## Key Objectives
- Centralize equipment records
- Automate maintenance scheduling & alerts
- Enforce access & business rules via PL/SQL
- Provide BI dashboards for decision support

## Quick Start
1. Create PDB: `database/scripts/create_pdb_and_users.sql`
2. Create tables: `database/scripts/create_tables.sql`
3. Insert sample data: `database/scripts/insert_sample_data.sql`
4. Compile PL/SQL packages: `database/scripts/plsql/`
5. Run tests: `queries/test_queries.sql`

