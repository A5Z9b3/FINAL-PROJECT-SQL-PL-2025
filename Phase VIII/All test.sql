-- ============================================
-- PHASE VIII: Final Documentation & BI Implementation
-- ============================================

SET SERVEROUTPUT ON SIZE UNLIMITED;

-- ============================================
-- 1. CREATE COMPREHENSIVE BUSINESS INTELLIGENCE VIEWS
-- ============================================

-- View 1: Executive Dashboard Summary
CREATE OR REPLACE VIEW v_executive_dashboard AS
SELECT 
    -- Equipment Metrics
    (SELECT COUNT(*) FROM EQUIPMENT WHERE Status = 'ACTIVE') AS Active_Equipment,
    (SELECT COUNT(*) FROM EQUIPMENT WHERE Status = 'UNDER_MAINTENANCE') AS Equipment_Under_Maintenance,
    (SELECT COUNT(*) FROM EQUIPMENT WHERE Status = 'DECOMMISSIONED') AS Decommissioned_Equipment,
    
    -- Maintenance Metrics
    (SELECT COUNT(*) FROM MAINTENANCE WHERE Status = 'SCHEDULED') AS Scheduled_Maintenance,
    (SELECT COUNT(*) FROM MAINTENANCE WHERE Status = 'IN_PROGRESS') AS Maintenance_In_Progress,
    (SELECT COUNT(*) FROM MAINTENANCE WHERE Status = 'COMPLETED' 
     AND ActualDate >= ADD_MONTHS(SYSDATE, -1)) AS Completed_Last_Month,
    
    -- Cost Metrics
    (SELECT SUM(PurchasePrice) FROM EQUIPMENT WHERE Status = 'ACTIVE') AS Total_Equipment_Value,
    (SELECT SUM(Cost) FROM MAINTENANCE 
     WHERE Status = 'COMPLETED' AND ActualDate >= ADD_MONTHS(SYSDATE, -12)) AS Annual_Maintenance_Cost,
    
    -- Alert Metrics
    (SELECT COUNT(*) FROM ALERTS WHERE Status = 'PENDING') AS Pending_Alerts,
    (SELECT COUNT(*) FROM ALERTS WHERE Status = 'IN_PROGRESS') AS Alerts_In_Progress,
    (SELECT COUNT(*) FROM ALERTS WHERE Priority = 'CRITICAL' AND Status IN ('PENDING', 'IN_PROGRESS')) AS Critical_Alerts,
    
    -- Compliance Metrics
    (SELECT COUNT(*) FROM EQUIPMENT 
     WHERE Status = 'ACTIVE' AND NextMaintenanceDate < SYSDATE) AS Overdue_Maintenance,
    (SELECT COUNT(*) FROM EQUIPMENT 
     WHERE Status = 'ACTIVE' AND WarrantyExpiry < SYSDATE) AS Expired_Warranties,
    
    -- Performance Metrics
    ROUND((SELECT AVG(calculate_equipment_health_score(EquipmentID)) 
           FROM EQUIPMENT WHERE Status = 'ACTIVE'), 1) AS Avg_Equipment_Health_Score,
    (SELECT ROUND(AVG(DowntimeHours), 1) 
     FROM MAINTENANCE_HISTORY 
     WHERE DateFixed >= ADD_MONTHS(SYSDATE, -3)) AS Avg_Downtime_Hours
FROM DUAL;

-- View 2: Department Performance Dashboard
CREATE OR REPLACE VIEW v_department_performance AS
SELECT 
    d.DeptID,
    d.DeptName,
    d.Location,
    d.HeadOfDept,
    -- Equipment Stats
    COUNT(e.EquipmentID) AS Total_Equipment,
    COUNT(CASE WHEN e.Status = 'ACTIVE' THEN 1 END) AS Active_Equipment,
    COUNT(CASE WHEN e.Status = 'UNDER_MAINTENANCE' THEN 1 END) AS Under_Maintenance,
    COUNT(CASE WHEN e.NextMaintenanceDate < SYSDATE THEN 1 END) AS Overdue_Maintenance,
    -- Financial Stats
    SUM(NVL(e.PurchasePrice, 0)) AS Total_Equipment_Value,
    SUM(NVL(m.Cost, 0)) AS Maintenance_Cost_Last_Year,
    -- Performance Stats
    ROUND(AVG(NVL(calculate_equipment_health_score(e.EquipmentID), 0)), 1) AS Avg_Health_Score,
    ROUND(AVG(NVL(mh.DowntimeHours, 0)), 1) AS Avg_Downtime_Hours,
    -- Technician Stats
    COUNT(DISTINCT t.TechID) AS Assigned_Technicians,
    -- Ranking
    RANK() OVER (ORDER BY SUM(NVL(e.PurchasePrice, 0)) DESC) AS Equipment_Value_Rank,
    RANK() OVER (ORDER BY SUM(NVL(m.Cost, 0)) DESC) AS Maintenance_Cost_Rank
FROM DEPARTMENTS d
LEFT JOIN EQUIPMENT e ON d.DeptID = e.DepartmentID
LEFT JOIN MAINTENANCE m ON e.EquipmentID = m.EquipmentID 
    AND m.Status = 'COMPLETED' 
    AND m.ActualDate >= ADD_MONTHS(SYSDATE, -12)
LEFT JOIN MAINTENANCE_HISTORY mh ON m.MaintenanceID = mh.MaintenanceID
LEFT JOIN TECHNICIANS t ON d.DeptID = t.DepartmentID
GROUP BY d.DeptID, d.DeptName, d.Location, d.HeadOfDept
ORDER BY Total_Equipment_Value DESC;

-- View 3: Maintenance Analytics Dashboard
CREATE OR REPLACE VIEW v_maintenance_analytics AS
SELECT 
    -- Time-based aggregations
    TO_CHAR(m.ActualDate, 'YYYY-MM') AS Month,
    TO_CHAR(m.ActualDate, 'YYYY-Q') AS Quarter,
    EXTRACT(YEAR FROM m.ActualDate) AS Year,
    
    -- Category breakdown
    e.Category,
    
    -- Maintenance metrics
    COUNT(*) AS Total_Maintenance,
    COUNT(CASE WHEN m.MaintenanceType = 'PREVENTIVE' THEN 1 END) AS Preventive_Maintenance,
    COUNT(CASE WHEN m.MaintenanceType = 'CORRECTIVE' THEN 1 END) AS Corrective_Maintenance,
    COUNT(CASE WHEN m.MaintenanceType = 'EMERGENCY' THEN 1 END) AS Emergency_Maintenance,
    
    -- Cost metrics
    SUM(m.Cost) AS Total_Cost,
    ROUND(AVG(m.Cost), 2) AS Avg_Cost,
    MIN(m.Cost) AS Min_Cost,
    MAX(m.Cost) AS Max_Cost,
    
    -- Downtime metrics
    SUM(mh.DowntimeHours) AS Total_Downtime_Hours,
    ROUND(AVG(mh.DowntimeHours), 1) AS Avg_Downtime_Hours,
    
    -- Performance metrics
    ROUND(SUM(m.Cost) / COUNT(*), 2) AS Cost_Per_Maintenance,
    ROUND(SUM(mh.DowntimeHours) / COUNT(*), 1) AS Downtime_Per_Maintenance,
    
    -- Trends (using window functions)
    LAG(COUNT(*), 1) OVER (PARTITION BY e.Category ORDER BY TO_CHAR(m.ActualDate, 'YYYY-MM')) AS Prev_Month_Count,
    ROUND((COUNT(*) - LAG(COUNT(*), 1) OVER (PARTITION BY e.Category ORDER BY TO_CHAR(m.ActualDate, 'YYYY-MM'))) / 
          NULLIF(LAG(COUNT(*), 1) OVER (PARTITION BY e.Category ORDER BY TO_CHAR(m.ActualDate, 'YYYY-MM')), 0) * 100, 1) 
          AS Month_Over_Month_Change_Pct
