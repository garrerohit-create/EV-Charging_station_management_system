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
