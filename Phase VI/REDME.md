HMMS_PhaseVI
│
├── README.md
├── procedures.sql
├── functions.sql
├── cursors.sql
├── packages.sql
└── test_results.sql

# Hospital Maintenance Management System (HMMS) - Phase VI

## Overview
Phase VI implements **PL/SQL procedures, functions, cursors, and packages** for HMMS.  
It also includes transaction handling, exception handling, window functions, and validation logic.

## Folder Structure
- `procedures.sql`  : PL/SQL procedures (INSERT/UPDATE/DELETE) with exception handling
- `functions.sql`   : PL/SQL functions (calculations, validation, lookups)
- `cursors.sql`     : Explicit cursors and bulk operations
- `packages.sql`    : Packages combining related procedures and functions
- `test_results.sql`: Scripts to test procedures, functions, cursors, and packages

## Features
- Parameterized procedures with IN/OUT/IN OUT
- Functions for calculations, validations, lookups
- Cursors for multi-row processing
- Bulk operations for optimization
- Window functions (RANK, DENSE_RANK, ROW_NUMBER, LAG, LEAD)
- Exception handling (predefined + custom)
- Error logging and recovery mechanisms
