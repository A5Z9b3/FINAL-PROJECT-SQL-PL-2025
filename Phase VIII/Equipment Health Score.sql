WITH equipment_metrics AS (
    SELECT 
        e.EquipmentID,
        e.Name,
        d.DeptName,
        calculate_equipment_age(e.EquipmentID) AS Age_Years,
        e.UtilizationHours,
        COUNT(m.MaintenanceID) AS Maintenance_Count,
        AVG(m.Cost) AS Avg_Maintenance_Cost,
        SUM(mh.DowntimeHours) AS Total_Downtime,
        CASE 
            WHEN e.NextMaintenanceDate < SYSDATE THEN 0.3
            WHEN e.NextMaintenanceDate <= SYSDATE + 7 THEN 0.6
            ELSE 1.0 
        END AS Maintenance_Score,
        CASE 
            WHEN e.WarrantyExpiry >= SYSDATE THEN 1.0
            ELSE 0.5 
        END AS Warranty_Score
    FROM EQUIPMENT e
    JOIN DEPARTMENTS d ON e.DepartmentID = d.DeptID
    LEFT JOIN MAINTENANCE m ON e.EquipmentID = m.EquipmentID
    LEFT JOIN MAINTENANCE_HISTORY mh ON m.MaintenanceID = mh.MaintenanceID
    WHERE e.Status = 'ACTIVE'
    GROUP BY e.EquipmentID, e.Name, d.DeptName, e.UtilizationHours,
             e.NextMaintenanceDate, e.WarrantyExpiry
)
SELECT 
    EquipmentID,
    Name,
    DeptName,
    Age_Years,
    UtilizationHours,
    Maintenance_Count,
    ROUND(Avg_Maintenance_Cost, 2) AS Avg_Maintenance_Cost,
    Total_Downtime,
    ROUND((Maintenance_Score * 0.4 + Warranty_Score * 0.3 + 
           (CASE WHEN Age_Years < 5 THEN 1.0 
                 WHEN Age_Years < 10 THEN 0.7 
                 ELSE 0.4 END) * 0.3) * 100, 1) AS Health_Score,
    CASE 
        WHEN ROUND((Maintenance_Score * 0.4 + Warranty_Score * 0.3 + 
                   (CASE WHEN Age_Years < 5 THEN 1.0 
                         WHEN Age_Years < 10 THEN 0.7 
                         ELSE 0.4 END) * 0.3) * 100, 1) >= 80 THEN 'EXCELLENT'
        WHEN ROUND((Maintenance_Score * 0.4 + Warranty_Score * 0.3 + 
                   (CASE WHEN Age_Years < 5 THEN 1.0 
                         WHEN Age_Years < 10 THEN 0.7 
                         ELSE 0.4 END) * 0.3) * 100, 1) >= 60 THEN 'GOOD'
        WHEN ROUND((Maintenance_Score * 0.4 + Warranty_Score * 0.3 + 
                   (CASE WHEN Age_Years < 5 THEN 1.0 
                         WHEN Age_Years < 10 THEN 0.7 
                         ELSE 0.4 END) * 0.3) * 100, 1) >= 40 THEN 'FAIR'
        ELSE 'POOR'
    END AS Health_Status
FROM equipment_metrics
ORDER BY Health_Score DESC;
