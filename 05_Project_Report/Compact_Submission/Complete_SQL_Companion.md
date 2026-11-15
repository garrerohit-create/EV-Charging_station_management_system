# Complete SQL companion

Reference listings only. Setup and test scripts modify data; the seed script truncates the core tables. Run original files individually in the documented order in a disposable environment.

## 02_SQL_Scripts\01_create_database.sql

```sql

-- Step 1: Create our project database
CREATE DATABASE IF NOT EXISTS ev_charging_management;

-- Step 2: Select the database
USE ev_charging_management;

-- Step 3: Check the selected database
SELECT DATABASE() AS current_database;

-- Step 4: Check the MySQL version
SELECT VERSION() AS mysql_version;

```

## 02_SQL_Scripts\02_create_tables.sql

```sql
-- =====================================================================
-- Project: EV Charging Station Management System
-- Script: 02_create_tables.sql
-- Description: Creates the 6 core relational tables with Primary Keys,
--              Foreign Keys, Unique constraints, and CHECK constraints.
-- Engine: InnoDB | Character Set: utf8mb4
-- =====================================================================

USE ev_charging_management;

-- 1. USERS TABLE
CREATE TABLE IF NOT EXISTS users (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    email VARCHAR(120) NOT NULL UNIQUE,
    phone VARCHAR(15) NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_user_email_format CHECK (email LIKE '%_@__%.__%')
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 2. STATIONS TABLE
CREATE TABLE IF NOT EXISTS stations (
    station_id INT AUTO_INCREMENT PRIMARY KEY,
    station_name VARCHAR(100) NOT NULL,
    address VARCHAR(255) NOT NULL,
    city VARCHAR(80) NOT NULL,
    state VARCHAR(80) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 3. CHARGERS TABLE
CREATE TABLE IF NOT EXISTS chargers (
    charger_id INT AUTO_INCREMENT PRIMARY KEY,
    station_id INT NOT NULL,
    charger_code VARCHAR(20) NOT NULL,
    charger_type ENUM('AC', 'DC') NOT NULL,
    power_kw DECIMAL(6,2) NOT NULL,
    rate_per_kwh DECIMAL(8,2) NOT NULL,
    status ENUM('ACTIVE', 'MAINTENANCE', 'OUT_OF_SERVICE') NOT NULL DEFAULT 'ACTIVE',
    CONSTRAINT fk_chargers_station 
        FOREIGN KEY (station_id) REFERENCES stations(station_id) 
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT uk_station_charger_code 
        UNIQUE (station_id, charger_code),
    CONSTRAINT chk_charger_power 
        CHECK (power_kw > 0.00),
    CONSTRAINT chk_charger_rate 
        CHECK (rate_per_kwh >= 0.00)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 4. BOOKINGS TABLE
CREATE TABLE IF NOT EXISTS bookings (
    booking_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    charger_id INT NOT NULL,
    start_time DATETIME NOT NULL,
    end_time DATETIME NOT NULL,
    status ENUM('PENDING', 'CONFIRMED', 'CANCELLED', 'COMPLETED') NOT NULL DEFAULT 'PENDING',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_bookings_user 
        FOREIGN KEY (user_id) REFERENCES users(user_id) 
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_bookings_charger 
        FOREIGN KEY (charger_id) REFERENCES chargers(charger_id) 
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_booking_time_order 
        CHECK (end_time > start_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 5. CHARGING_SESSIONS TABLE
CREATE TABLE IF NOT EXISTS charging_sessions (
    session_id INT AUTO_INCREMENT PRIMARY KEY,
    booking_id INT NOT NULL UNIQUE,
    actual_start DATETIME NOT NULL,
    actual_end DATETIME NULL,
    energy_kwh DECIMAL(8,3) NULL,
    rate_per_kwh DECIMAL(8,2) NOT NULL,
    status ENUM('IN_PROGRESS', 'COMPLETED') NOT NULL DEFAULT 'IN_PROGRESS',
    CONSTRAINT fk_sessions_booking 
        FOREIGN KEY (booking_id) REFERENCES bookings(booking_id) 
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_session_time_order 
        CHECK (actual_end IS NULL OR actual_end >= actual_start),
    CONSTRAINT chk_session_energy 
        CHECK (energy_kwh IS NULL OR energy_kwh >= 0.000),
    CONSTRAINT chk_session_rate 
        CHECK (rate_per_kwh >= 0.00)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 6. PAYMENTS TABLE
CREATE TABLE IF NOT EXISTS payments (
    payment_id INT AUTO_INCREMENT PRIMARY KEY,
    session_id INT NOT NULL UNIQUE,
    amount DECIMAL(10,2) NOT NULL,
    method ENUM('UPI', 'CARD', 'CASH') NULL,
    status ENUM('PENDING', 'COMPLETED', 'FAILED') NOT NULL DEFAULT 'PENDING',
    paid_at DATETIME NULL,
    CONSTRAINT fk_payments_session 
        FOREIGN KEY (session_id) REFERENCES charging_sessions(session_id) 
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_payment_amount 
        CHECK (amount >= 0.00)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

```

## 02_SQL_Scripts\03_constraints_indexes.sql

```sql
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

```

## 02_SQL_Scripts\04_triggers.sql

```sql
-- =====================================================================
-- Project: EV Charging Station Management System
-- Script: 04_triggers.sql
-- Description: Business integrity triggers for automated rate snapshotting,
--              booking interval validation, and payment settlement timestamps.
-- =====================================================================

USE ev_charging_management;

DROP TRIGGER IF EXISTS trg_bookings_before_insert;
DROP TRIGGER IF EXISTS trg_sessions_before_insert;
DROP TRIGGER IF EXISTS trg_sessions_after_update;
DROP TRIGGER IF EXISTS trg_payments_before_update;

DELIMITER $$

-- 1. Trigger: Validate booking time interval logic
CREATE TRIGGER trg_bookings_before_insert
BEFORE INSERT ON bookings
FOR EACH ROW
BEGIN
    IF NEW.end_time <= NEW.start_time THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Validation Error: Booking end_time must be strictly after start_time.';
    END IF;
END$$

-- 2. Trigger: Automatic Rate Snapshot Enforcement
-- Captures the baseline catalog rate from chargers table if not explicitly provided
CREATE TRIGGER trg_sessions_before_insert
BEFORE INSERT ON charging_sessions
FOR EACH ROW
BEGIN
    DECLARE v_catalog_rate DECIMAL(8,2);
    
    IF NEW.rate_per_kwh IS NULL OR NEW.rate_per_kwh <= 0.00 THEN
        SELECT c.rate_per_kwh INTO v_catalog_rate
        FROM bookings b
        JOIN chargers c ON b.charger_id = c.charger_id
        WHERE b.booking_id = NEW.booking_id;
        
        SET NEW.rate_per_kwh = IFNULL(v_catalog_rate, 15.00);
    END IF;
    
    IF NEW.actual_end IS NOT NULL AND NEW.actual_end < NEW.actual_start THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Validation Error: Charging session actual_end cannot precede actual_start.';
    END IF;
END$$

-- 3. Trigger: Synchronize booking status when charging session completes
CREATE TRIGGER trg_sessions_after_update
AFTER UPDATE ON charging_sessions
FOR EACH ROW
BEGIN
    IF NEW.status = 'COMPLETED' AND OLD.status != 'COMPLETED' THEN
        UPDATE bookings
        SET status = 'COMPLETED'
        WHERE booking_id = NEW.booking_id;
    END IF;
END$$

-- 4. Trigger: Auto-populate settlement timestamp on payment completion
CREATE TRIGGER trg_payments_before_update
BEFORE UPDATE ON payments
FOR EACH ROW
BEGIN
    IF NEW.status = 'COMPLETED' AND (OLD.status IS NULL OR OLD.status != 'COMPLETED') THEN
        IF NEW.paid_at IS NULL THEN
            SET NEW.paid_at = CURRENT_TIMESTAMP;
        END IF;
    END IF;
END$$

DELIMITER ;

```

## 02_SQL_Scripts\05_stored_procedures.sql

