-- =====================================================================
-- Project: EV Charging Station Management System
-- Script: 07_demo_queries.sql
-- Description: 32 comprehensive, categorized demonstration SQL queries
--              covering Basic CRUD, Joins, Aggregation, Subqueries, CTEs,
--              Window Functions, and Business Analytics.
-- =====================================================================

USE ev_charging_management;

-- =====================================================================
-- SECTION 1: BASIC SQL & FILTERING (Queries 1 - 5)
-- =====================================================================

-- Query 1: List all charging stations sorted by State and City
SELECT station_id, station_name, city, state, address
FROM stations
ORDER BY state ASC, city ASC;

-- Query 2: Display distinct charging power capacities available in the network
SELECT DISTINCT power_kw, charger_type
FROM chargers
ORDER BY power_kw ASC;

-- Query 3: Find all high-speed DC fast chargers with power >= 60 kW
SELECT charger_id, station_id, charger_code, power_kw, rate_per_kwh, status
FROM chargers
WHERE charger_type = 'DC' AND power_kw >= 60.00 AND status = 'ACTIVE'
ORDER BY power_kw DESC;

-- Query 4: Retrieve the top 5 most recently registered users
SELECT user_id, full_name, email, phone, created_at
FROM users
ORDER BY created_at DESC
LIMIT 5;

-- Query 5: Find bookings created in the first week of November 2026
SELECT booking_id, user_id, charger_id, start_time, end_time, status
FROM bookings
WHERE created_at BETWEEN '2026-11-01 00:00:00' AND '2026-11-07 23:59:59'
ORDER BY created_at ASC;


-- =====================================================================
-- SECTION 2: RELATIONAL JOINS (Queries 6 - 10)
-- =====================================================================

-- Query 6: Display chargers along with their parent station information (INNER JOIN)
SELECT 
    s.station_name,
    s.city,
    c.charger_code,
    c.charger_type,
    c.power_kw,
    c.rate_per_kwh,
    c.status AS operational_status
FROM chargers c
INNER JOIN stations s ON c.station_id = s.station_id
ORDER BY s.city, c.charger_code;

-- Query 7: User booking details with driver name, station, and charger specifications
SELECT 
    b.booking_id,
    u.full_name AS driver_name,
    u.phone,
    s.station_name,
    c.charger_code,
    b.start_time,
    b.end_time,
    b.status
FROM bookings b
JOIN users u    ON b.user_id = u.user_id
JOIN chargers c ON b.charger_id = c.charger_id
JOIN stations s ON c.station_id = s.station_id
WHERE b.status = 'CONFIRMED'
ORDER BY b.start_time ASC;

-- Query 8: Full operational hierarchy: Station -> Charger -> Booking -> Session -> Payment
SELECT 
    s.station_name,
    c.charger_code,
    u.full_name AS customer,
    cs.actual_start,
    cs.energy_kwh,
    p.amount AS amount_paid,
    p.method AS payment_mode,
    p.status AS payment_state
FROM payments p
JOIN charging_sessions cs ON p.session_id = cs.session_id
JOIN bookings b           ON cs.booking_id = b.booking_id
JOIN users u              ON b.user_id = u.user_id
JOIN chargers c           ON b.charger_id = c.charger_id
JOIN stations s           ON c.station_id = s.station_id
WHERE p.status = 'COMPLETED'
ORDER BY p.amount DESC
LIMIT 10;

-- Query 9: Identify chargers that currently have zero completed sessions (LEFT JOIN)
SELECT 
    c.charger_id,
    c.charger_code,
    s.station_name,
    c.status
FROM chargers c
JOIN stations s ON c.station_id = s.station_id
LEFT JOIN bookings b ON c.charger_id = b.charger_id
LEFT JOIN charging_sessions cs ON b.booking_id = cs.booking_id AND cs.status = 'COMPLETED'
GROUP BY c.charger_id, c.charger_code, s.station_name, c.status
HAVING COUNT(cs.session_id) = 0;

-- Query 10: Find users who have registered but never made a confirmed or completed booking
SELECT 
    u.user_id,
    u.full_name,
    u.email,
    u.phone
FROM users u
LEFT JOIN bookings b ON u.user_id = b.user_id AND b.status IN ('CONFIRMED', 'COMPLETED')
WHERE b.booking_id IS NULL;


-- =====================================================================
-- SECTION 3: AGGREGATION & SUMMARY (Queries 11 - 15)
-- =====================================================================

