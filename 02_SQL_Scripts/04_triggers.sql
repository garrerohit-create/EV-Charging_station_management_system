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