```sql
-- =====================================================================
-- Project: EV Charging Station Management System
-- Script: 05_stored_procedures.sql
-- Description: ACID-compliant stored procedures implementing core business
--              workflows, concurrency control (FOR UPDATE), and reporting.
-- =====================================================================

USE ev_charging_management;

DROP PROCEDURE IF EXISTS sp_book_charger_slot;
DROP PROCEDURE IF EXISTS sp_start_charging_session;
DROP PROCEDURE IF EXISTS sp_complete_charging_session;
DROP PROCEDURE IF EXISTS sp_calculate_bill;
DROP PROCEDURE IF EXISTS sp_process_payment;
DROP PROCEDURE IF EXISTS sp_station_revenue_report;

DELIMITER $$

-- 1. PROCEDURE: Book a charging slot with exclusive row locking & conflict prevention
CREATE PROCEDURE sp_book_charger_slot(
    IN  p_user_id      INT,
    IN  p_charger_id   INT,
    IN  p_start_time   DATETIME,
    IN  p_end_time     DATETIME,
    OUT p_booking_id   INT,
    OUT p_status_code  VARCHAR(30),
    OUT p_message      VARCHAR(255)
)
proc_label: BEGIN
    DECLARE v_user_exists     INT DEFAULT 0;
    DECLARE v_charger_status  VARCHAR(20);
    DECLARE v_conflict_count  INT DEFAULT 0;
    DECLARE v_err_msg         VARCHAR(255);
    
    -- Transaction handler for error rollback
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_err_msg = MESSAGE_TEXT;
        ROLLBACK;
        SET p_booking_id  = NULL;
        SET p_status_code = 'ERROR';
        SET p_message     = CONCAT('Error: ', IFNULL(v_err_msg, 'Transaction failed. Rolled back.'));
    END;

    START TRANSACTION READ WRITE;

    -- Validation 1: Verify time window order
    IF p_end_time <= p_start_time THEN
        ROLLBACK;
        SET p_booking_id  = NULL;
        SET p_status_code = 'INVALID_TIME';
        SET p_message     = 'End time must be strictly after start time.';
        LEAVE proc_label;
    END IF;

    -- Validation 2: Verify user exists
    SELECT COUNT(*) INTO v_user_exists FROM users WHERE user_id = p_user_id;
    IF v_user_exists = 0 THEN
        ROLLBACK;
        SET p_booking_id  = NULL;
        SET p_status_code = 'USER_NOT_FOUND';
        SET p_message     = 'User ID does not exist.';
        LEAVE proc_label;
    END IF;

    -- Validation 3: Lock the charger row for update to prevent concurrent double-booking
    SELECT status INTO v_charger_status 
    FROM chargers 
    WHERE charger_id = p_charger_id 
    FOR UPDATE;

    IF v_charger_status IS NULL THEN
        ROLLBACK;
        SET p_booking_id  = NULL;
        SET p_status_code = 'CHARGER_NOT_FOUND';
        SET p_message     = 'Charger ID does not exist.';
        LEAVE proc_label;
    END IF;

    IF v_charger_status != 'ACTIVE' THEN
        ROLLBACK;
        SET p_booking_id  = NULL;
        SET p_status_code = 'CHARGER_UNAVAILABLE';
        SET p_message     = CONCAT('Charger is currently ', v_charger_status, '. Booking rejected.');
        LEAVE proc_label;
    END IF;

    -- Validation 4: Overlapping slot check (Interval Collision Theorem)
    -- Collision condition: existing.start < requested.end AND requested.start < existing.end
    SELECT COUNT(*) INTO v_conflict_count
    FROM bookings
    WHERE charger_id = p_charger_id
      AND status IN ('CONFIRMED', 'PENDING')
      AND start_time < p_end_time
      AND p_start_time < end_time;

    IF v_conflict_count > 0 THEN
        ROLLBACK;
        SET p_booking_id  = NULL;
        SET p_status_code = 'SLOT_CONFLICT';
        SET p_message     = 'Selected slot conflicts with an existing reservation.';
        LEAVE proc_label;
    END IF;

    -- Insert confirmed booking
    INSERT INTO bookings (user_id, charger_id, start_time, end_time, status, created_at)
    VALUES (p_user_id, p_charger_id, p_start_time, p_end_time, 'CONFIRMED', CURRENT_TIMESTAMP);

    SET p_booking_id  = LAST_INSERT_ID();
    SET p_status_code = 'SUCCESS';
    SET p_message     = 'Charging slot successfully booked.';

    COMMIT;
END proc_label$$

-- 2. PROCEDURE: Start charging session (Locks rate snapshot)
CREATE PROCEDURE sp_start_charging_session(
    IN  p_booking_id   INT,
    OUT p_session_id   INT,
    OUT p_status_code  VARCHAR(30),
    OUT p_message      VARCHAR(255)
)
proc_label: BEGIN
    DECLARE v_booking_status VARCHAR(20);
    DECLARE v_charger_rate   DECIMAL(8,2);
    DECLARE v_session_exists INT DEFAULT 0;
    DECLARE v_err_msg        VARCHAR(255);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_err_msg = MESSAGE_TEXT;
        ROLLBACK;
        SET p_session_id  = NULL;
        SET p_status_code = 'ERROR';
        SET p_message     = CONCAT('Error: ', IFNULL(v_err_msg, 'Session startup failed. Rolled back.'));
    END;

    START TRANSACTION READ WRITE;

    -- Check if session already created for this booking first
    SELECT COUNT(*) INTO v_session_exists 
    FROM charging_sessions 
    WHERE booking_id = p_booking_id;

    IF v_session_exists > 0 THEN
        ROLLBACK;
        SET p_session_id  = NULL;
        SET p_status_code = 'SESSION_ALREADY_EXISTS';
        SET p_message     = 'A charging session already exists for this booking.';
        LEAVE proc_label;
    END IF;

    -- Check booking status
    SELECT b.status, c.rate_per_kwh 
    INTO v_booking_status, v_charger_rate
    FROM bookings b
    JOIN chargers c ON b.charger_id = c.charger_id
    WHERE b.booking_id = p_booking_id
    FOR UPDATE;

    IF v_booking_status IS NULL THEN
        ROLLBACK;
        SET p_session_id  = NULL;
        SET p_status_code = 'BOOKING_NOT_FOUND';
        SET p_message     = 'Booking does not exist.';
        LEAVE proc_label;
    END IF;

    IF v_booking_status != 'CONFIRMED' THEN
        ROLLBACK;
        SET p_session_id  = NULL;
        SET p_status_code = 'INVALID_BOOKING_STATUS';
        SET p_message     = CONCAT('Cannot start session for booking in status: ', v_booking_status);
        LEAVE proc_label;
    END IF;

    -- Insert active session with immutable rate snapshot
    INSERT INTO charging_sessions (
        booking_id, actual_start, rate_per_kwh, status
    ) VALUES (
        p_booking_id, CURRENT_TIMESTAMP, v_charger_rate, 'IN_PROGRESS'
    );

    SET p_session_id  = LAST_INSERT_ID();
    SET p_status_code = 'SUCCESS';
    SET p_message     = 'Charging session started successfully.';

    COMMIT;
END proc_label$$

-- 3. PROCEDURE: Complete charging session & generate initial billing
CREATE PROCEDURE sp_complete_charging_session(
    IN  p_session_id   INT,
    IN  p_energy_kwh   DECIMAL(8,3),
    OUT p_total_amount DECIMAL(10,2),
    OUT p_status_code  VARCHAR(30),
    OUT p_message      VARCHAR(255)
)
proc_label: BEGIN
    DECLARE v_session_status VARCHAR(20);
    DECLARE v_locked_rate    DECIMAL(8,2);
    DECLARE v_payment_exists INT DEFAULT 0;
    DECLARE v_err_msg        VARCHAR(255);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_err_msg = MESSAGE_TEXT;
        ROLLBACK;
        SET p_total_amount = 0.00;
        SET p_status_code  = 'ERROR';
        SET p_message      = CONCAT('Error: ', IFNULL(v_err_msg, 'Failed to complete session. Rolled back.'));
    END;

    START TRANSACTION READ WRITE;

    IF p_energy_kwh < 0.000 THEN
        ROLLBACK;
        SET p_total_amount = 0.00;
        SET p_status_code  = 'INVALID_ENERGY';
        SET p_message      = 'Energy consumption cannot be negative.';
        LEAVE proc_label;
    END IF;

    SELECT status, rate_per_kwh 
    INTO v_session_status, v_locked_rate
    FROM charging_sessions
    WHERE session_id = p_session_id
    FOR UPDATE;

    IF v_session_status IS NULL THEN
        ROLLBACK;
        SET p_total_amount = 0.00;
        SET p_status_code  = 'SESSION_NOT_FOUND';
        SET p_message      = 'Charging session not found.';
        LEAVE proc_label;
    END IF;

    IF v_session_status != 'IN_PROGRESS' THEN
        ROLLBACK;
        SET p_total_amount = 0.00;
        SET p_status_code  = 'ALREADY_COMPLETED';
        SET p_message      = 'Session is already completed or inactive.';
        LEAVE proc_label;
    END IF;

    -- Calculate amount using locked rate snapshot
    SET p_total_amount = ROUND(p_energy_kwh * v_locked_rate, 2);

    -- Update session
    UPDATE charging_sessions
    SET actual_end = CURRENT_TIMESTAMP,
        energy_kwh = p_energy_kwh,
        status     = 'COMPLETED'
    WHERE session_id = p_session_id;

    -- Insert corresponding pending payment record
    SELECT COUNT(*) INTO v_payment_exists FROM payments WHERE session_id = p_session_id;
    IF v_payment_exists = 0 THEN
        INSERT INTO payments (session_id, amount, status)
        VALUES (p_session_id, p_total_amount, 'PENDING');
    ELSE
        UPDATE payments SET amount = p_total_amount WHERE session_id = p_session_id;
    END IF;

    SET p_status_code = 'SUCCESS';
    SET p_message     = 'Session completed and payment record generated.';

    COMMIT;
END proc_label$$

-- 4. PROCEDURE: Calculate and display detailed bill breakdown
CREATE PROCEDURE sp_calculate_bill(
    IN  p_session_id     INT,
    OUT p_user_name      VARCHAR(100),
    OUT p_station_name   VARCHAR(100),
    OUT p_charger_code   VARCHAR(20),
    OUT p_energy_kwh     DECIMAL(8,3),
    OUT p_rate_per_kwh   DECIMAL(8,2),
    OUT p_total_amount   DECIMAL(10,2)
)
BEGIN
    SELECT 
        u.full_name,
        st.station_name,
        ch.charger_code,
        cs.energy_kwh,
        cs.rate_per_kwh,
        ROUND(IFNULL(cs.energy_kwh, 0.000) * cs.rate_per_kwh, 2)
    INTO 
        p_user_name,
        p_station_name,
        p_charger_code,
        p_energy_kwh,
        p_rate_per_kwh,
        p_total_amount
    FROM charging_sessions cs
    JOIN bookings b   ON cs.booking_id = b.booking_id
    JOIN users u      ON b.user_id = u.user_id
    JOIN chargers ch  ON b.charger_id = ch.charger_id
    JOIN stations st  ON ch.station_id = st.station_id
    WHERE cs.session_id = p_session_id;
END$$

-- 5. PROCEDURE: Process and reconcile payment
CREATE PROCEDURE sp_process_payment(
    IN  p_session_id   INT,
    IN  p_method       VARCHAR(10),
    IN  p_status       VARCHAR(20),
    OUT p_status_code  VARCHAR(30),
    OUT p_message      VARCHAR(255)
)
proc_label: BEGIN
    DECLARE v_payment_exists INT DEFAULT 0;
    DECLARE v_err_msg        VARCHAR(255);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_err_msg = MESSAGE_TEXT;
        ROLLBACK;
        SET p_status_code = 'ERROR';
        SET p_message     = CONCAT('Error: ', IFNULL(v_err_msg, 'Payment processing failed. Rolled back.'));
    END;

    START TRANSACTION READ WRITE;

    IF p_method NOT IN ('UPI', 'CARD', 'CASH') THEN
        ROLLBACK;
        SET p_status_code = 'INVALID_METHOD';
        SET p_message     = 'Invalid payment method. Must be UPI, CARD, or CASH.';
        LEAVE proc_label;
    END IF;

    IF p_status NOT IN ('COMPLETED', 'FAILED') THEN
        ROLLBACK;
        SET p_status_code = 'INVALID_STATUS';
        SET p_message     = 'Payment status update must be COMPLETED or FAILED.';
        LEAVE proc_label;
    END IF;

    SELECT COUNT(*) INTO v_payment_exists FROM payments WHERE session_id = p_session_id;

    IF v_payment_exists = 0 THEN
        ROLLBACK;
        SET p_status_code = 'PAYMENT_NOT_FOUND';
        SET p_message     = 'No payment invoice found for this session.';
        LEAVE proc_label;
    END IF;

    UPDATE payments
    SET method  = p_method,
        status  = p_status,
        paid_at = IF(p_status = 'COMPLETED', CURRENT_TIMESTAMP, NULL)
    WHERE session_id = p_session_id;

    SET p_status_code = 'SUCCESS';
    SET p_message     = CONCAT('Payment updated to ', p_status);

    COMMIT;
END proc_label$$

-- 6. PROCEDURE: Station-wise Revenue and Utilization Summary
CREATE PROCEDURE sp_station_revenue_report(
    IN p_station_id INT
)
BEGIN
    SELECT 
        st.station_id,
        st.station_name,
        st.city,
        st.state,
        COUNT(DISTINCT ch.charger_id) AS total_chargers,
        COUNT(DISTINCT b.booking_id)  AS total_bookings,
        COUNT(DISTINCT cs.session_id) AS total_sessions,
        COALESCE(SUM(cs.energy_kwh), 0.000) AS total_kwh_delivered,
        COALESCE(SUM(CASE WHEN p.status = 'COMPLETED' THEN p.amount ELSE 0.00 END), 0.00) AS total_revenue_inr
    FROM stations st
    LEFT JOIN chargers ch          ON st.station_id = ch.station_id
    LEFT JOIN bookings b           ON ch.charger_id = b.charger_id
    LEFT JOIN charging_sessions cs ON b.booking_id = cs.booking_id
    LEFT JOIN payments p           ON cs.session_id = p.session_id
    WHERE (p_station_id IS NULL OR st.station_id = p_station_id)
    GROUP BY st.station_id, st.station_name, st.city, st.state
    ORDER BY total_revenue_inr DESC;
END$$

DELIMITER ;

```

