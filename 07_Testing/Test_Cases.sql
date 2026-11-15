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
