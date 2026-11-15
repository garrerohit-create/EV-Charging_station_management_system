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
