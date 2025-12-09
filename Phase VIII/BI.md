# Business Intelligence Requirements

## Stakeholders
1. Hospital Administrators
2. Department Heads
3. Biomedical Technicians
4. Finance Department
5. Quality Assurance Team

## Key Performance Indicators (KPIs)

### 1. Equipment Performance KPIs
- Equipment Utilization Rate (%)
- Mean Time Between Failures (MTBF)
- Mean Time To Repair (MTTR)
- Overall Equipment Effectiveness (OEE)

### 2. Maintenance KPIs
- Preventive Maintenance Compliance (%)
- Emergency Maintenance Rate (%)
- Maintenance Cost per Equipment
- Technician Productivity

### 3. Financial KPIs
- Total Equipment Value by Department
- Maintenance Cost as % of Equipment Value
- Warranty Coverage Utilization
- Cost Avoidance through Preventive Maintenance

### 4. Operational KPIs
- Equipment Downtime Hours
- Alert Resolution Time
- Spare Parts Inventory Turnover
- Department-wise Equipment Health Score

## Reporting Frequency
- **Daily:** Equipment status, critical alerts
- **Weekly:** Maintenance schedule, technician workload
- **Monthly:** Performance metrics, cost analysis
- **Quarterly:** Strategic reports, budget planning
- **Annual:** Compliance reports, asset valuation

## Analytical Queries:

### 1. Equipment Utilization Dashboard
```sql
SELECT 
    e.Name,
    d.DeptName,
    e.UtilizationHours,
    e.PurchasePrice,
    ROUND((e.UtilizationHours / (24 * 30)) * 100, 2) AS Utilization_Percentage,
    RANK() OVER (ORDER BY e.UtilizationHours DESC) AS Utilization_Rank
FROM EQUIPMENT e
JOIN DEPARTMENTS d ON e.DepartmentID = d.DeptID
WHERE e.Status = 'ACTIVE'
ORDER BY Utilization_Percentage DESC;
