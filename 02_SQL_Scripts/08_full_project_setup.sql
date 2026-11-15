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
