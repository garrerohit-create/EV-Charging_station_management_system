-- =====================================================================
-- Project: EV Charging Station Management System
-- Script: 03_constraints_indexes.sql
-- Description: Creates performance-optimizing B-Tree indexes on search keys,
--              foreign keys, composite filters, and temporal booking ranges.
-- =====================================================================

USE ev_charging_management;

-- 1. Stations: Geographic lookup index
CREATE INDEX idx_stations_city_state 
ON stations (city, state);

-- 2. Chargers: Filter active units by charging speed/type
CREATE INDEX idx_chargers_status_type 
ON chargers (status, charger_type);

-- 3. Bookings: Temporal slot conflict & availability check
-- Essential for sp_book_charger_slot() range overlap detection
CREATE INDEX idx_bookings_conflict_search 
ON bookings (charger_id, status, start_time, end_time);

-- 4. Bookings: User reservation history lookup
CREATE INDEX idx_bookings_user_status 
ON bookings (user_id, status);

-- 5. Sessions: Active charging monitoring and date metrics
CREATE INDEX idx_sessions_status_start 
ON charging_sessions (status, actual_start);

-- 6. Payments: Financial settlement and method auditing
CREATE INDEX idx_payments_status_method 
ON payments (status, method);