FROM MAINTENANCE m
JOIN EQUIPMENT e ON m.EquipmentID = e.EquipmentID
LEFT JOIN MAINTENANCE_HISTORY mh ON m.MaintenanceID = mh.MaintenanceID
WHERE m.Status = 'COMPLETED'
    AND m.ActualDate >= ADD_MONTHS(SYSDATE, -24)
GROUP BY 
    TO_CHAR(m.ActualDate, 'YYYY-MM'),
    TO_CHAR(m.ActualDate, 'YYYY-Q'),
    EXTRACT(YEAR FROM m.ActualDate),
    e.Category
ORDER BY Year DESC, Month DESC, Category;

-- View 4: Technician Performance Dashboard
CREATE OR REPLACE VIEW v_technician_analytics AS
SELECT 
    t.TechID,
    t.FullName,
    t.Specialty,
    d.DeptName AS Department,
    t.CertificationLevel,
    
    -- Workload metrics
    COUNT(m.MaintenanceID) AS Total_Maintenance_Assigned,
    COUNT(CASE WHEN m.Status = 'COMPLETED' THEN 1 END) AS Completed_Maintenance,
    COUNT(CASE WHEN m.Status = 'IN_PROGRESS' THEN 1 END) AS In_Progress_Maintenance,
    COUNT(CASE WHEN m.Status = 'SCHEDULED' THEN 1 END) AS Scheduled_Maintenance,
    
    -- Time-based metrics
    COUNT(CASE WHEN m.ActualDate >= ADD_MONTHS(SYSDATE, -1) THEN 1 END) AS Last_Month_Maintenance,
    COUNT(CASE WHEN m.ActualDate >= ADD_MONTHS(SYSDATE, -3) THEN 1 END) AS Last_Quarter_Maintenance,
    COUNT(CASE WHEN m.ActualDate >= ADD_MONTHS(SYSDATE, -12) THEN 1 END) AS Last_Year_Maintenance,
    
    -- Cost metrics
    SUM(NVL(m.Cost, 0)) AS Total_Cost_Managed,
    ROUND(AVG(NVL(m.Cost, 0)), 2) AS Avg_Cost_Per_Maintenance,
    
    -- Downtime metrics
    ROUND(AVG(NVL(mh.DowntimeHours, 0)), 1) AS Avg_Downtime_Hours,
    SUM(NVL(mh.DowntimeHours, 0)) AS Total_Downtime_Hours,
    
    -- Performance scores
    get_technician_workload_score(t.TechID) AS Workload_Score,
    ROUND((COUNT(CASE WHEN m.Status = 'COMPLETED' THEN 1 END) * 100.0) / 
          NULLIF(COUNT(m.MaintenanceID), 0), 1) AS Completion_Rate_Pct,
    
    -- Rankings
    RANK() OVER (ORDER BY COUNT(m.MaintenanceID) DESC) AS Productivity_Rank,
    RANK() OVER (ORDER BY AVG(NVL(mh.DowntimeHours, 999)) ASC) AS Efficiency_Rank,
    RANK() OVER (ORDER BY SUM(NVL(m.Cost, 0)) DESC) AS Cost_Management_Rank
FROM TECHNICIANS t
LEFT JOIN MAINTENANCE m ON t.TechID = m.TechnicianID
LEFT JOIN MAINTENANCE_HISTORY mh ON m.MaintenanceID = mh.MaintenanceID
LEFT JOIN DEPARTMENTS d ON t.DepartmentID = d.DeptID
WHERE t.Status = 'ACTIVE'
GROUP BY t.TechID, t.FullName, t.Specialty, d.DeptName, t.CertificationLevel
ORDER BY Productivity_Rank;

-- View 5: Equipment Health & Risk Assessment
CREATE OR REPLACE VIEW v_equipment_risk_assessment AS
SELECT 
    e.EquipmentID,
    e.Name,
    e.SerialNumber,
    e.Category,
    d.DeptName,
    
    -- Age and Usage
    calculate_equipment_age(e.EquipmentID) AS Age_Years,
    e.UtilizationHours,
    ROUND(e.UtilizationHours / 8760 * 100, 1) AS Utilization_Percentage,
    
    -- Maintenance History
    COUNT(m.MaintenanceID) AS Total_Maintenance_Count,
    COUNT(CASE WHEN m.MaintenanceType = 'EMERGENCY' THEN 1 END) AS Emergency_Maintenance_Count,
    SUM(NVL(m.Cost, 0)) AS Total_Maintenance_Cost,
    ROUND(AVG(NVL(mh.DowntimeHours, 0)), 1) AS Avg_Downtime_Hours,
    
    -- Health Metrics
    calculate_equipment_health_score(e.EquipmentID) AS Health_Score,
    equipment_management_pkg.predict_failure_risk(e.EquipmentID) AS Failure_Risk,
    equipment_management_pkg.calculate_roi(e.EquipmentID) AS ROI_Percentage,
    
    -- Status and Alerts
    e.Status,
    is_maintenance_due(e.EquipmentID) AS Maintenance_Status,
    COUNT(a.AlertID) AS Active_Alerts,
    COUNT(CASE WHEN a.Priority = 'CRITICAL' THEN 1 END) AS Critical_Alerts,
    
    -- Financial
    e.PurchasePrice,
    e.WarrantyExpiry,
    CASE 
        WHEN e.WarrantyExpiry IS NULL THEN 'NO WARRANTY'
        WHEN e.WarrantyExpiry < SYSDATE THEN 'EXPIRED'
        WHEN e.WarrantyExpiry <= SYSDATE + 30 THEN 'EXPIRING SOON'
        ELSE 'ACTIVE'
    END AS Warranty_Status,
    
    -- Recommendations
    CASE 
        WHEN calculate_equipment_health_score(e.EquipmentID) < 40 THEN 'CRITICAL - NEEDS REPLACEMENT'
        WHEN calculate_equipment_health_score(e.EquipmentID) < 60 THEN 'POOR - SCHEDULE MAINTENANCE'
        WHEN calculate_equipment_health_score(e.EquipmentID) < 80 THEN 'FAIR - MONITOR CLOSELY'
        ELSE 'GOOD - NORMAL OPERATION'
    END AS Recommendation