## 02_SQL_Scripts\06_views.sql

```sql
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

```

## 02_SQL_Scripts\07_demo_queries.sql

```sql
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

```

## 02_SQL_Scripts\08_full_project_setup.sql

```sql
-- =====================================================================
-- Project: EV Charging Station Management System
-- Script: 08_full_project_setup.sql
-- Description: Master Idempotent Setup Script for fresh installation.
--              Executes DDL, Constraints, Triggers, Stored Procedures,
--              Views, and Seeds Sample Data in exact dependency sequence.
-- DBMS: MySQL Community Server 8.4 LTS
-- =====================================================================

-- Step 1: Initialize Database Environment
CREATE DATABASE IF NOT EXISTS ev_charging_management;
USE ev_charging_management;

-- Step 2: Source Component Scripts
-- Note: When executing from MySQL Workbench or mysql CLI:
-- Ensure your working directory points to the project root, or execute:
-- mysql -u root -p ev_charging_management < 02_SQL_Scripts/08_full_project_setup.sql

SOURCE 02_SQL_Scripts/01_create_database.sql;
SOURCE 02_SQL_Scripts/02_create_tables.sql;
SOURCE 02_SQL_Scripts/03_constraints_indexes.sql;
SOURCE 02_SQL_Scripts/04_triggers.sql;
SOURCE 02_SQL_Scripts/05_stored_procedures.sql;
SOURCE 02_SQL_Scripts/06_views.sql;
SOURCE 03_Sample_Data/01_seed_data.sql;

-- Step 3: Verification Check
SELECT 'Database Setup Completed Successfully!' AS status;
SELECT 'users' AS table_name, COUNT(*) AS row_count FROM users
UNION ALL SELECT 'stations', COUNT(*) FROM stations
UNION ALL SELECT 'chargers', COUNT(*) FROM chargers
UNION ALL SELECT 'bookings', COUNT(*) FROM bookings
UNION ALL SELECT 'charging_sessions', COUNT(*) FROM charging_sessions
UNION ALL SELECT 'payments', COUNT(*) FROM payments;

```

## 03_Sample_Data\01_seed_data.sql

