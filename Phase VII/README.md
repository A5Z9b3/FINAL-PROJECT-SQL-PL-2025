
# HMS Project - Phase VII: Advanced Programming & Auditing

## Objective
Implement business rules and auditing for Hospital Maintenance Management System.

## Business Rules
- DML (INSERT/UPDATE/DELETE) **blocked on weekdays** (Mon-Fri)
- DML **blocked on public holidays**
- DML **allowed on weekends**

## Implementation
1. **Holiday Management**: `HOLIDAYS` table
2. **Audit Log Table**: `AUDIT_LOG`
3. **Audit Logging Function**: `audit_pkg.log_audit`
4. **Restriction Check Function**: `audit_pkg.is_dml_allowed`
5. **Triggers**: row-level triggers on `Equipment`, `Technicians`, `Maintenance`, `Departments`, `Alerts`
6. **Compound Trigger**: captures multiple row attempts

## Testing
- Test inserts on weekdays, weekends, and holidays
- Verify `AUDIT_LOG` captures all attempts
- Clear error messages displayed

## How to Run
1. Open SQL Developer
2. Run scripts in order:
   - `01_tables.sql`
   - `02_audit_pkg.sql`
   - `03_triggers.sql`
   - `04_test_scripts.sql`
3. Check `AUDIT_LOG` to verify behavior

## Output
- DBMS_OUTPUT messages indicate allowed/denied operations
- `AUDIT_LOG` contains detailed logging