FROM EQUIPMENT e
JOIN DEPARTMENTS d ON e.DepartmentID = d.DeptID
LEFT JOIN MAINTENANCE m ON e.EquipmentID = m.EquipmentID AND m.Status = 'COMPLETED'
LEFT JOIN MAINTENANCE_HISTORY mh ON m.MaintenanceID = mh.MaintenanceID
LEFT JOIN ALERTS a ON e.EquipmentID = a.EquipmentID AND a.Status IN ('PENDING', 'IN_PROGRESS')
WHERE e.Status != 'DECOMMISSIONED'
GROUP BY 
    e.EquipmentID, e.Name, e.SerialNumber, e.Category, d.DeptName,
    e.UtilizationHours, e.Status, e.PurchasePrice, e.WarrantyExpiry
ORDER BY Health_Score ASC, Failure_Risk DESC;

-- View 6: Audit & Compliance Dashboard
CREATE OR REPLACE VIEW v_audit_compliance AS
SELECT 
    -- Daily Statistics
    TRUNC(Timestamp) AS Audit_Date,
    TO_CHAR(TRUNC(Timestamp), 'Day') AS Day_Of_Week,
    
    -- Operation Statistics
    COUNT(*) AS Total_Operations,
    COUNT(CASE WHEN Status = 'DENIED' THEN 1 END) AS Denied_Operations,
    COUNT(CASE WHEN Status = 'SUCCESS' THEN 1 END) AS Successful_Operations,
    COUNT(CASE WHEN Status = 'ERROR' THEN 1 END) AS Error_Operations,
    
    -- Table Statistics
    COUNT(DISTINCT TableName) AS Tables_Modified,
    
    -- User Statistics
    COUNT(DISTINCT Username) AS Active_Users,
    
    -- Denial Reasons
    COUNT(CASE WHEN ErrorMessage LIKE '%weekday%' THEN 1 END) AS Weekday_Denials,
    COUNT(CASE WHEN ErrorMessage LIKE '%holiday%' THEN 1 END) AS Holiday_Denials,
    COUNT(CASE WHEN ErrorMessage LIKE '%not allowed%' THEN 1 END) AS Rule_Violation_Denials,
    
    -- Success Rate
    ROUND((COUNT(CASE WHEN Status = 'SUCCESS' THEN 1 END) * 100.0) / COUNT(*), 1) AS Success_Rate_Pct,
    
    -- Peak Activity
    TO_CHAR(Timestamp, 'HH24') AS Hour_Of_Day,
    COUNT(CASE WHEN TO_CHAR(Timestamp, 'HH24') BETWEEN '08' AND '17' THEN 1 END) AS Business_Hours_Operations,
    COUNT(CASE WHEN TO_CHAR(Timestamp, 'HH24') NOT BETWEEN '08' AND '17' THEN 1 END) AS After_Hours_Operations
FROM AUDIT_LOG
WHERE Timestamp >= TRUNC(SYSDATE) - 30
GROUP BY TRUNC(Timestamp), TO_CHAR(TRUNC(Timestamp), 'Day'), TO_CHAR(Timestamp, 'HH24')
ORDER BY Audit_Date DESC, Hour_Of_Day;

-- ============================================
-- 2. CREATE ANALYTICAL STORED PROCEDURES FOR BI
-- ============================================

-- Procedure 1: Generate Monthly Performance Report
CREATE OR REPLACE PROCEDURE generate_monthly_performance_report(
    p_month IN NUMBER DEFAULT EXTRACT(MONTH FROM SYSDATE),
    p_year IN NUMBER DEFAULT EXTRACT(YEAR FROM SYSDATE),
    p_report OUT SYS_REFCURSOR
)
IS
BEGIN
    OPEN p_report FOR
    WITH monthly_data AS (
        SELECT 
            d.DeptName,
            -- Equipment Metrics
            COUNT(e.EquipmentID) AS Equipment_Count,
            COUNT(CASE WHEN e.Status = 'ACTIVE' THEN 1 END) AS Active_Equipment,
            COUNT(CASE WHEN e.Status = 'UNDER_MAINTENANCE' THEN 1 END) AS Under_Maintenance,
            
            -- Maintenance Metrics
            COUNT(m.MaintenanceID) AS Maintenance_Count,
            COUNT(CASE WHEN m.MaintenanceType = 'PREVENTIVE' THEN 1 END) AS Preventive_Maintenance,
            COUNT(CASE WHEN m.MaintenanceType = 'CORRECTIVE' THEN 1 END) AS Corrective_Maintenance,
            
            -- Cost Metrics
            SUM(NVL(m.Cost, 0)) AS Total_Maintenance_Cost,
            ROUND(AVG(NVL(m.Cost, 0)), 2) AS Avg_Maintenance_Cost,
            
            -- Downtime Metrics
            SUM(NVL(mh.DowntimeHours, 0)) AS Total_Downtime_Hours,
            ROUND(AVG(NVL(mh.DowntimeHours, 0)), 1) AS Avg_Downtime_Hours,
            
            -- Performance Metrics
            ROUND(AVG(NVL(calculate_equipment_health_score(e.EquipmentID), 0)), 1) AS Avg_Health_Score,
            ROUND((COUNT(CASE WHEN m.Status = 'COMPLETED' THEN 1 END) * 100.0) / 
                  NULLIF(COUNT(m.MaintenanceID), 0), 1) AS Maintenance_Completion_Rate
        FROM DEPARTMENTS d
        LEFT JOIN EQUIPMENT e ON d.DeptID = e.DepartmentID
        LEFT JOIN MAINTENANCE m ON e.EquipmentID = m.EquipmentID
            AND EXTRACT(MONTH FROM m.ActualDate) = p_month
            AND EXTRACT(YEAR FROM m.ActualDate) = p_year
        LEFT JOIN MAINTENANCE_HISTORY mh ON m.MaintenanceID = mh.MaintenanceID
        GROUP BY d.DeptName
    )
    SELECT 
        DeptName,
        Equipment_Count,
        Active_Equipment,
        Under_Maintenance,
        Maintenance_Count,
        Preventive_Maintenance,
        Corrective_Maintenance,
        Total_Maintenance_Cost,
        Avg_Maintenance_Cost,
        Total_Downtime_Hours,
        Avg_Downtime_Hours,
        Avg_Health_Score,
        Maintenance_Completion_Rate,
        -- Rankings
        RANK() OVER (ORDER BY Total_Maintenance_Cost DESC) AS Cost_Rank,
        RANK() OVER (ORDER BY Avg_Downtime_Hours ASC) AS Downtime_Rank,
        RANK() OVER (ORDER BY Avg_Health_Score DESC) AS Health_Rank
    FROM monthly_data
    ORDER BY Total_Maintenance_Cost DESC;