-- Query 11: Total and average electricity consumption by charger type
SELECT 
    c.charger_type,
    COUNT(cs.session_id) AS completed_sessions,
    ROUND(SUM(cs.energy_kwh), 2) AS total_energy_kwh,
    ROUND(AVG(cs.energy_kwh), 2) AS avg_energy_per_session_kwh,
    ROUND(MIN(cs.energy_kwh), 2) AS min_energy_kwh,
    ROUND(MAX(cs.energy_kwh), 2) AS max_energy_kwh
FROM charging_sessions cs
JOIN bookings b   ON cs.booking_id = b.booking_id
JOIN chargers c   ON b.charger_id = c.charger_id
WHERE cs.status = 'COMPLETED'
GROUP BY c.charger_type;

-- Query 12: Total revenue and transaction count by payment instrument
SELECT 
    COALESCE(method, 'UNSPECIFIED') AS payment_method,
    COUNT(*) AS total_transactions,
    SUM(CASE WHEN status = 'COMPLETED' THEN amount ELSE 0.00 END) AS settled_revenue_inr,
    SUM(CASE WHEN status = 'PENDING' THEN amount ELSE 0.00 END) AS pending_revenue_inr,
    SUM(CASE WHEN status = 'FAILED' THEN amount ELSE 0.00 END) AS failed_amount_inr
FROM payments
GROUP BY method;

-- Query 13: Top 3 charging stations by total electricity delivered
SELECT 
    s.station_id,
    s.station_name,
    s.city,
    COUNT(cs.session_id) AS total_sessions,
    ROUND(SUM(cs.energy_kwh), 2) AS total_kwh
FROM stations s
JOIN chargers c ON s.station_id = c.station_id
JOIN bookings b ON c.charger_id = b.charger_id
JOIN charging_sessions cs ON b.booking_id = cs.booking_id
WHERE cs.status = 'COMPLETED'
GROUP BY s.station_id, s.station_name, s.city
ORDER BY total_kwh DESC
LIMIT 3;

-- Query 14: Station-wise booking volume distribution and status breakdown
SELECT 
    s.station_name,
    COUNT(b.booking_id) AS total_bookings,
    SUM(CASE WHEN b.status = 'COMPLETED' THEN 1 ELSE 0 END) AS completed_count,
    SUM(CASE WHEN b.status = 'CONFIRMED' THEN 1 ELSE 0 END) AS confirmed_count,
    SUM(CASE WHEN b.status = 'CANCELLED' THEN 1 ELSE 0 END) AS cancelled_count
FROM stations s
JOIN chargers c ON s.station_id = c.station_id
JOIN bookings b ON c.charger_id = b.charger_id
GROUP BY s.station_id, s.station_name
ORDER BY total_bookings DESC;

-- Query 15: Identify high-consumption users who consumed > 50 kWh in total
SELECT 
    u.user_id,
    u.full_name,
    COUNT(cs.session_id) AS total_sessions,
    ROUND(SUM(cs.energy_kwh), 2) AS cumulative_kwh,
    ROUND(SUM(p.amount), 2) AS total_spent_inr
FROM users u
JOIN bookings b ON u.user_id = b.user_id
JOIN charging_sessions cs ON b.booking_id = cs.booking_id
JOIN payments p ON cs.session_id = p.session_id
WHERE cs.status = 'COMPLETED' AND p.status = 'COMPLETED'
GROUP BY u.user_id, u.full_name
HAVING cumulative_kwh > 50.00
ORDER BY cumulative_kwh DESC;


-- =====================================================================
-- SECTION 4: SUBQUERIES & CORRELATED QUERIES (Queries 16 - 20)
-- =====================================================================

-- Query 16: Chargers whose hourly rate is strictly above the overall average rate
SELECT 
    charger_id,
    charger_code,
    charger_type,
    rate_per_kwh
FROM chargers
WHERE rate_per_kwh > (SELECT AVG(rate_per_kwh) FROM chargers)
ORDER BY rate_per_kwh DESC;

-- Query 17: Correlated Subquery: Find sessions that consumed more than station average
SELECT 
    cs.session_id,
    s.station_name,
    c.charger_code,
    cs.energy_kwh
FROM charging_sessions cs
JOIN bookings b   ON cs.booking_id = b.booking_id
JOIN chargers c   ON b.charger_id = c.charger_id
JOIN stations s   ON c.station_id = s.station_id
WHERE cs.status = 'COMPLETED'
  AND cs.energy_kwh > (
      SELECT AVG(cs2.energy_kwh)
      FROM charging_sessions cs2
      JOIN bookings b2   ON cs2.booking_id = b2.booking_id
      JOIN chargers c2   ON b2.charger_id = c2.charger_id
      WHERE c2.station_id = s.station_id AND cs2.status = 'COMPLETED'
  )
