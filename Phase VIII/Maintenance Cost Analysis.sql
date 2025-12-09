SELECT 
    TO_CHAR(m.ActualDate, 'YYYY-MM') AS Month,
    d.DeptName,
    COUNT(*) AS Maintenance_Count,
    SUM(m.Cost) AS Total_Cost,
    AVG(m.Cost) AS Avg_Cost,
    SUM(mh.DowntimeHours) AS Total_Downtime,
    ROUND(SUM(m.Cost) / COUNT(*), 2) AS Cost_Per_Maintenance
FROM MAINTENANCE m
JOIN EQUIPMENT e ON m.EquipmentID = e.EquipmentID
JOIN DEPARTMENTS d ON e.DepartmentID = d.DeptID
LEFT JOIN MAINTENANCE_HISTORY mh ON m.MaintenanceID = mh.MaintenanceID
WHERE m.Status = 'COMPLETED'
    AND m.ActualDate >= ADD_MONTHS(SYSDATE, -12)
GROUP BY TO_CHAR(m.ActualDate, 'YYYY-MM'), d.DeptName
ORDER BY Month DESC, Total_Cost DESC;
