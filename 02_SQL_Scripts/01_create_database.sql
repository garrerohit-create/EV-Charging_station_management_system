
-- Step 1: Create our project database
CREATE DATABASE IF NOT EXISTS ev_charging_management;

-- Step 2: Select the database
USE ev_charging_management;

-- Step 3: Check the selected database
SELECT DATABASE() AS current_database;

-- Step 4: Check the MySQL version
SELECT VERSION() AS mysql_version;