ORDER BY s.station_name, cs.energy_kwh DESC;

-- Query 18: Find users who made bookings in both Hyderabad and Bengaluru (INTERSECT via Subquery)
SELECT DISTINCT u.user_id, u.full_name
FROM users u
JOIN bookings b ON u.user_id = b.user_id
JOIN chargers c ON b.charger_id = c.charger_id
JOIN stations s ON c.station_id = s.station_id
WHERE s.city = 'Hyderabad'
  AND u.user_id IN (
      SELECT u2.user_id
      FROM users u2
      JOIN bookings b2 ON u2.user_id = b2.user_id
      JOIN chargers c2 ON b2.charger_id = c2.charger_id
      JOIN stations s2 ON c2.station_id = s2.station_id
      WHERE s2.city = 'Bengaluru'
  );

-- Query 19: Find chargers with upcoming confirmed bookings using EXISTS
SELECT c.charger_id, c.charger_code, s.station_name
FROM chargers c
JOIN stations s ON c.station_id = s.station_id
WHERE EXISTS (
    SELECT 1 
    FROM bookings b 
    WHERE b.charger_id = c.charger_id 
      AND b.status = 'CONFIRMED' 
      AND b.start_time > '2026-11-15 00:00:00'
);

-- Query 20: Station utilization percentage (Active Chargers / Total Chargers)
SELECT 
    s.station_name,
    s.city,
    (SELECT COUNT(*) FROM chargers c WHERE c.station_id = s.station_id) AS total_chargers,
    (SELECT COUNT(*) FROM chargers c WHERE c.station_id = s.station_id AND c.status = 'ACTIVE') AS active_chargers,
    ROUND(
        (SELECT COUNT(*) FROM chargers c WHERE c.station_id = s.station_id AND c.status = 'ACTIVE') * 100.0 /
        NULLIF((SELECT COUNT(*) FROM chargers c WHERE c.station_id = s.station_id), 0), 1
    ) AS operational_availability_pct
FROM stations s;


-- =====================================================================
-- SECTION 5: ADVANCED SQL (CTEs & WINDOW FUNCTIONS) (Queries 21 - 25)
-- =====================================================================

-- Query 21: Common Table Expression (CTE) - Monthly Revenue and Energy Delivery
WITH MonthlyStats AS (
    SELECT 
        DATE_FORMAT(cs.actual_start, '%Y-%m') AS billing_month,
        COUNT(cs.session_id) AS total_sessions,
        SUM(cs.energy_kwh) AS total_kwh,
        SUM(p.amount) AS total_revenue
    FROM charging_sessions cs
    JOIN payments p ON cs.session_id = p.session_id
    WHERE cs.status = 'COMPLETED' AND p.status = 'COMPLETED'
    GROUP BY DATE_FORMAT(cs.actual_start, '%Y-%m')
)
SELECT 
    billing_month,
    total_sessions,
    ROUND(total_kwh, 2) AS total_energy_kwh,
    ROUND(total_revenue, 2) AS total_revenue_inr,
    ROUND(total_revenue / total_kwh, 2) AS effective_avg_rate_inr
FROM MonthlyStats;

-- Query 22: Window Function - DENSE_RANK() chargers by revenue within their city
WITH ChargerRevenue AS (
    SELECT 
        s.city,
        s.station_name,
        c.charger_code,
        COALESCE(SUM(p.amount), 0.00) AS total_revenue
    FROM chargers c
    JOIN stations s ON c.station_id = s.station_id
    LEFT JOIN bookings b ON c.charger_id = b.charger_id
    LEFT JOIN charging_sessions cs ON b.booking_id = cs.booking_id
    LEFT JOIN payments p ON cs.session_id = p.session_id AND p.status = 'COMPLETED'
    GROUP BY s.city, s.station_name, c.charger_code
)
SELECT 
    city,
    station_name,
    charger_code,
    total_revenue,
    DENSE_RANK() OVER (PARTITION BY city ORDER BY total_revenue DESC) AS city_revenue_rank
FROM ChargerRevenue;

-- Query 23: Window Function - Running Total (Cumulative Energy Delivered over time)
SELECT 
    cs.session_id,
    DATE(cs.actual_start) AS session_date,
    cs.energy_kwh,
    ROUND(SUM(cs.energy_kwh) OVER (ORDER BY cs.actual_start ASC), 2) AS running_total_kwh
