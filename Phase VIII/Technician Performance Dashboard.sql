SELECT 
    t.FullName,
    d.DeptName AS Technician_Dept,
    COUNT(m.MaintenanceID) AS Total_Jobs,
    SUM(CASE WHEN m.Status = 'COMPLETED' THEN 1 ELSE 0 END) AS Completed_Jobs,
    AVG(mh.DowntimeHours) AS Avg_Repair_Time,
    SUM(m.Cost) AS Total_Cost_Handled,
    ROUND(AVG(m.Cost), 2) AS Avg_Cost_Per_Job,
    RANK() OVER (ORDER BY COUNT(m.MaintenanceID) DESC) AS Performance_Rank
FROM TECHNICIANS t
LEFT JOIN MAINTENANCE m ON t.TechID = m.TechnicianID
LEFT JOIN MAINTENANCE_HISTORY mh ON m.MaintenanceID = mh.MaintenanceID
LEFT JOIN DEPARTMENTS d ON t.DepartmentID = d.DeptID
WHERE m.ActualDate >= ADD_MONTHS(SYSDATE, -3)
GROUP BY t.TechID, t.FullName, d.DeptName
ORDER BY Performance_Rank;