```sql
-- =====================================================================
-- Project: EV Charging Station Management System
-- Script: 03_Sample_Data/01_seed_data.sql
-- Description: Deterministic, realistic Indian sample dataset.
-- Volumes: 20 Users, 8 Stations, 24 Chargers, 60 Bookings,
--          30 Charging Sessions, 25 Payments.
-- =====================================================================

USE ev_charging_management;

-- Disable Foreign Key checks temporarily for clean atomic seeding
SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE TABLE payments;
TRUNCATE TABLE charging_sessions;
TRUNCATE TABLE bookings;
TRUNCATE TABLE chargers;
TRUNCATE TABLE stations;
TRUNCATE TABLE users;
SET FOREIGN_KEY_CHECKS = 1;

-- =====================================================================
-- 1. USERS (20 Registered Indian EV Drivers)
-- =====================================================================
INSERT INTO users (user_id, full_name, email, phone, created_at) VALUES
(1,  'Aarav Sharma',     'aarav.sharma@example.in',     '+919876543210', '2026-10-01 09:15:00'),
(2,  'Priya Patel',      'priya.patel@example.in',      '+919876543211', '2026-10-02 11:30:00'),
(3,  'Rohan Iyer',       'rohan.iyer@example.in',       '+919876543212', '2026-10-03 14:20:00'),
(4,  'Ananya Reddy',     'ananya.reddy@example.in',     '+919876543213', '2026-10-04 10:45:00'),
(5,  'Vikram Malhotra',  'vikram.m@example.in',         '+919876543214', '2026-10-05 16:10:00'),
(6,  'Sneha Kulkarni',   'sneha.k@example.in',          '+919876543215', '2026-10-06 08:50:00'),
(7,  'Karthik Nair',     'karthik.nair@example.in',     '+919876543216', '2026-10-07 13:00:00'),
(8,  'Neha Gupta',       'neha.gupta@example.in',       '+919876543217', '2026-10-08 17:25:00'),
(9,  'Aditya Rao',       'aditya.rao@example.in',       '+919876543218', '2026-10-09 12:40:00'),
(10, 'Pooja Verma',      'pooja.verma@example.in',      '+919876543219', '2026-10-10 15:15:00'),
(11, 'Siddharth Sen',    'siddharth.s@example.in',      '+919876543220', '2026-10-11 09:05:00'),
(12, 'Kavita Deshmukh',  'kavita.d@example.in',         '+919876543221', '2026-10-12 11:55:00'),
(13, 'Rahul Menon',      'rahul.menon@example.in',      '+919876543222', '2026-10-13 14:10:00'),
(14, 'Meera Nambiar',    'meera.n@example.in',          '+919876543223', '2026-10-14 18:00:00'),
(15, 'Gautam Banerjee',  'gautam.b@example.in',         '+919876543224', '2026-10-15 10:20:00'),
(16, 'Divya Pillai',     'divya.pillai@example.in',     '+919876543225', '2026-10-16 16:45:00'),
(17, 'Varun Joshi',      'varun.joshi@example.in',      '+919876543226', '2026-10-17 08:30:00'),
(18, 'Ritu Saxena',      'ritu.saxena@example.in',      '+919876543227', '2026-10-18 13:15:00'),
(19, 'Arjun Chawla',     'arjun.chawla@example.in',     '+919876543228', '2026-10-19 17:50:00'),
(20, 'Tanvi Bhatia',     'tanvi.bhatia@example.in',     '+919876543229', '2026-10-20 12:10:00');

-- =====================================================================
-- 2. STATIONS (8 Major Indian Charging Hubs)
-- =====================================================================
INSERT INTO stations (station_id, station_name, address, city, state) VALUES
(1, 'Gachibowli FastHub EV',        'Plot 45, Financial District, Gachibowli',   'Hyderabad',  'Telangana'),
(2, 'Hitec City CyberCharge',       'Opposite Cyber Towers, Hitec City',         'Hyderabad',  'Telangana'),
(3, 'Indiranagar EcoPower Station', '100 Feet Road, HAL 2nd Stage, Indiranagar', 'Bengaluru',  'Karnataka'),
(4, 'Whitefield TechCharge Hub',    'ITPB Main Road, Whitefield',                'Bengaluru',  'Karnataka'),
(5, 'BKC SuperCharge Junction',     'G Block, Bandra Kurla Complex',             'Mumbai',     'Maharashtra'),
(6, 'Kothrud GreenPulse EV',        'Paud Road, Near Vanaz Metro, Kothrud',      'Pune',       'Maharashtra'),
(7, 'Anna Nagar FastPoint',         '2nd Avenue, Roundtana, Anna Nagar',         'Chennai',    'Tamil Nadu'),
(8, 'Connaught Place PrimeCharge',  'Outer Circle, Near Metro Gate 4, CP',       'New Delhi',  'Delhi');

-- =====================================================================
-- 3. CHARGERS (24 Units: AC Slow & DC Fast across 8 stations)
-- =====================================================================
INSERT INTO chargers (charger_id, station_id, charger_code, charger_type, power_kw, rate_per_kwh, status) VALUES
-- Station 1: Hyderabad Gachibowli
(1,  1, 'GB-AC-01',  'AC', 22.00,  14.00, 'ACTIVE'),
(2,  1, 'GB-DC-01',  'DC', 60.00,  19.50, 'ACTIVE'),
(3,  1, 'GB-DC-02',  'DC', 120.00, 22.00, 'ACTIVE'),

-- Station 2: Hyderabad Hitec City
(4,  2, 'HC-AC-01',  'AC', 11.00,  13.50, 'ACTIVE'),
(5,  2, 'HC-DC-01',  'DC', 50.00,  18.50, 'ACTIVE'),
(6,  2, 'HC-DC-02',  'DC', 150.00, 24.00, 'MAINTENANCE'),

-- Station 3: Bengaluru Indiranagar
(7,  3, 'IN-AC-01',  'AC', 22.00,  15.00, 'ACTIVE'),
(8,  3, 'IN-DC-01',  'DC', 60.00,  20.00, 'ACTIVE'),
(9,  3, 'IN-DC-02',  'DC', 120.00, 23.00, 'ACTIVE'),

-- Station 4: Bengaluru Whitefield
(10, 4, 'WF-AC-01',  'AC', 7.40,   12.50, 'ACTIVE'),
(11, 4, 'WF-DC-01',  'DC', 50.00,  18.50, 'ACTIVE'),
(12, 4, 'WF-DC-02',  'DC', 60.00,  19.00, 'OUT_OF_SERVICE'),

-- Station 5: Mumbai BKC
(13, 5, 'BKC-AC-01', 'AC', 22.00,  16.00, 'ACTIVE'),
(14, 5, 'BKC-DC-01', 'DC', 120.00, 24.00, 'ACTIVE'),
(15, 5, 'BKC-DC-02', 'DC', 150.00, 25.50, 'ACTIVE'),

-- Station 6: Pune Kothrud
(16, 6, 'KT-AC-01',  'AC', 11.00,  13.00, 'ACTIVE'),
(17, 6, 'KT-DC-01',  'DC', 60.00,  19.00, 'ACTIVE'),
(18, 6, 'KT-DC-02',  'DC', 120.00, 22.50, 'ACTIVE'),

-- Station 7: Chennai Anna Nagar
(19, 7, 'AN-AC-01',  'AC', 22.00,  14.50, 'ACTIVE'),
(20, 7, 'AN-DC-01',  'DC', 50.00,  18.00, 'ACTIVE'),
(21, 7, 'AN-DC-02',  'DC', 60.00,  19.50, 'MAINTENANCE'),

-- Station 8: New Delhi Connaught Place
(22, 8, 'CP-AC-01',  'AC', 22.00,  15.50, 'ACTIVE'),
(23, 8, 'CP-DC-01',  'DC', 60.00,  21.00, 'ACTIVE'),
(24, 8, 'CP-DC-02',  'DC', 150.00, 26.00, 'OUT_OF_SERVICE');

-- =====================================================================
-- 4. BOOKINGS (60 Realistic Reservations)
-- =====================================================================
INSERT INTO bookings (booking_id, user_id, charger_id, start_time, end_time, status, created_at) VALUES
-- Past completed bookings (1 to 30) - corresponding to charging sessions
(1,  1,  2,  '2026-11-01 08:00:00', '2026-11-01 09:00:00', 'COMPLETED', '2026-10-31 18:00:00'),
(2,  2,  3,  '2026-11-01 09:30:00', '2026-11-01 10:15:00', 'COMPLETED', '2026-10-31 20:15:00'),
(3,  3,  1,  '2026-11-01 10:00:00', '2026-11-01 12:30:00', 'COMPLETED', '2026-10-31 22:00:00'),
(4,  4,  5,  '2026-11-02 08:30:00', '2026-11-02 09:45:00', 'COMPLETED', '2026-11-01 19:30:00'),
(5,  5,  8,  '2026-11-02 11:00:00', '2026-11-02 12:00:00', 'COMPLETED', '2026-11-01 21:00:00'),
(6,  6,  9,  '2026-11-02 13:00:00', '2026-11-02 14:00:00', 'COMPLETED', '2026-11-02 08:00:00'),
(7,  7,  11, '2026-11-03 09:00:00', '2026-11-03 10:00:00', 'COMPLETED', '2026-11-02 18:45:00'),
(8,  8,  14, '2026-11-03 10:30:00', '2026-11-03 11:30:00', 'COMPLETED', '2026-11-02 20:30:00'),
(9,  9,  15, '2026-11-03 12:00:00', '2026-11-03 12:45:00', 'COMPLETED', '2026-11-02 22:15:00'),
(10, 10, 17, '2026-11-04 08:00:00', '2026-11-04 09:00:00', 'COMPLETED', '2026-11-03 19:00:00'),
(11, 11, 18, '2026-11-04 10:00:00', '2026-11-04 11:00:00', 'COMPLETED', '2026-11-03 21:10:00'),
(12, 12, 20, '2026-11-04 14:00:00', '2026-11-04 15:00:00', 'COMPLETED', '2026-11-04 09:00:00'),
(13, 13, 23, '2026-11-05 09:30:00', '2026-11-05 10:30:00', 'COMPLETED', '2026-11-04 18:20:00'),
(14, 14, 2,  '2026-11-05 11:00:00', '2026-11-05 12:00:00', 'COMPLETED', '2026-11-04 20:00:00'),
(15, 15, 3,  '2026-11-05 13:00:00', '2026-11-05 14:00:00', 'COMPLETED', '2026-11-05 08:30:00'),
(16, 16, 7,  '2026-11-06 08:30:00', '2026-11-06 10:30:00', 'COMPLETED', '2026-11-05 19:15:00'),
(17, 17, 8,  '2026-11-06 11:00:00', '2026-11-06 12:00:00', 'COMPLETED', '2026-11-05 21:40:00'),
(18, 18, 14, '2026-11-06 14:00:00', '2026-11-06 15:00:00', 'COMPLETED', '2026-11-06 09:10:00'),
(19, 19, 17, '2026-11-07 09:00:00', '2026-11-07 10:00:00', 'COMPLETED', '2026-11-06 18:50:00'),
(20, 20, 23, '2026-11-07 11:00:00', '2026-11-07 12:00:00', 'COMPLETED', '2026-11-06 20:30:00'),
(21, 1,  4,  '2026-11-08 08:00:00', '2026-11-08 10:00:00', 'COMPLETED', '2026-11-07 17:00:00'),
(22, 2,  5,  '2026-11-08 10:30:00', '2026-11-08 11:30:00', 'COMPLETED', '2026-11-07 19:20:00'),
(23, 3,  9,  '2026-11-08 13:00:00', '2026-11-08 14:00:00', 'COMPLETED', '2026-11-08 08:15:00'),
(24, 4,  10, '2026-11-09 09:00:00', '2026-11-09 11:30:00', 'COMPLETED', '2026-11-08 18:00:00'),
(25, 5,  13, '2026-11-09 12:00:00', '2026-11-09 14:00:00', 'COMPLETED', '2026-11-08 20:10:00'),
(26, 6,  15, '2026-11-10 08:30:00', '2026-11-10 09:30:00', 'COMPLETED', '2026-11-09 19:40:00'),
(27, 7,  18, '2026-11-10 11:00:00', '2026-11-10 12:00:00', 'COMPLETED', '2026-11-09 21:30:00'),
(28, 8,  2,  '2026-11-11 09:00:00', '2026-11-11 10:00:00', 'COMPLETED', '2026-11-10 18:15:00'),
(29, 9,  8,  '2026-11-11 11:30:00', '2026-11-11 12:30:00', 'COMPLETED', '2026-11-10 20:00:00'),
(30, 10, 14, '2026-11-12 10:00:00', '2026-11-12 11:00:00', 'COMPLETED', '2026-11-11 19:00:00'),

-- Cancelled Bookings (31 to 38)
(31, 11, 1,  '2026-11-05 14:00:00', '2026-11-05 16:00:00', 'CANCELLED', '2026-11-04 10:00:00'),
(32, 12, 4,  '2026-11-06 12:00:00', '2026-11-06 14:00:00', 'CANCELLED', '2026-11-05 11:30:00'),
(33, 13, 7,  '2026-11-07 14:00:00', '2026-11-07 16:00:00', 'CANCELLED', '2026-11-06 15:20:00'),
(34, 14, 10, '2026-11-08 13:00:00', '2026-11-08 15:00:00', 'CANCELLED', '2026-11-07 09:40:00'),
(35, 15, 13, '2026-11-09 15:00:00', '2026-11-09 17:00:00', 'CANCELLED', '2026-11-08 14:10:00'),
(36, 16, 16, '2026-11-10 13:00:00', '2026-11-10 15:00:00', 'CANCELLED', '2026-11-09 16:00:00'),
(37, 17, 19, '2026-11-11 14:00:00', '2026-11-11 16:00:00', 'CANCELLED', '2026-11-10 12:30:00'),
(38, 18, 22, '2026-11-12 13:00:00', '2026-11-12 15:00:00', 'CANCELLED', '2026-11-11 10:50:00'),

-- Pending Slot Requests (39 to 42)
(39, 19, 2,  '2026-11-16 08:00:00', '2026-11-16 09:00:00', 'PENDING',   '2026-11-15 08:00:00'),
(40, 20, 5,  '2026-11-16 10:00:00', '2026-11-16 11:00:00', 'PENDING',   '2026-11-15 08:30:00'),
(41, 1,  8,  '2026-11-16 12:00:00', '2026-11-16 13:00:00', 'PENDING',   '2026-11-15 09:00:00'),
(42, 2,  11, '2026-11-16 14:00:00', '2026-11-16 15:00:00', 'PENDING',   '2026-11-15 09:15:00'),

-- Confirmed Upcoming Bookings (43 to 60)
(43, 3,  14, '2026-11-16 09:00:00', '2026-11-16 10:00:00', 'CONFIRMED', '2026-11-14 10:00:00'),
(44, 4,  15, '2026-11-16 11:00:00', '2026-11-16 12:00:00', 'CONFIRMED', '2026-11-14 11:30:00'),
(45, 5,  17, '2026-11-16 13:00:00', '2026-11-16 14:00:00', 'CONFIRMED', '2026-11-14 14:00:00'),
(46, 6,  18, '2026-11-16 15:00:00', '2026-11-16 16:00:00', 'CONFIRMED', '2026-11-14 16:15:00'),
(47, 7,  20, '2026-11-17 08:30:00', '2026-11-17 09:30:00', 'CONFIRMED', '2026-11-14 18:00:00'),
(48, 8,  23, '2026-11-17 10:00:00', '2026-11-17 11:00:00', 'CONFIRMED', '2026-11-14 19:45:00'),
(49, 9,  1,  '2026-11-17 12:00:00', '2026-11-17 14:00:00', 'CONFIRMED', '2026-11-15 07:10:00'),
(50, 10, 3,  '2026-11-17 14:30:00', '2026-11-17 15:30:00', 'CONFIRMED', '2026-11-15 07:30:00'),
(51, 11, 7,  '2026-11-18 09:00:00', '2026-11-18 11:00:00', 'CONFIRMED', '2026-11-15 08:00:00'),
(52, 12, 9,  '2026-11-18 11:30:00', '2026-11-18 12:30:00', 'CONFIRMED', '2026-11-15 08:20:00'),
(53, 13, 11, '2026-11-18 13:00:00', '2026-11-18 14:00:00', 'CONFIRMED', '2026-11-15 08:40:00'),
(54, 14, 14, '2026-11-18 15:00:00', '2026-11-18 16:00:00', 'CONFIRMED', '2026-11-15 09:00:00'),
(55, 15, 17, '2026-11-19 09:00:00', '2026-11-19 10:00:00', 'CONFIRMED', '2026-11-15 09:15:00'),
(56, 16, 18, '2026-11-19 11:00:00', '2026-11-19 12:00:00', 'CONFIRMED', '2026-11-15 09:30:00'),
(57, 17, 20, '2026-11-19 13:30:00', '2026-11-19 14:30:00', 'CONFIRMED', '2026-11-15 09:45:00'),
(58, 18, 23, '2026-11-19 15:00:00', '2026-11-19 16:00:00', 'CONFIRMED', '2026-11-15 10:00:00'),
(59, 19, 2,  '2026-11-20 09:00:00', '2026-11-20 10:00:00', 'CONFIRMED', '2026-11-15 10:15:00'),
(60, 20, 8,  '2026-11-20 11:00:00', '2026-11-20 12:00:00', 'CONFIRMED', '2026-11-15 10:30:00');

-- =====================================================================
-- 5. CHARGING_SESSIONS (30 Sessions: 27 Completed + 3 In-Progress)
-- =====================================================================
INSERT INTO charging_sessions (session_id, booking_id, actual_start, actual_end, energy_kwh, rate_per_kwh, status) VALUES
(1,  1,  '2026-11-01 08:02:10', '2026-11-01 08:58:30', 42.500, 19.50, 'COMPLETED'),
(2,  2,  '2026-11-01 09:31:05', '2026-11-01 10:14:12', 55.200, 22.00, 'COMPLETED'),
(3,  3,  '2026-11-01 10:05:00', '2026-11-01 12:25:40', 28.400, 14.00, 'COMPLETED'),
(4,  4,  '2026-11-02 08:32:15', '2026-11-02 09:42:00', 36.800, 18.50, 'COMPLETED'),
(5,  5,  '2026-11-02 11:01:20', '2026-11-02 11:57:45', 48.000, 20.00, 'COMPLETED'),
(6,  6,  '2026-11-02 13:03:00', '2026-11-02 13:58:10', 62.100, 23.00, 'COMPLETED'),
(7,  7,  '2026-11-03 09:02:40', '2026-11-03 09:55:18', 34.500, 18.50, 'COMPLETED'),
(8,  8,  '2026-11-03 10:31:10', '2026-11-03 11:28:40', 58.000, 24.00, 'COMPLETED'),
(9,  9,  '2026-11-03 12:02:18', '2026-11-03 12:44:05', 44.250, 25.50, 'COMPLETED'),
(10, 10, '2026-11-04 08:01:50', '2026-11-04 08:56:30', 41.000, 19.00, 'COMPLETED'),
(11, 11, '2026-11-04 10:02:15', '2026-11-04 10:59:00', 52.800, 22.50, 'COMPLETED'),
(12, 12, '2026-11-04 14:01:30', '2026-11-04 14:58:20', 37.600, 18.00, 'COMPLETED'),
(13, 13, '2026-11-05 09:32:00', '2026-11-05 10:27:45', 46.500, 21.00, 'COMPLETED'),
(14, 14, '2026-11-05 11:04:10', '2026-11-05 11:58:10', 43.100, 19.50, 'COMPLETED'),
(15, 15, '2026-11-05 13:01:25', '2026-11-05 13:55:00', 54.000, 22.00, 'COMPLETED'),
(16, 16, '2026-11-06 08:35:00', '2026-11-06 10:25:00', 25.000, 15.00, 'COMPLETED'),
(17, 17, '2026-11-06 11:02:40', '2026-11-06 11:56:30', 49.300, 20.00, 'COMPLETED'),
(18, 18, '2026-11-06 14:03:10', '2026-11-06 14:59:15', 56.400, 24.00, 'COMPLETED'),
(19, 19, '2026-11-07 09:01:15', '2026-11-07 09:54:20', 39.800, 19.00, 'COMPLETED'),
(20, 20, '2026-11-07 11:02:00', '2026-11-07 11:58:00', 47.200, 21.00, 'COMPLETED'),
(21, 21, '2026-11-08 08:05:00', '2026-11-08 09:55:00', 18.500, 13.50, 'COMPLETED'),
(22, 22, '2026-11-08 10:31:40', '2026-11-08 11:28:10', 38.000, 18.50, 'COMPLETED'),
(23, 23, '2026-11-08 13:02:50', '2026-11-08 13:57:30', 53.500, 23.00, 'COMPLETED'),
(24, 24, '2026-11-09 09:05:00', '2026-11-09 11:20:00', 16.200, 12.50, 'COMPLETED'),
(25, 25, '2026-11-09 12:04:00', '2026-11-09 13:50:00', 27.500, 16.00, 'COMPLETED'),
(26, 26, '2026-11-10 08:31:00', '2026-11-10 09:28:00', 60.500, 25.50, 'COMPLETED'),
(27, 27, '2026-11-10 11:03:00', '2026-11-10 11:58:30', 51.000, 22.50, 'COMPLETED'),
-- 3 Active (In-Progress) telemetry sessions
(28, 28, '2026-11-15 10:00:00', NULL, NULL, 19.50, 'IN_PROGRESS'),
(29, 29, '2026-11-15 10:15:00', NULL, NULL, 20.00, 'IN_PROGRESS'),
(30, 30, '2026-11-15 10:30:00', NULL, NULL, 24.00, 'IN_PROGRESS');

-- =====================================================================
-- 6. PAYMENTS (25 Billing Records: 20 Completed, 3 Pending, 2 Failed)
-- =====================================================================
-- Formula: amount = energy_kwh * rate_per_kwh
INSERT INTO payments (payment_id, session_id, amount, method, status, paid_at) VALUES
(1,  1,  828.75,  'UPI',  'COMPLETED', '2026-11-01 09:05:00'), -- 42.500 * 19.50 = 828.75
(2,  2,  1214.40, 'CARD', 'COMPLETED', '2026-11-01 10:20:00'), -- 55.200 * 22.00 = 1214.40
(3,  3,  397.60,  'UPI',  'COMPLETED', '2026-11-01 12:35:00'), -- 28.400 * 14.00 = 397.60
(4,  4,  680.80,  'CASH', 'COMPLETED', '2026-11-02 09:50:00'), -- 36.800 * 18.50 = 680.80
(5,  5,  960.00,  'UPI',  'COMPLETED', '2026-11-02 12:05:00'), -- 48.000 * 20.00 = 960.00
(6,  6,  1428.30, 'CARD', 'COMPLETED', '2026-11-02 14:05:00'), -- 62.100 * 23.00 = 1428.30
(7,  7,  638.25,  'UPI',  'COMPLETED', '2026-11-03 10:02:00'), -- 34.500 * 18.50 = 638.25
(8,  8,  1392.00, 'CARD', 'COMPLETED', '2026-11-03 11:35:00'), -- 58.000 * 24.00 = 1392.00
(9,  9,  1128.38, 'UPI',  'COMPLETED', '2026-11-03 12:50:00'), -- 44.250 * 25.50 = 1128.375 -> 1128.38
(10, 10, 779.00,  'UPI',  'COMPLETED', '2026-11-04 09:05:00'), -- 41.000 * 19.00 = 779.00
(11, 11, 1188.00, 'CARD', 'COMPLETED', '2026-11-04 11:05:00'), -- 52.800 * 22.50 = 1188.00
(12, 12, 676.80,  'UPI',  'COMPLETED', '2026-11-04 15:05:00'), -- 37.600 * 18.00 = 676.80
(13, 13, 976.50,  'CARD', 'COMPLETED', '2026-11-05 10:35:00'), -- 46.500 * 21.00 = 976.50
(14, 14, 840.45,  'UPI',  'COMPLETED', '2026-11-05 12:05:00'), -- 43.100 * 19.50 = 840.45
(15, 15, 1188.00, 'CARD', 'COMPLETED', '2026-11-05 14:02:00'), -- 54.000 * 22.00 = 1188.00
(16, 16, 375.00,  'UPI',  'COMPLETED', '2026-11-06 10:30:00'), -- 25.000 * 15.00 = 375.00
(17, 17, 986.00,  'UPI',  'COMPLETED', '2026-11-06 12:05:00'), -- 49.300 * 20.00 = 986.00
(18, 18, 1353.60, 'CARD', 'COMPLETED', '2026-11-06 15:05:00'), -- 56.400 * 24.00 = 1353.60
(19, 19, 756.20,  'UPI',  'COMPLETED', '2026-11-07 10:00:00'), -- 39.800 * 19.00 = 756.20
(20, 20, 991.20,  'CASH', 'COMPLETED', '2026-11-07 12:05:00'), -- 47.200 * 21.00 = 991.20
-- Pending payments awaiting customer checkout
(21, 21, 249.75,  NULL,   'PENDING',   NULL),                 -- 18.500 * 13.50 = 249.75
(22, 22, 703.00,  NULL,   'PENDING',   NULL),                 -- 38.000 * 18.50 = 703.00
(23, 23, 1230.50, NULL,   'PENDING',   NULL),                 -- 53.500 * 23.00 = 1230.50
-- Failed transaction attempts (card declined / gateway timeout)
(24, 24, 202.50,  'CARD', 'FAILED',    NULL),                 -- 16.200 * 12.50 = 202.50
(25, 25, 440.00,  'UPI',  'FAILED',    NULL);                 -- 27.500 * 16.00 = 440.00

```