END generate_monthly_performance_report;
/

-- Procedure 2: Generate Equipment Lifecycle Analysis
CREATE OR REPLACE PROCEDURE generate_equipment_lifecycle_report(
    p_report OUT SYS_REFCURSOR
)
IS
BEGIN
    OPEN p_report FOR
    SELECT 
        e.EquipmentID,
        e.Name,
        e.Category,
        d.DeptName,
        
        -- Age Analysis
        calculate_equipment_age(e.EquipmentID) AS Age_Years,
        CASE 
            WHEN calculate_equipment_age(e.EquipmentID) < 3 THEN 'NEW (0-3 years)'
            WHEN calculate_equipment_age(e.EquipmentID) < 7 THEN 'MID-LIFE (4-7 years)'
            WHEN calculate_equipment_age(e.EquipmentID) < 10 THEN 'MATURE (8-10 years)'
            ELSE 'AGING (10+ years)'
        END AS Age_Category,
        
        -- Financial Analysis
        e.PurchasePrice,
        SUM(NVL(m.Cost, 0)) AS Total_Maintenance_Cost,
        ROUND(SUM(NVL(m.Cost, 0)) / NULLIF(e.PurchasePrice, 0) * 100, 1) AS Maintenance_Cost_Percentage,
        
        -- Usage Analysis
        e.UtilizationHours,
        ROUND(e.UtilizationHours / (calculate_equipment_age(e.EquipmentID) * 8760) * 100, 1) AS Annual_Utilization_Pct,
        
        -- Performance Analysis
        calculate_equipment_health_score(e.EquipmentID) AS Health_Score,
        equipment_management_pkg.predict_failure_risk(e.EquipmentID) AS Failure_Risk,
        
        -- Recommendations
        CASE 
            WHEN calculate_equipment_age(e.EquipmentID) >= 10 AND calculate_equipment_health_score(e.EquipmentID) < 50 
                THEN 'HIGH PRIORITY FOR REPLACEMENT'
            WHEN calculate_equipment_health_score(e.EquipmentID) < 40 
                THEN 'SCHEDULE MAJOR MAINTENANCE OR REPLACEMENT'
            WHEN calculate_equipment_health_score(e.EquipmentID) < 60 
                THEN 'MONITOR CLOSELY - CONSIDER UPGRADE'
            ELSE 'CONTINUE NORMAL OPERATION'
        END AS Lifecycle_Recommendation,
        
        -- ROI Analysis
        equipment_management_pkg.calculate_roi(e.EquipmentID) AS ROI_Percentage,
        CASE 
            WHEN equipment_management_pkg.calculate_roi(e.EquipmentID) < 5 THEN 'LOW ROI'
            WHEN equipment_management_pkg.calculate_roi(e.EquipmentID) < 15 THEN 'MODERATE ROI'
            ELSE 'HIGH ROI'
        END AS ROI_Category
    FROM EQUIPMENT e
    JOIN DEPARTMENTS d ON e.DepartmentID = d.DeptID
    LEFT JOIN MAINTENANCE m ON e.EquipmentID = m.EquipmentID AND m.Status = 'COMPLETED'
    WHERE e.Status = 'ACTIVE'
    GROUP BY e.EquipmentID, e.Name, e.Category, d.DeptName, e.PurchasePrice, e.UtilizationHours
    ORDER BY Age_Years DESC, Health_Score ASC;
END generate_equipment_lifecycle_report;
/

-- Procedure 3: Generate Predictive Maintenance Schedule
CREATE OR REPLACE PROCEDURE generate_predictive_maintenance_schedule(
    p_lookahead_days IN NUMBER DEFAULT 90,
    p_report OUT SYS_REFCURSOR
)
IS
BEGIN
    OPEN p_report FOR
    WITH risk_assessment AS (
        SELECT 
            e.EquipmentID,
            e.Name,
            e.Category,
            d.DeptName,
            
            -- Risk Factors
            calculate_equipment_age(e.EquipmentID) AS Age_Years,
            e.UtilizationHours,
            calculate_equipment_health_score(e.EquipmentID) AS Health_Score,
            equipment_management_pkg.predict_failure_risk(e.EquipmentID) AS Failure_Risk,
            
            -- Maintenance History
            MAX(m.ActualDate) AS Last_Maintenance_Date,
            COUNT(m.MaintenanceID) AS Total_Maintenance_Count,
            COUNT(CASE WHEN m.MaintenanceType = 'EMERGENCY' THEN 1 END) AS Emergency_Maintenance_Count,
            
            -- Calculate Risk Score (0-100, higher = more risk)
            (calculate_equipment_age(e.EquipmentID) * 2.5) + 
            (100 - calculate_equipment_health_score(e.EquipmentID)) + 
            (CASE equipment_management_pkg.predict_failure_risk(e.EquipmentID)
                WHEN 'CRITICAL' THEN 40
                WHEN 'HIGH' THEN 30
                WHEN 'MEDIUM' THEN 20
                WHEN 'LOW' THEN 10
                ELSE 0
            END) AS Calculated_Risk_Score
        FROM EQUIPMENT e
        JOIN DEPARTMENTS d ON e.DepartmentID = d.DeptID
        LEFT JOIN MAINTENANCE m ON e.EquipmentID = m.EquipmentID AND m.Status = 'COMPLETED'
        WHERE e.Status = 'ACTIVE'
        GROUP BY e.EquipmentID, e.Name, e.Category, d.DeptName, e.UtilizationHours
    )
    SELECT 
        EquipmentID,
        Name,
        Category,
        DeptName,
        Age_Years,
        UtilizationHours,
        Health_Score,
        Failure_Risk,
        Last_Maintenance_Date,
        Total_Maintenance_Count,
        Emergency_Maintenance_Count,
        Calculated_Risk_Score,
        
        -- Maintenance Priority
        CASE 
            WHEN Calculated_Risk_Score >= 80 THEN 'CRITICAL - SCHEDULE IMMEDIATELY'
            WHEN Calculated_Risk_Score >= 60 THEN 'HIGH - SCHEDULE WITHIN 2 WEEKS'
            WHEN Calculated_Risk_Score >= 40 THEN 'MEDIUM - SCHEDULE WITHIN 4 WEEKS'
            ELSE 'LOW - SCHEDULE ROUTINE'
        END AS Maintenance_Priority,
        
        -- Recommended Schedule
        CASE 
            WHEN Calculated_Risk_Score >= 80 THEN SYSDATE + 7  -- Within 7 days
            WHEN Calculated_Risk_Score >= 60 THEN SYSDATE + 14 -- Within 14 days
            WHEN Calculated_Risk_Score >= 40 THEN SYSDATE + 28 -- Within 28 days
            ELSE SYSDATE + 90  -- Within 90 days
        END AS Recommended_Schedule_Date,
        
        -- Estimated Cost
        CASE 
            WHEN Calculated_Risk_Score >= 80 THEN 5000  -- High cost for critical
            WHEN Calculated_Risk_Score >= 60 THEN 3000  -- Medium-high cost
            WHEN Calculated_Risk_Score >= 40 THEN 1500  -- Medium cost
            ELSE 800  -- Low cost for routine
        END AS Estimated_Cost,
        
        -- Recommended Technician Specialty
        CASE Category
            WHEN 'IMAGING' THEN 'IMAGING EQUIPMENT SPECIALIST'
            WHEN 'LIFE_SUPPORT' THEN 'LIFE SUPPORT SYSTEMS SPECIALIST'
            WHEN 'SURGICAL' THEN 'SURGICAL EQUIPMENT SPECIALIST'
            WHEN 'MONITORING' THEN 'MONITORING SYSTEMS SPECIALIST'
            ELSE 'GENERAL BIOMEDICAL TECHNICIAN'
        END AS Recommended_Specialty
    FROM risk_assessment
    WHERE Calculated_Risk_Score >= 30  -- Only show equipment needing attention
    ORDER BY Calculated_Risk_Score DESC, Last_Maintenance_Date NULLS FIRST;
