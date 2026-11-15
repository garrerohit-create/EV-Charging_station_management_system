-- =====================================================================
-- Project: EV Charging Station Management System
-- Script: 06_views.sql
-- Description: Business intelligence and reporting views for operational
--              monitoring, user history, audit trails, and revenue metrics.
-- =====================================================================

USE ev_charging_management;

-- 1. View: Available & Operational Chargers
CREATE OR REPLACE VIEW vw_active_chargers AS
SELECT 
    c.charger_id,
    c.charger_code,
    c.charger_type,
    c.power_kw,
    c.rate_per_kwh,
    c.status AS charger_status,
    s.station_id,
    s.station_name,
    s.address,
    s.city,
    s.state
FROM chargers c
JOIN stations s ON c.station_id = s.station_id
WHERE c.status = 'ACTIVE';

-- 2. View: Comprehensive User Booking History
CREATE OR REPLACE VIEW vw_user_booking_history AS
SELECT 
    b.booking_id,
    u.user_id,
    u.full_name AS user_name,
    u.email,
    u.phone,
    s.station_name,
    s.city,
    c.charger_code,
    c.charger_type,
    c.power_kw,
    b.start_time,
    b.end_time,
    TIMESTAMPDIFF(MINUTE, b.start_time, b.end_time) AS booked_duration_minutes,
    b.status AS booking_status,
    b.created_at AS booked_at
FROM bookings b
JOIN users u    ON b.user_id = u.user_id
JOIN chargers c ON b.charger_id = c.charger_id
JOIN stations s ON c.station_id = s.station_id;

-- 3. View: Charging Session Details & Energy Telemetry
CREATE OR REPLACE VIEW vw_charging_session_details AS
SELECT 
    cs.session_id,
    cs.booking_id,
    u.user_id,
    u.full_name AS user_name,
    s.station_name,
    s.city,
    c.charger_code,
    c.charger_type,
    cs.actual_start,
    cs.actual_end,
    TIMESTAMPDIFF(MINUTE, cs.actual_start, cs.actual_end) AS actual_duration_minutes,
    cs.energy_kwh,
    cs.rate_per_kwh AS applied_rate_snapshot,
    ROUND(IFNULL(cs.energy_kwh, 0.000) * cs.rate_per_kwh, 2) AS calculated_bill_inr,
    cs.status AS session_status
FROM charging_sessions cs
JOIN bookings b   ON cs.booking_id = b.booking_id
JOIN users u      ON b.user_id = u.user_id
JOIN chargers c   ON b.charger_id = c.charger_id
JOIN stations s   ON c.station_id = s.station_id;

-- 4. View: Financial Payment Audit Log
CREATE OR REPLACE VIEW vw_payment_audit_log AS
SELECT 
    p.payment_id,
    p.session_id,
    u.user_id,
    u.full_name AS customer_name,
    s.station_name,
    c.charger_code,
    cs.energy_kwh,
    cs.rate_per_kwh,
    p.amount AS billed_amount_inr,
    p.method AS payment_method,
    p.status AS payment_status,
    p.paid_at AS settlement_timestamp
FROM payments p
JOIN charging_sessions cs ON p.session_id = cs.session_id
JOIN bookings b           ON cs.booking_id = b.booking_id
JOIN users u              ON b.user_id = u.user_id
JOIN chargers c           ON b.charger_id = c.charger_id
JOIN stations s           ON c.station_id = s.station_id;

-- 5. View: Station Performance & Revenue Summary
CREATE OR REPLACE VIEW vw_station_revenue_summary AS
SELECT 
    s.station_id,
    s.station_name,
    s.city,
    s.state,
    COUNT(DISTINCT c.charger_id) AS total_chargers,
    SUM(CASE WHEN c.status = 'ACTIVE' THEN 1 ELSE 0 END) AS operational_chargers,
    COUNT(DISTINCT b.booking_id) AS total_bookings,
    COUNT(DISTINCT cs.session_id) AS total_sessions,
    COALESCE(SUM(cs.energy_kwh), 0.000) AS total_energy_kwh_delivered,
    COALESCE(SUM(CASE WHEN p.status = 'COMPLETED' THEN p.amount ELSE 0.00 END), 0.00) AS total_revenue_inr
FROM stations s
LEFT JOIN chargers c          ON s.station_id = c.station_id
LEFT JOIN bookings b          ON c.charger_id = b.charger_id
LEFT JOIN charging_sessions cs ON b.booking_id = cs.booking_id
LEFT JOIN payments p          ON cs.session_id = p.session_id
GROUP BY s.station_id, s.station_name, s.city, s.state;