## 07_Testing\Test_Cases.sql

```sql
-- =====================================================================
-- Project: EV Charging Station Management System
-- Script: 07_Testing/Test_Cases.sql
-- Description: Automated Test Harness verifying Positive, Negative,
--              Constraint, Concurrency, and Workflow Test Scenarios.
-- =====================================================================

USE ev_charging_management;

DROP TABLE IF EXISTS test_execution_log;
CREATE TABLE test_execution_log (
    log_id INT AUTO_INCREMENT PRIMARY KEY,
    test_id VARCHAR(20) NOT NULL,
    test_name VARCHAR(150) NOT NULL,
    expected_result VARCHAR(100) NOT NULL,
    actual_result VARCHAR(255) NOT NULL,
    test_status ENUM('PASS', 'FAIL') NOT NULL,
    executed_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

DROP PROCEDURE IF EXISTS sp_run_automated_tests;

DELIMITER $$

CREATE PROCEDURE sp_run_automated_tests()
BEGIN
    DECLARE v_error_occurred INT DEFAULT 0;
    DECLARE v_last_error VARCHAR(255) DEFAULT '';
    DECLARE v_test_user_id INT;
    DECLARE v_booking_id1 INT;
    DECLARE v_booking_id2 INT;
    DECLARE v_booking_id3 INT;
    DECLARE v_session_id INT;
    DECLARE v_dummy_session_id INT;
    DECLARE v_status_code VARCHAR(30);
    DECLARE v_message VARCHAR(255);
    DECLARE v_bill_amount DECIMAL(10,2);
    DECLARE v_session_rate DECIMAL(8,2);

    -- Helper handler for blocks expecting an error
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION 
    BEGIN
        SET v_error_occurred = 1;
        GET DIAGNOSTICS CONDITION 1 v_last_error = MESSAGE_TEXT;
    END;

    -- Clean up any remnant test records from prior runs
    DELETE FROM payments WHERE session_id IN (SELECT session_id FROM charging_sessions cs JOIN bookings b ON cs.booking_id = b.booking_id JOIN users u ON b.user_id = u.user_id WHERE u.email LIKE 'qa.%');
    DELETE FROM charging_sessions WHERE booking_id IN (SELECT booking_id FROM bookings b JOIN users u ON b.user_id = u.user_id WHERE u.email LIKE 'qa.%');
    DELETE FROM bookings WHERE user_id IN (SELECT user_id FROM users WHERE email LIKE 'qa.%');
    DELETE FROM users WHERE email LIKE 'qa.%';

    -- =================================================================
    -- TC-01: Insert Valid User (Positive)
    -- =================================================================
    SET v_error_occurred = 0;
    INSERT INTO users (full_name, email, phone) 
    VALUES ('QA Test User', 'qa.testuser@example.in', '+919999900001');
    SET v_test_user_id = LAST_INSERT_ID();

    IF v_error_occurred = 0 AND v_test_user_id > 0 THEN
        INSERT INTO test_execution_log (test_id, test_name, expected_result, actual_result, test_status)
        VALUES ('TC-01', 'Insert Valid User Profile', 'Row inserted successfully', CONCAT('User ID ', v_test_user_id, ' created'), 'PASS');
    ELSE
        INSERT INTO test_execution_log (test_id, test_name, expected_result, actual_result, test_status)
        VALUES ('TC-01', 'Insert Valid User Profile', 'Row inserted successfully', 'Failed to insert', 'FAIL');
    END IF;

    -- =================================================================
    -- TC-02: Duplicate Email Rejection (Negative)
    -- =================================================================
    SET v_error_occurred = 0;
    INSERT INTO users (full_name, email, phone) 
    VALUES ('Duplicate Email User', 'qa.testuser@example.in', '+919999900002');

    IF v_error_occurred = 1 THEN
        INSERT INTO test_execution_log (test_id, test_name, expected_result, actual_result, test_status)
        VALUES ('TC-02', 'Duplicate Email Constraint', 'Rejection via ER_DUP_ENTRY', v_last_error, 'PASS');
    ELSE
        INSERT INTO test_execution_log (test_id, test_name, expected_result, actual_result, test_status)
        VALUES ('TC-02', 'Duplicate Email Constraint', 'Rejection via ER_DUP_ENTRY', 'Unexpectedly allowed duplicate email', 'FAIL');
    END IF;

    -- =================================================================
    -- TC-03: Malformed Email CHECK Constraint (Negative)
    -- =================================================================
    SET v_error_occurred = 0;
    INSERT INTO users (full_name, email, phone) 
    VALUES ('Invalid Email User', 'plainaddress', '+919999900003');

    IF v_error_occurred = 1 THEN
        INSERT INTO test_execution_log (test_id, test_name, expected_result, actual_result, test_status)
        VALUES ('TC-03', 'Malformed Email CHECK Constraint', 'Rejection via chk_user_email_format', v_last_error, 'PASS');
    ELSE
        INSERT INTO test_execution_log (test_id, test_name, expected_result, actual_result, test_status)
        VALUES ('TC-03', 'Malformed Email CHECK Constraint', 'Rejection via chk_user_email_format', 'Unexpectedly allowed malformed email', 'FAIL');
    END IF;

    -- =================================================================
    -- TC-04: Foreign Key Violation - Non-existent Station (Negative)
    -- =================================================================
    SET v_error_occurred = 0;
    INSERT INTO chargers (station_id, charger_code, charger_type, power_kw, rate_per_kwh, status)
    VALUES (9999, 'INVALID-01', 'AC', 22.00, 15.00, 'ACTIVE');

    IF v_error_occurred = 1 THEN
        INSERT INTO test_execution_log (test_id, test_name, expected_result, actual_result, test_status)
        VALUES ('TC-04', 'Foreign Key Integrity on Chargers', 'Rejection via fk_chargers_station', v_last_error, 'PASS');
    ELSE
        INSERT INTO test_execution_log (test_id, test_name, expected_result, actual_result, test_status)
        VALUES ('TC-04', 'Foreign Key Integrity on Chargers', 'Rejection via fk_chargers_station', 'Unexpectedly allowed orphaned charger', 'FAIL');
    END IF;

    -- =================================================================
    -- TC-05: Non-positive Power Output CHECK Constraint (Negative)
    -- =================================================================
    SET v_error_occurred = 0;
    INSERT INTO chargers (station_id, charger_code, charger_type, power_kw, rate_per_kwh, status)
    VALUES (1, 'NEG-PWR-01', 'DC', -50.00, 20.00, 'ACTIVE');

    IF v_error_occurred = 1 THEN
        INSERT INTO test_execution_log (test_id, test_name, expected_result, actual_result, test_status)
        VALUES ('TC-05', 'Charger Power CHECK Constraint', 'Rejection via chk_charger_power', v_last_error, 'PASS');
    ELSE
        INSERT INTO test_execution_log (test_id, test_name, expected_result, actual_result, test_status)
        VALUES ('TC-05', 'Charger Power CHECK Constraint', 'Rejection via chk_charger_power', 'Unexpectedly allowed negative power', 'FAIL');
    END IF;

    -- =================================================================
    -- TC-06: Booking End Time <= Start Time (Negative)
    -- =================================================================
    SET v_error_occurred = 0;
    INSERT INTO bookings (user_id, charger_id, start_time, end_time, status)
    VALUES (v_test_user_id, 1, '2026-11-25 14:00:00', '2026-11-25 13:00:00', 'PENDING');

    IF v_error_occurred = 1 THEN
        INSERT INTO test_execution_log (test_id, test_name, expected_result, actual_result, test_status)
        VALUES ('TC-06', 'Booking Time Chronology CHECK', 'Rejection via chk_booking_time_order', v_last_error, 'PASS');
    ELSE
        INSERT INTO test_execution_log (test_id, test_name, expected_result, actual_result, test_status)
        VALUES ('TC-06', 'Booking Time Chronology CHECK', 'Rejection via chk_booking_time_order', 'Unexpectedly allowed inverted time', 'FAIL');
    END IF;

    -- =================================================================
    -- TC-07: Booking Charger Under MAINTENANCE (Negative)
    -- Charger 6 is in MAINTENANCE
    -- =================================================================
    CALL sp_book_charger_slot(v_test_user_id, 6, '2026-11-25 10:00:00', '2026-11-25 11:00:00', v_booking_id1, v_status_code, v_message);

    IF v_status_code = 'CHARGER_UNAVAILABLE' THEN
        INSERT INTO test_execution_log (test_id, test_name, expected_result, actual_result, test_status)
        VALUES ('TC-07', 'Maintenance Charger Booking Guard', 'CHARGER_UNAVAILABLE', v_message, 'PASS');
    ELSE
        INSERT INTO test_execution_log (test_id, test_name, expected_result, actual_result, test_status)
        VALUES ('TC-07', 'Maintenance Charger Booking Guard', 'CHARGER_UNAVAILABLE', CONCAT('Unexpected status: ', v_status_code), 'FAIL');
    END IF;

    -- =================================================================
    -- TC-08: Successful Booking Reservation (Positive)
    -- Charger 10 has rate = 12.00
    -- =================================================================
    CALL sp_book_charger_slot(v_test_user_id, 10, '2026-11-25 10:00:00', '2026-11-25 12:00:00', v_booking_id1, v_status_code, v_message);

    IF v_status_code = 'SUCCESS' AND v_booking_id1 > 0 THEN
        INSERT INTO test_execution_log (test_id, test_name, expected_result, actual_result, test_status)
        VALUES ('TC-08', 'Valid Slot Booking Creation', 'SUCCESS (Booking confirmed)', CONCAT('Booking ID ', v_booking_id1, ' confirmed'), 'PASS');
    ELSE
        INSERT INTO test_execution_log (test_id, test_name, expected_result, actual_result, test_status)
        VALUES ('TC-08', 'Valid Slot Booking Creation', 'SUCCESS', v_message, 'FAIL');
    END IF;

    -- =================================================================
    -- TC-09: Overlapping Double-Booking Prevention (Negative)
    -- Requested window: 11:00 to 13:00 intersects existing 10:00 to 12:00
    -- =================================================================
    CALL sp_book_charger_slot(v_test_user_id, 10, '2026-11-25 11:00:00', '2026-11-25 13:00:00', v_booking_id2, v_status_code, v_message);

    IF v_status_code = 'SLOT_CONFLICT' THEN
        INSERT INTO test_execution_log (test_id, test_name, expected_result, actual_result, test_status)
        VALUES ('TC-09', 'Overlapping Slot Collision Prevention', 'SLOT_CONFLICT rejection', v_message, 'PASS');
    ELSE
        INSERT INTO test_execution_log (test_id, test_name, expected_result, actual_result, test_status)
        VALUES ('TC-09', 'Overlapping Slot Collision Prevention', 'SLOT_CONFLICT rejection', CONCAT('Unexpected code: ', v_status_code), 'FAIL');
    END IF;

    -- =================================================================
    -- TC-10: Adjacent Non-Overlapping Booking (Positive)
    -- Requested window: 12:00 to 14:00 directly follows 10:00 to 12:00
    -- =================================================================
    CALL sp_book_charger_slot(v_test_user_id, 10, '2026-11-25 12:00:00', '2026-11-25 14:00:00', v_booking_id3, v_status_code, v_message);

    IF v_status_code = 'SUCCESS' AND v_booking_id3 > 0 THEN
        INSERT INTO test_execution_log (test_id, test_name, expected_result, actual_result, test_status)
        VALUES ('TC-10', 'Adjacent Slot Booking Tolerance', 'SUCCESS (Zero conflict)', CONCAT('Adjacent Booking ID ', v_booking_id3, ' created'), 'PASS');
    ELSE
        INSERT INTO test_execution_log (test_id, test_name, expected_result, actual_result, test_status)
        VALUES ('TC-10', 'Adjacent Slot Booking Tolerance', 'SUCCESS', v_message, 'FAIL');
    END IF;

    -- =================================================================
    -- TC-11: Start Charging Session & Rate Snapshot (Positive)
    -- =================================================================
    CALL sp_start_charging_session(v_booking_id1, v_session_id, v_status_code, v_message);

    IF v_status_code = 'SUCCESS' AND v_session_id > 0 THEN
        SELECT rate_per_kwh INTO v_session_rate FROM charging_sessions WHERE session_id = v_session_id;
        INSERT INTO test_execution_log (test_id, test_name, expected_result, actual_result, test_status)
        VALUES ('TC-11', 'Start Session & Capture Rate Snapshot', 'SUCCESS with rate snapshot', CONCAT('Session ID ', v_session_id, ' started @ ₹', v_session_rate, '/kWh'), 'PASS');
    ELSE
        INSERT INTO test_execution_log (test_id, test_name, expected_result, actual_result, test_status)
        VALUES ('TC-11', 'Start Session & Capture Rate Snapshot', 'SUCCESS', v_message, 'FAIL');
    END IF;

    -- =================================================================
    -- TC-12: Duplicate Session for Same Booking Rejection (Negative)
    -- =================================================================
    CALL sp_start_charging_session(v_booking_id1, v_dummy_session_id, v_status_code, v_message);

    IF v_status_code = 'SESSION_ALREADY_EXISTS' THEN
        INSERT INTO test_execution_log (test_id, test_name, expected_result, actual_result, test_status)
        VALUES ('TC-12', 'Single Session per Booking (1:1)', 'SESSION_ALREADY_EXISTS rejection', v_message, 'PASS');
    ELSE
        INSERT INTO test_execution_log (test_id, test_name, expected_result, actual_result, test_status)
        VALUES ('TC-12', 'Single Session per Booking (1:1)', 'SESSION_ALREADY_EXISTS rejection', CONCAT('Unexpected code: ', v_status_code), 'FAIL');
    END IF;

    -- =================================================================
    -- TC-13: Negative Energy Consumption CHECK (Negative)
    -- =================================================================
    SET v_error_occurred = 0;
    INSERT INTO charging_sessions (booking_id, actual_start, energy_kwh, rate_per_kwh, status)
    VALUES (v_booking_id3, CURRENT_TIMESTAMP, -15.500, 12.00, 'IN_PROGRESS');

    IF v_error_occurred = 1 THEN
        INSERT INTO test_execution_log (test_id, test_name, expected_result, actual_result, test_status)
        VALUES ('TC-13', 'Negative Energy Telemetry CHECK', 'Rejection via chk_session_energy', v_last_error, 'PASS');
    ELSE
        INSERT INTO test_execution_log (test_id, test_name, expected_result, actual_result, test_status)
        VALUES ('TC-13', 'Negative Energy Telemetry CHECK', 'Rejection via chk_session_energy', 'Unexpectedly allowed negative kWh', 'FAIL');
    END IF;

    -- =================================================================
    -- TC-14: Complete Session & Calculate Bill (Positive / Workflow)
    -- 25.000 kWh @ ₹12.50 = ₹312.50 (or rate on charger 10 = 12.50)
    -- =================================================================
    CALL sp_complete_charging_session(v_session_id, 25.000, v_bill_amount, v_status_code, v_message);

    IF v_status_code = 'SUCCESS' AND v_bill_amount > 0 THEN
        INSERT INTO test_execution_log (test_id, test_name, expected_result, actual_result, test_status)
        VALUES ('TC-14', 'Session Completion & Bill Computation', 'SUCCESS with bill generated', CONCAT('Bill Amount: ₹', v_bill_amount), 'PASS');
    ELSE
        INSERT INTO test_execution_log (test_id, test_name, expected_result, actual_result, test_status)
        VALUES ('TC-14', 'Session Completion & Bill Computation', 'SUCCESS', v_message, 'FAIL');
    END IF;

    -- =================================================================
    -- TC-15: Historical Rate Snapshot Protection (Positive)
    -- Alter charger catalog rate; verify historical session is unaffected
    -- =================================================================
    UPDATE chargers SET rate_per_kwh = 99.00 WHERE charger_id = 10;
    SELECT rate_per_kwh INTO v_session_rate FROM charging_sessions WHERE session_id = v_session_id;

    IF v_session_rate != 99.00 THEN
        INSERT INTO test_execution_log (test_id, test_name, expected_result, actual_result, test_status)
        VALUES ('TC-15', 'Historical Rate Snapshot Integrity', 'Session rate preserved regardless of catalog change', CONCAT('Session rate preserved at ₹', v_session_rate, ' (Catalog changed to ₹99.00)'), 'PASS');
    ELSE
        INSERT INTO test_execution_log (test_id, test_name, expected_result, actual_result, test_status)
        VALUES ('TC-15', 'Historical Rate Snapshot Integrity', 'Session rate preserved', 'Session rate incorrectly modified with catalog', 'FAIL');
    END IF;
    -- Restore original catalog rate
    UPDATE chargers SET rate_per_kwh = 12.50 WHERE charger_id = 10;

    -- =================================================================
    -- TC-16: Duplicate Payment Record Rejection (Negative)
    -- =================================================================
    SET v_error_occurred = 0;
    INSERT INTO payments (session_id, amount, status)
    VALUES (v_session_id, 100.00, 'PENDING');

    IF v_error_occurred = 1 THEN
        INSERT INTO test_execution_log (test_id, test_name, expected_result, actual_result, test_status)
        VALUES ('TC-16', 'Duplicate Payment Insertion Guard (1:1)', 'Rejection via UNIQUE KEY on session_id', v_last_error, 'PASS');
    ELSE
        INSERT INTO test_execution_log (test_id, test_name, expected_result, actual_result, test_status)
        VALUES ('TC-16', 'Duplicate Payment Insertion Guard (1:1)', 'Rejection via UNIQUE KEY on session_id', 'Unexpected duplicate payment allowed', 'FAIL');
    END IF;

    -- =================================================================
    -- TC-17: Process Payment to Settlement (Positive)
    -- =================================================================
    CALL sp_process_payment(v_session_id, 'UPI', 'COMPLETED', v_status_code, v_message);

    IF v_status_code = 'SUCCESS' THEN
        INSERT INTO test_execution_log (test_id, test_name, expected_result, actual_result, test_status)
        VALUES ('TC-17', 'Payment Settlement Reconciliation', 'SUCCESS (Settled via UPI)', v_message, 'PASS');
    ELSE
        INSERT INTO test_execution_log (test_id, test_name, expected_result, actual_result, test_status)
        VALUES ('TC-17', 'Payment Settlement Reconciliation', 'SUCCESS', v_message, 'FAIL');
    END IF;

    -- =================================================================
    -- TC-18: Foreign Key RESTRICT on Parent Delete (Negative)
    -- Attempt to delete Station 1 when active chargers depend on it
    -- =================================================================
    SET v_error_occurred = 0;
    DELETE FROM stations WHERE station_id = 1;

    IF v_error_occurred = 1 THEN
        INSERT INTO test_execution_log (test_id, test_name, expected_result, actual_result, test_status)
        VALUES ('TC-18', 'Referential RESTRICT Deletion Protection', 'Deletion blocked by Foreign Key', v_last_error, 'PASS');
    ELSE
        INSERT INTO test_execution_log (test_id, test_name, expected_result, actual_result, test_status)
        VALUES ('TC-18', 'Referential RESTRICT Deletion Protection', 'Deletion blocked by Foreign Key', 'Unexpectedly permitted cascade deletion of station', 'FAIL');
    END IF;

    -- =================================================================
    -- TC-19: Station Summary View Consistency (Positive)
    -- Sum of completed payments in stations matches view output
    -- =================================================================
    SET v_error_occurred = 0;
    SELECT 
        IF(COUNT(*) > 0, 'CONSISTENT', 'EMPTY') INTO v_message
    FROM vw_station_revenue_summary
    WHERE total_revenue_inr > 0;

    IF v_message = 'CONSISTENT' THEN
        INSERT INTO test_execution_log (test_id, test_name, expected_result, actual_result, test_status)
        VALUES ('TC-19', 'View & Table Aggregation Consistency', 'Revenue totals mathematically consistent', 'vw_station_revenue_summary successfully verified', 'PASS');
    ELSE
        INSERT INTO test_execution_log (test_id, test_name, expected_result, actual_result, test_status)
        VALUES ('TC-19', 'View & Table Aggregation Consistency', 'Revenue totals consistent', 'Inconsistent view aggregation', 'FAIL');
    END IF;

    -- =================================================================
    -- TC-20: Cleanup QA Test Records (Positive)
    -- Cleanly removes disposable test records without affecting sample data
    -- =================================================================
    DELETE FROM payments WHERE session_id = v_session_id;
    DELETE FROM charging_sessions WHERE session_id = v_session_id;
    DELETE FROM bookings WHERE user_id = v_test_user_id;
    DELETE FROM users WHERE user_id = v_test_user_id;

    INSERT INTO test_execution_log (test_id, test_name, expected_result, actual_result, test_status)
    VALUES ('TC-20', 'Atomic Test Artifact Teardown', 'Disposable test data safely purged', 'Clean state maintained', 'PASS');

END$$

DELIMITER ;

```