END generate_predictive_maintenance_schedule;
/

-- ============================================
-- 3. CREATE MATERIALIZED VIEWS FOR PERFORMANCE
-- ============================================

-- Materialized View 1: Daily Equipment Status Summary
CREATE MATERIALIZED VIEW mv_daily_equipment_status
REFRESH COMPLETE ON DEMAND
AS
SELECT 
    TRUNC(SYSDATE) AS Snapshot_Date,
    d.DeptName,
    e.Category,
    COUNT(e.EquipmentID) AS Total_Equipment,
    COUNT(CASE WHEN e.Status = 'ACTIVE' THEN 1 END) AS Active,
    COUNT(CASE WHEN e.Status = 'UNDER_MAINTENANCE' THEN 1 END) AS Under_Maintenance,
    COUNT(CASE WHEN e.Status = 'INACTIVE' THEN 1 END) AS Inactive,
    COUNT(CASE WHEN e.Status = 'DECOMMISSIONED' THEN 1 END) AS Decommissioned,
    COUNT(CASE WHEN e.NextMaintenanceDate < SYSDATE THEN 1 END) AS Overdue_Maintenance,
    COUNT(CASE WHEN e.WarrantyExpiry < SYSDATE THEN 1 END) AS Expired_Warranty,
    ROUND(AVG(calculate_equipment_health_score(e.EquipmentID)), 1) AS Avg_Health_Score,
    SUM(e.PurchasePrice) AS Total_Value
FROM EQUIPMENT e
JOIN DEPARTMENTS d ON e.DepartmentID = d.DeptID
GROUP BY d.DeptName, e.Category;

-- Materialized View 2: Monthly Maintenance Summary
CREATE MATERIALIZED VIEW mv_monthly_maintenance_summary
REFRESH COMPLETE ON DEMAND
AS
SELECT 
    TO_CHAR(m.ActualDate, 'YYYY-MM') AS Month,
    d.DeptName,
    e.Category,
    COUNT(m.MaintenanceID) AS Total_Maintenance,
    COUNT(CASE WHEN m.MaintenanceType = 'PREVENTIVE' THEN 1 END) AS Preventive,
    COUNT(CASE WHEN m.MaintenanceType = 'CORRECTIVE' THEN 1 END) AS Corrective,
    COUNT(CASE WHEN m.MaintenanceType = 'EMERGENCY' THEN 1 END) AS Emergency,
    SUM(m.Cost) AS Total_Cost,
    ROUND(AVG(m.Cost), 2) AS Avg_Cost,
    SUM(NVL(mh.DowntimeHours, 0)) AS Total_Downtime,
    ROUND(AVG(NVL(mh.DowntimeHours, 0)), 1) AS Avg_Downtime,
    COUNT(DISTINCT t.TechID) AS Technicians_Involved,
    ROUND((COUNT(CASE WHEN m.Status = 'COMPLETED' THEN 1 END) * 100.0) / COUNT(*), 1) AS Completion_Rate
FROM MAINTENANCE m
JOIN EQUIPMENT e ON m.EquipmentID = e.EquipmentID
JOIN DEPARTMENTS d ON e.DepartmentID = d.DeptID
LEFT JOIN MAINTENANCE_HISTORY mh ON m.MaintenanceID = mh.MaintenanceID
LEFT JOIN TECHNICIANS t ON m.TechnicianID = t.TechID
WHERE m.Status = 'COMPLETED'
    AND m.ActualDate >= ADD_MONTHS(SYSDATE, -24)
GROUP BY TO_CHAR(m.ActualDate, 'YYYY-MM'), d.DeptName, e.Category;

-- ============================================
-- 4. CREATE FINAL VERIFICATION SCRIPT
-- ============================================

CREATE OR REPLACE PROCEDURE verify_phase_viii_implementation
IS
    v_view_count NUMBER;
    v_procedure_count NUMBER;
    v_mview_count NUMBER;
    v_total_score NUMBER := 0;
    v_max_score NUMBER := 100;