FROM charging_sessions cs
WHERE cs.status = 'COMPLETED'
ORDER BY cs.actual_start ASC
LIMIT 12;

-- Query 24: Window Function - LAG() to calculate time elapsed since previous session on the same charger
SELECT 
    cs.session_id,
    b.charger_id,
    cs.actual_start,
    LAG(cs.actual_end, 1) OVER (PARTITION BY b.charger_id ORDER BY cs.actual_start) AS prev_session_end,
    TIMESTAMPDIFF(MINUTE, 
        LAG(cs.actual_end, 1) OVER (PARTITION BY b.charger_id ORDER BY cs.actual_start), 
        cs.actual_start
    ) AS idle_minutes_between_sessions
FROM charging_sessions cs
JOIN bookings b ON cs.booking_id = b.booking_id
WHERE cs.status = 'COMPLETED';

-- Query 25: Performance Execution Plan (EXPLAIN) on composite time conflict search
EXPLAIN
SELECT booking_id, charger_id, start_time, end_time
FROM bookings
WHERE charger_id = 2 
  AND status IN ('CONFIRMED', 'PENDING')
  AND start_time < '2026-11-01 10:00:00'
  AND '2026-11-01 09:00:00' < end_time;


-- =====================================================================
-- SECTION 6: BUSINESS DEMO QUERIES (Queries 26 - 32)
-- =====================================================================

-- Query 26: Search for operational chargers currently available in Hyderabad
SELECT 
    charger_id,
    charger_code,
    charger_type,
    power_kw,
    rate_per_kwh,
    station_name,
    address
FROM vw_active_chargers
WHERE city = 'Hyderabad'
ORDER BY power_kw DESC;

-- Query 27: Check if a specific charger (Charger 2) is free between 15:00 and 16:00 on 2026-11-16
SELECT 
    c.charger_id,
    c.charger_code,
    CASE 
        WHEN COUNT(b.booking_id) = 0 THEN 'SLOT_AVAILABLE'
        ELSE 'SLOT_OCCUPIED'
    END AS availability_status
FROM chargers c
LEFT JOIN bookings b ON c.charger_id = b.charger_id
  AND b.status IN ('CONFIRMED', 'PENDING')
  AND b.start_time < '2026-11-16 16:00:00'
  AND '2026-11-16 15:00:00' < b.end_time
WHERE c.charger_id = 2
GROUP BY c.charger_id, c.charger_code;

-- Query 28: Identify outstanding unpaid or failed payment invoices needing collection
SELECT 
    p.payment_id,
    u.full_name AS customer_name,
    u.phone,
    s.station_name,
    p.amount AS amount_due_inr,
    p.status AS payment_status
FROM payments p
JOIN charging_sessions cs ON p.session_id = cs.session_id
JOIN bookings b           ON cs.booking_id = b.booking_id
JOIN users u              ON b.user_id = u.user_id
JOIN chargers c           ON b.charger_id = c.charger_id
JOIN stations s           ON c.station_id = s.station_id
WHERE p.status IN ('PENDING', 'FAILED')
ORDER BY p.amount DESC;

-- Query 29: Overall Network KPI Dashboard
SELECT 
    (SELECT COUNT(*) FROM stations) AS total_stations,
    (SELECT COUNT(*) FROM chargers WHERE status = 'ACTIVE') AS active_chargers,
    (SELECT COUNT(*) FROM bookings) AS total_bookings,
    (SELECT COUNT(*) FROM charging_sessions WHERE status = 'COMPLETED') AS completed_sessions,
    (SELECT ROUND(SUM(energy_kwh), 2) FROM charging_sessions) AS total_kwh_delivered,
    (SELECT ROUND(SUM(amount), 2) FROM payments WHERE status = 'COMPLETED') AS total_revenue_collected_inr;

-- Query 30: Stored Procedure Execution: Calculate bill breakdown for Session #1
CALL sp_calculate_bill(1, @user, @station, @charger, @kwh, @rate, @total);
SELECT 
    @user AS customer,
    @station AS station,
    @charger AS charger,
    @kwh AS energy_consumed_kwh,
    @rate AS rate_snapshot_inr,
    @total AS total_bill_inr;

-- Query 31: Stored Procedure Execution: Generate Station Revenue Report
CALL sp_station_revenue_report(NULL);

-- Query 32: View Query: Comprehensive financial audit log
SELECT * FROM vw_payment_audit_log LIMIT 10;