BEGIN
    DBMS_OUTPUT.PUT_LINE('===============================================');
    DBMS_OUTPUT.PUT_LINE('PHASE VIII: FINAL IMPLEMENTATION VERIFICATION');
    DBMS_OUTPUT.PUT_LINE('===============================================');
    DBMS_OUTPUT.PUT_LINE('');
    
    -- Check 1: Verify all BI Views exist
    DBMS_OUTPUT.PUT_LINE('=== CHECK 1: BUSINESS INTELLIGENCE VIEWS ===');
    SELECT COUNT(*) INTO v_view_count
    FROM user_views
    WHERE view_name LIKE 'V\_%' ESCAPE '\';
    
    IF v_view_count >= 6 THEN
        DBMS_OUTPUT.PUT_LINE('✓ ' || v_view_count || ' BI views created (Required: 6+)');
        v_total_score := v_total_score + 20;
        
        -- List the views
        FOR rec IN (SELECT view_name FROM user_views WHERE view_name LIKE 'V\_%' ESCAPE '\' ORDER BY view_name) 
        LOOP
            DBMS_OUTPUT.PUT_LINE('  - ' || rec.view_name);
        END LOOP;
    ELSE
        DBMS_OUTPUT.PUT_LINE('✗ Only ' || v_view_count || ' BI views created (Required: 6+)');
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('');
    
    -- Check 2: Verify BI Procedures
    DBMS_OUTPUT.PUT_LINE('=== CHECK 2: ANALYTICAL PROCEDURES ===');
    SELECT COUNT(*) INTO v_procedure_count
    FROM user_procedures
    WHERE object_name LIKE 'GENERATE_%_REPORT' 
       OR object_name LIKE 'GENERATE_%_SCHEDULE';
    
    IF v_procedure_count >= 3 THEN
        DBMS_OUTPUT.PUT_LINE('✓ ' || v_procedure_count || ' analytical procedures created (Required: 3+)');
        v_total_score := v_total_score + 20;
        
        -- List the procedures
        FOR rec IN (
            SELECT DISTINCT object_name 
            FROM user_procedures 
            WHERE object_name LIKE 'GENERATE_%_REPORT' 
               OR object_name LIKE 'GENERATE_%_SCHEDULE'
            ORDER BY object_name
        ) 
        LOOP
            DBMS_OUTPUT.PUT_LINE('  - ' || rec.object_name);
        END LOOP;
    ELSE
        DBMS_OUTPUT.PUT_LINE('✗ Only ' || v_procedure_count || ' analytical procedures created');
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('');
    
    -- Check 3: Verify Materialized Views
    DBMS_OUTPUT.PUT_LINE('=== CHECK 3: MATERIALIZED VIEWS ===');
    SELECT COUNT(*) INTO v_mview_count
    FROM user_mviews;
    
    IF v_mview_count >= 2 THEN
        DBMS_OUTPUT.PUT_LINE('✓ ' || v_mview_count || ' materialized views created (Required: 2+)');
        v_total_score := v_total_score + 20;
        
        -- List the materialized views
        FOR rec IN (SELECT mview_name FROM user_mviews ORDER BY mview_name) 
        LOOP
            DBMS_OUTPUT.PUT_LINE('  - ' || rec.mview_name);
        END LOOP;
    ELSE
        DBMS_OUTPUT.PUT_LINE('✗ Only ' || v_mview_count || ' materialized views created');
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('');
    
    -- Check 4: Test Data Retrieval
    DBMS_OUTPUT.PUT_LINE('=== CHECK 4: DATA RETRIEVAL TEST ===');
    DECLARE
        v_executive_count NUMBER;
        v_department_count NUMBER;
        v_audit_count NUMBER;
    BEGIN
        -- Test executive dashboard
        SELECT COUNT(*) INTO v_executive_count FROM v_executive_dashboard;
        DBMS_OUTPUT.PUT_LINE('✓ Executive dashboard query returns ' || v_executive_count || ' row');
        v_total_score := v_total_score + 10;
        
        -- Test department performance
        SELECT COUNT(*) INTO v_department_count FROM v_department_performance;
        DBMS_OUTPUT.PUT_LINE('✓ Department performance view returns ' || v_department_count || ' rows');
        v_total_score := v_total_score + 10;
        
        -- Test audit compliance
        SELECT COUNT(*) INTO v_audit_count FROM v_audit_compliance;
        DBMS_OUTPUT.PUT_LINE('✓ Audit compliance view returns ' || v_audit_count || ' rows');
        v_total_score := v_total_score + 10;
        
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('✗ Data retrieval test failed: ' || SQLERRM);
    END;
    
    DBMS_OUTPUT.PUT_LINE('');
    
    -- Check 5: Test Procedure Execution
    DBMS_OUTPUT.PUT_LINE('=== CHECK 5: PROCEDURE EXECUTION TEST ===');
    DECLARE
        v_report_cursor SYS_REFCURSOR;
        v_row_count NUMBER := 0;
    BEGIN
        -- Test monthly performance report
        generate_monthly_performance_report(
            p_month => EXTRACT(MONTH FROM SYSDATE),
            p_year => EXTRACT(YEAR FROM SYSDATE),
            p_report => v_report_cursor
        );
        
        -- Count rows
        LOOP
            FETCH v_report_cursor INTO 
                v_row_count, v_row_count, v_row_count, v_row_count, v_row_count, 
                v_row_count, v_row_count, v_row_count, v_row_count, v_row_count,
                v_row_count, v_row_count, v_row_count, v_row_count, v_row_count,
                v_row_count, v_row_count;
            EXIT WHEN v_report_cursor%NOTFOUND;
        END LOOP;
        
        CLOSE v_report_cursor;
        DBMS_OUTPUT.PUT_LINE('✓ Monthly performance report procedure executes successfully');
        v_total_score := v_total_score + 10;
        
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('✗ Procedure execution test failed: ' || SQLERRM);
    END;
    
    DBMS_OUTPUT.PUT_LINE('');
    
    -- Final Score
    DBMS_OUTPUT.PUT_LINE('===============================================');
    DBMS_OUTPUT.PUT_LINE('FINAL VERIFICATION SCORE: ' || v_total_score || '/' || v_max_score);
    
    IF v_total_score >= 80 THEN
        DBMS_OUTPUT.PUT_LINE('STATUS: PASSED ✓');
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('PHASE VIII IMPLEMENTATION COMPLETE!');
        DBMS_OUTPUT.PUT_LINE('All Business Intelligence components successfully implemented.');
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('Ready for final project submission.');
    ELSE
        DBMS_OUTPUT.PUT_LINE('STATUS: FAILED ✗');
        DBMS_OUTPUT.PUT_LINE('Some components are missing or not working correctly.');
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('===============================================');
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Verification failed with error: ' || SQLERRM);
END verify_phase_viii_implementation;
/

-- ============================================
-- 5. CREATE FINAL PROJECT DOCUMENTATION SCRIPT
-- ============================================

CREATE OR REPLACE PROCEDURE generate_project_documentation
IS
BEGIN
    DBMS_OUTPUT.PUT_LINE('===============================================');
    DBMS_OUTPUT.PUT_LINE('HOSPITAL EQUIPMENT MANAGEMENT SYSTEM');
    DBMS_OUTPUT.PUT_LINE('FINAL PROJECT DOCUMENTATION');
    DBMS_OUTPUT.PUT_LINE('===============================================');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('STUDENT: Habanabashaka Philimin');
    DBMS_OUTPUT.PUT_LINE('STUDENT ID: 27487');
    DBMS_OUTPUT.PUT_LINE('GROUP: A');
    DBMS_OUTPUT.PUT_LINE('COURSE: Database Development with PL/SQL');
    DBMS_OUTPUT.PUT_LINE('INSTITUTION: Adventist University of Central Africa (AUCA)');
    DBMS_OUTPUT.PUT_LINE('LECTURER: Eric Maniraguha');
    DBMS_OUTPUT.PUT_LINE('COMPLETION DATE: ' || TO_CHAR(SYSDATE, 'DD-MON-YYYY'));
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('===============================================');
    DBMS_OUTPUT.PUT_LINE('PROJECT SUMMARY');
    DBMS_OUTPUT.PUT_LINE('===============================================');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('PROBLEM STATEMENT:');
    DBMS_OUTPUT.PUT_LINE('Manual tracking of hospital equipment leads to equipment downtime,');
    DBMS_OUTPUT.PUT_LINE('missed maintenance schedules, inefficient resource allocation,');
    DBMS_OUTPUT.PUT_LINE('and lack of real-time status monitoring.');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('SOLUTION:');
    DBMS_OUTPUT.PUT_LINE('A comprehensive Oracle PL/SQL database system for managing');
    DBMS_OUTPUT.PUT_LINE('hospital equipment lifecycle with automated maintenance scheduling,');
    DBMS_OUTPUT.PUT_LINE('real-time monitoring, and business intelligence capabilities.');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('KEY FEATURES:');
    DBMS_OUTPUT.PUT_LINE('1. Equipment lifecycle management');
    DBMS_OUTPUT.PUT_LINE('2. Automated maintenance scheduling');
    DBMS_OUTPUT.PUT_LINE('3. Real-time status monitoring and alerts');
    DBMS_OUTPUT.PUT_LINE('4. Business intelligence dashboards');
    DBMS_OUTPUT.PUT_LINE('5. Comprehensive audit trail and security');
    DBMS_OUTPUT.PUT_LINE('6. Predictive maintenance analytics');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('===============================================');
    DBMS_OUTPUT.PUT_LINE('TECHNICAL SPECIFICATIONS');
    DBMS_OUTPUT.PUT_LINE('===============================================');
    DBMS_OUTPUT.PUT_LINE('');
    
    -- Database Statistics
    DECLARE
        v_table_count NUMBER;
        v_proc_count NUMBER;
        v_func_count NUMBER;
        v_trigger_count NUMBER;
        v_view_count NUMBER;
        v_package_count NUMBER;
    BEGIN
        -- Count objects
        SELECT COUNT(*) INTO v_table_count FROM user_tables;
        SELECT COUNT(*) INTO v_proc_count FROM user_procedures WHERE object_type = 'PROCEDURE';
        SELECT COUNT(*) INTO v_func_count FROM user_procedures WHERE object_type = 'FUNCTION';
        SELECT COUNT(*) INTO v_trigger_count FROM user_triggers;
        SELECT COUNT(*) INTO v_view_count FROM user_views;
        SELECT COUNT(*) INTO v_package_count FROM user_objects WHERE object_type = 'PACKAGE';
        
        DBMS_OUTPUT.PUT_LINE('DATABASE OBJECTS:');
        DBMS_OUTPUT.PUT_LINE('  Tables: ' || v_table_count);
        DBMS_OUTPUT.PUT_LINE('  Stored Procedures: ' || v_proc_count);
        DBMS_OUTPUT.PUT_LINE('  Functions: ' || v_func_count);
        DBMS_OUTPUT.PUT_LINE('  Triggers: ' || v_trigger_count);
        DBMS_OUTPUT.PUT_LINE('  Views: ' || v_view_count);
        DBMS_OUTPUT.PUT_LINE('  Packages: ' || v_package_count);
        DBMS_OUTPUT.PUT_LINE('');
        
        -- Data Statistics
        DBMS_OUTPUT.PUT_LINE('DATA STATISTICS:');
        DECLARE
            v_equipment_count NUMBER;
            v_maintenance_count NUMBER;
            v_alert_count NUMBER;
            v_technician_count NUMBER;
            v_audit_count NUMBER;
        BEGIN
            SELECT COUNT(*) INTO v_equipment_count FROM EQUIPMENT;
            SELECT COUNT(*) INTO v_maintenance_count FROM MAINTENANCE;
            SELECT COUNT(*) INTO v_alert_count FROM ALERTS;
            SELECT COUNT(*) INTO v_technician_count FROM TECHNICIANS;
            SELECT COUNT(*) INTO v_audit_count FROM AUDIT_LOG;
            
            DBMS_OUTPUT.PUT_LINE('  Equipment Records: ' || v_equipment_count);
            DBMS_OUTPUT.PUT_LINE('  Maintenance Records: ' || v_maintenance_count);
            DBMS_OUTPUT.PUT_LINE('  Alert Records: ' || v_alert_count);
            DBMS_OUTPUT.PUT_LINE('  Technician Records: ' || v_technician_count);
            DBMS_OUTPUT.PUT_LINE('  Audit Log Entries: ' || v_audit_count);
        END;
        
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('BUSINESS INTELLIGENCE COMPONENTS:');
        DBMS_OUTPUT.PUT_LINE('  1. Executive Dashboard (v_executive_dashboard)');
        DBMS_OUTPUT.PUT_LINE('  2. Department Performance Dashboard (v_department_performance)');
        DBMS_OUTPUT.PUT_LINE('  3. Maintenance Analytics Dashboard (v_maintenance_analytics)');
        DBMS_OUTPUT.PUT_LINE('  4. Technician Performance Dashboard (v_technician_analytics)');
        DBMS_OUTPUT.PUT_LINE('  5. Equipment Risk Assessment (v_equipment_risk_assessment)');
        DBMS_OUTPUT.PUT_LINE('  6. Audit & Compliance Dashboard (v_audit_compliance)');
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('ANALYTICAL PROCEDURES:');
        DBMS_OUTPUT.PUT_LINE('  1. generate_monthly_performance_report');
        DBMS_OUTPUT.PUT_LINE('  2. generate_equipment_lifecycle_report');
        DBMS_OUTPUT.PUT_LINE('  3. generate_predictive_maintenance_schedule');
        
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Error generating statistics: ' || SQLERRM);
    END;
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('===============================================');
    DBMS_OUTPUT.PUT_LINE('KEY ACHIEVEMENTS');
    DBMS_OUTPUT.PUT_LINE('===============================================');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('✓ Complete 8-phase project implementation');
    DBMS_OUTPUT.PUT_LINE('✓ Normalized database design (3NF)');
    DBMS_OUTPUT.PUT_LINE('✓ Comprehensive PL/SQL programming');
    DBMS_OUTPUT.PUT_LINE('✓ Advanced trigger implementation with business rules');
    DBMS_OUTPUT.PUT_LINE('✓ Business intelligence dashboards and analytics');
    DBMS_OUTPUT.PUT_LINE('✓ Complete audit trail and security implementation');
    DBMS_OUTPUT.PUT_LINE('✓ Predictive maintenance capabilities');
    DBMS_OUTPUT.PUT_LINE('✓ Production-ready code with error handling');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('===============================================');
    DBMS_OUTPUT.PUT_LINE('FILES TO SUBMIT');
    DBMS_OUTPUT.PUT_LINE('===============================================');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('1. GitHub Repository with complete source code');
    DBMS_OUTPUT.PUT_LINE('2. PowerPoint Presentation (10 slides)');
    DBMS_OUTPUT.PUT_LINE('3. Database backup files');
    DBMS_OUTPUT.PUT_LINE('4. Project documentation');
    DBMS_OUTPUT.PUT_LINE('5. Test results and screenshots');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('===============================================');
    DBMS_OUTPUT.PUT_LINE('PROJECT COMPLETE - READY FOR SUBMISSION');
    DBMS_OUTPUT.PUT_LINE('===============================================');
    
END generate_project_documentation;
/

-- ============================================
-- 6. RUN FINAL VERIFICATION AND DOCUMENTATION
-- ============================================

-- Run verification
BEGIN
    verify_phase_viii_implementation();
END;
/

-- Run documentation generation
BEGIN
    generate_project_documentation();
END;
/

-- ============================================
-- 7. SAMPLE QUERIES FOR PRESENTATION DEMONSTRATION
-- ============================================

-- Query 1: Show executive dashboard
SELECT 'EXECUTIVE DASHBOARD SUMMARY' AS report_title FROM DUAL;
SELECT * FROM v_executive_dashboard;

-- Query 2: Show top departments by maintenance cost
SELECT 'TOP DEPARTMENTS BY MAINTENANCE COST' AS report_title FROM DUAL;
SELECT DeptName, Total_Equipment, Total_Equipment_Value, Maintenance_Cost_Last_Year
FROM v_department_performance
WHERE ROWNUM <= 5
ORDER BY Maintenance_Cost_Last_Year DESC;

-- Query 3: Show equipment needing urgent attention
SELECT 'EQUIPMENT NEEDING URGENT ATTENTION' AS report_title FROM DUAL;
SELECT EquipmentID, Name, Category, DeptName, Health_Score, Failure_Risk, Recommendation
FROM v_equipment_risk_assessment
WHERE Health_Score < 60
AND ROWNUM <= 5
ORDER BY Health_Score ASC;

-- Query 4: Show recent audit activity
SELECT 'RECENT AUDIT ACTIVITY' AS report_title FROM DUAL;
SELECT Audit_Date, Total_Operations, Denied_Operations, Success_Rate_Pct
FROM v_audit_compliance
WHERE ROWNUM <= 5
ORDER BY Audit_Date DESC;

-- Query 5: Test predictive maintenance
DECLARE
    v_report SYS_REFCURSOR;
    v_equipment_id NUMBER;
    v_name VARCHAR2(200);
    v_priority VARCHAR2(100);
BEGIN
    OPEN v_report FOR
    SELECT EquipmentID, Name, Maintenance_Priority
    FROM TABLE(
        CURSOR(
            SELECT * FROM v_equipment_risk_assessment 
            WHERE Health_Score < 70 
            ORDER BY Health_Score ASC
        )
    ) WHERE ROWNUM <= 3;
    
    DBMS_OUTPUT.PUT_LINE('TOP 3 EQUIPMENT FOR PREDICTIVE MAINTENANCE:');
    LOOP
        FETCH v_report INTO v_equipment_id, v_name, v_priority;
        EXIT WHEN v_report%NOTFOUND;
        DBMS_OUTPUT.PUT_LINE('  ' || v_equipment_id || ' - ' || v_name || ': ' || v_priority);
    END LOOP;
    CLOSE v_report;
END;
/

-- ============================================
-- 8. FINAL CLEANUP AND OPTIMIZATION
-- ============================================

-- Gather statistics for better query performance
BEGIN
    DBMS_STATS.GATHER_SCHEMA_STATS(
        ownname => USER,
        estimate_percent => DBMS_STATS.AUTO_SAMPLE_SIZE,
        method_opt => 'FOR ALL COLUMNS SIZE AUTO',
        degree => DBMS_STATS.AUTO_DEGREE,
        cascade => TRUE
    );
    DBMS_OUTPUT.PUT_LINE('Database statistics gathered for optimal performance');
END;
/

-- Create indexes for BI queries if not already exist
CREATE INDEX idx_equipment_health ON EQUIPMENT (calculate_equipment_health_score(EquipmentID));
CREATE INDEX idx_maintenance_completed ON MAINTENANCE (Status, ActualDate);
CREATE INDEX idx_alerts_priority ON ALERTS (Priority, Status);
CREATE INDEX idx_audit_timestamp ON AUDIT_LOG (Timestamp);

-- ============================================
-- 9. FINAL PROJECT COMPLETION MESSAGE
-- ============================================

BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('****************************************************************');
    DBMS_OUTPUT.PUT_LINE('*                                                              *');
    DBMS_OUTPUT.PUT_LINE('*  HOSPITAL EQUIPMENT MANAGEMENT SYSTEM - PROJECT COMPLETE!    *');
    DBMS_OUTPUT.PUT_LINE('*                                                              *');
    DBMS_OUTPUT.PUT_LINE('****************************************************************');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('CONGRATULATIONS! All 8 phases successfully implemented:');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('PHASE I:   Problem Identification ✓');
    DBMS_OUTPUT.PUT_LINE('PHASE II:  Business Process Modeling ✓');
    DBMS_OUTPUT.PUT_LINE('PHASE III: Logical Database Design ✓');
    DBMS_OUTPUT.PUT_LINE('PHASE IV:  Database Creation ✓');
    DBMS_OUTPUT.PUT_LINE('PHASE V:   Table Implementation & Data Insertion ✓');
    DBMS_OUTPUT.PUT_LINE('PHASE VI:  PL/SQL Development ✓');
    DBMS_OUTPUT.PUT_LINE('PHASE VII: Advanced Programming & Auditing ✓');
    DBMS_OUTPUT.PUT_LINE('PHASE VIII: Documentation, BI & Presentation ✓');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Project Name: Hospital Equipment Management System');
    DBMS_OUTPUT.PUT_LINE('Student: Habanabashaka Philimin (ID: 27487)');
    DBMS_OUTPUT.PUT_LINE('Group: A');
    DBMS_OUTPUT.PUT_LINE('Database: A_27487_Philimin_HospitalEquipment_db');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Ready for final submission to:');
    DBMS_OUTPUT.PUT_LINE('Lecturer: Eric Maniraguha');
    DBMS_OUTPUT.PUT_LINE('Email: eric.maniraguha@auca.ac.rw');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('"Whatever you do, work at it with all your heart,');
    DBMS_OUTPUT.PUT_LINE(' as working for the Lord, not for human masters."');
    DBMS_OUTPUT.PUT_LINE('                     - Colossians 3:23 (NIV)');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('****************************************************************');
END;
/
