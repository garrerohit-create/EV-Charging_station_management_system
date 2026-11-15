# Comprehensive SQL Query Execution Results & Analysis
## EV Charging Station Management System

**Executed on:** MySQL 8.4.13 LTS | **Database:** `ev_charging_management` | **Status:** All 32 Queries Passed (0 Errors)

---

### Section 1: Basic SQL & Filtering

#### Query 1: List all charging stations sorted by State and City
```sql
SELECT station_id, station_name, city, state, address
FROM stations
ORDER BY state ASC, city ASC;
```
**Actual Output:**
```text
+------------+------------------------------+-----------+-------------+-------------------------------------------+
| station_id | station_name                 | city      | state       | address                                   |
+------------+------------------------------+-----------+-------------+-------------------------------------------+
|          8 | Connaught Place PrimeCharge  | New Delhi | Delhi       | Outer Circle, Near Metro Gate 4, CP       |
|          3 | Indiranagar EcoPower Station | Bengaluru | Karnataka   | 100 Feet Road, HAL 2nd Stage, Indiranagar |
|          4 | Whitefield TechCharge Hub    | Bengaluru | Karnataka   | ITPB Main Road, Whitefield                |
|          5 | BKC SuperCharge Junction     | Mumbai    | Maharashtra | G Block, Bandra Kurla Complex             |
|          6 | Kothrud GreenPulse EV        | Pune      | Maharashtra | Paud Road, Near Vanaz Metro, Kothrud      |
|          7 | Anna Nagar FastPoint         | Chennai   | Tamil Nadu  | 2nd Avenue, Roundtana, Anna Nagar         |
|          1 | Gachibowli FastHub EV        | Hyderabad | Telangana   | Plot 45, Financial District, Gachibowli   |
|          2 | Hitec City CyberCharge       | Hyderabad | Telangana   | Opposite Cyber Towers, Hitec City         |
+------------+------------------------------+-----------+-------------+-------------------------------------------+
8 rows in set
```

#### Query 2: Display distinct charging power capacities available
```sql
SELECT DISTINCT power_kw, charger_type
FROM chargers
ORDER BY power_kw ASC;
```
**Actual Output:**
```text
+----------+--------------+
| power_kw | charger_type |
+----------+--------------+
|     7.40 | AC           |
|    11.00 | AC           |
|    22.00 | AC           |
|    50.00 | DC           |
|    60.00 | DC           |
|   120.00 | DC           |
|   150.00 | DC           |
+----------+--------------+
7 rows in set
```

#### Query 3: Active High-Speed DC Fast Chargers (>= 60 kW)
```sql
SELECT charger_id, station_id, charger_code, power_kw, rate_per_kwh, status
FROM chargers
WHERE charger_type = 'DC' AND power_kw >= 60.00 AND status = 'ACTIVE'
ORDER BY power_kw DESC;
```
**Actual Output:**
```text
+------------+------------+--------------+----------+--------------+--------+
| charger_id | station_id | charger_code | power_kw | rate_per_kwh | status |
+------------+------------+--------------+----------+--------------+--------+
|         15 |          5 | BKC-DC-02    |   150.00 |        25.50 | ACTIVE |
|          3 |          1 | GB-DC-02     |   120.00 |        22.00 | ACTIVE |
|          9 |          3 | IN-DC-02     |   120.00 |        23.00 | ACTIVE |
|         14 |          5 | BKC-DC-01    |   120.00 |        24.00 | ACTIVE |
|         18 |          6 | KT-DC-02     |   120.00 |        22.50 | ACTIVE |
|          2 |          1 | GB-DC-01     |    60.00 |        19.50 | ACTIVE |
|          8 |          3 | IN-DC-01     |    60.00 |        20.00 | ACTIVE |
|         17 |          6 | KT-DC-01     |    60.00 |        19.00 | ACTIVE |
|         23 |          8 | CP-DC-01     |    60.00 |        21.00 | ACTIVE |
+------------+------------+--------------+----------+--------------+--------+
9 rows in set
```

---

### Section 2: Relational Joins & Relational Algebra

#### Query 8: Full Lifecycle Join (Station -> Charger -> Booking -> Session -> Payment)
```sql
SELECT 
    s.station_name, c.charger_code, u.full_name AS customer,
    cs.actual_start, cs.energy_kwh, p.amount AS amount_paid,
    p.method AS payment_mode, p.status AS payment_state
FROM payments p
JOIN charging_sessions cs ON p.session_id = cs.session_id
JOIN bookings b           ON cs.booking_id = b.booking_id
JOIN users u              ON b.user_id = u.user_id
JOIN chargers c           ON b.charger_id = c.charger_id
JOIN stations s           ON c.station_id = s.station_id
WHERE p.status = 'COMPLETED'
ORDER BY p.amount DESC
LIMIT 5;
```
**Actual Output:**
```text
+------------------------------+--------------+-----------------+---------------------+------------+-------------+--------------+---------------+
| station_name                 | charger_code | customer        | actual_start        | energy_kwh | amount_paid | payment_mode | payment_state |
+------------------------------+--------------+-----------------+---------------------+------------+-------------+--------------+---------------+
| Indiranagar EcoPower Station | IN-DC-02     | Sneha Kulkarni  | 2026-11-02 13:03:00 |     62.100 |     1428.30 | CARD         | COMPLETED     |
| BKC SuperCharge Junction     | BKC-DC-01    | Neha Gupta      | 2026-11-03 10:31:10 |     58.000 |     1392.00 | CARD         | COMPLETED     |
| BKC SuperCharge Junction     | BKC-DC-01    | Ritu Saxena     | 2026-11-06 14:03:10 |     56.400 |     1353.60 | CARD         | COMPLETED     |
| Gachibowli FastHub EV        | GB-DC-02     | Priya Patel     | 2026-11-01 09:31:05 |     55.200 |     1214.40 | CARD         | COMPLETED     |
| Kothrud GreenPulse EV        | KT-DC-02     | Siddharth Sen   | 2026-11-04 10:02:15 |     52.800 |     1188.00 | CARD         | COMPLETED     |
+------------------------------+--------------+-----------------+---------------------+------------+-------------+--------------+---------------+
5 rows in set
```

---

### Section 3: Aggregation & Grouping Metrics

#### Query 11: Total and Average Electricity Consumption by Charger Speed Type
```sql
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
```
**Actual Output:**
```text
+--------------+--------------------+------------------+----------------------------+----------------+----------------+
| charger_type | completed_sessions | total_energy_kwh | avg_energy_per_session_kwh | min_energy_kwh | max_energy_kwh |
+--------------+--------------------+------------------+----------------------------+----------------+----------------+
| DC           |                 21 |          992.55  |                      47.26 |          34.50 |          62.10 |
| AC           |                  6 |          144.60  |                      24.10 |          16.20 |          28.40 |
+--------------+--------------------+------------------+----------------------------+----------------+----------------+
2 rows in set
```

#### Query 12: Financial Settlement by Payment Instrument
```sql
SELECT 
    COALESCE(method, 'UNSPECIFIED') AS payment_method,
    COUNT(*) AS total_transactions,
    SUM(CASE WHEN status = 'COMPLETED' THEN amount ELSE 0.00 END) AS settled_revenue_inr,
    SUM(CASE WHEN status = 'PENDING' THEN amount ELSE 0.00 END) AS pending_revenue_inr,
    SUM(CASE WHEN status = 'FAILED' THEN amount ELSE 0.00 END) AS failed_amount_inr
FROM payments
GROUP BY method;
```
**Actual Output:**
```text
+----------------+--------------------+---------------------+---------------------+-------------------+
| payment_method | total_transactions | settled_revenue_inr | pending_revenue_inr | failed_amount_inr |
+----------------+--------------------+---------------------+---------------------+-------------------+
| UPI            |                 12 |             8727.48 |                0.00 |            440.00 |
| CARD           |                  9 |             8542.80 |                0.00 |            202.50 |
| CASH           |                  2 |             1672.00 |                0.00 |              0.00 |
| UNSPECIFIED    |                  2 |                0.00 |             2183.25 |              0.00 |
+----------------+--------------------+---------------------+---------------------+-------------------+
4 rows in set
```

---

### Section 4: Advanced SQL (CTEs, Window Functions & Execution Plans)

#### Query 21: Common Table Expression (CTE) Monthly Revenue & Energy Metrics
```sql
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
```
**Actual Output:**
```text
+---------------+----------------+------------------+-------------------+------------------------+
| billing_month | total_sessions | total_energy_kwh | total_revenue_inr | effective_avg_rate_inr |
+---------------+----------------+------------------+-------------------+------------------------+
| 2026-11       |             20 |           938.85 |          18942.28 |                  20.18 |
+---------------+----------------+------------------+-------------------+------------------------+
1 row in set
```

#### Query 22: Window Function DENSE_RANK() by City Revenue
```sql
WITH ChargerRevenue AS (
    SELECT 
        s.city, s.station_name, c.charger_code,
        COALESCE(SUM(p.amount), 0.00) AS total_revenue
    FROM chargers c
    JOIN stations s ON c.station_id = s.station_id
    LEFT JOIN bookings b ON c.charger_id = b.charger_id
    LEFT JOIN charging_sessions cs ON b.booking_id = cs.booking_id
    LEFT JOIN payments p ON cs.session_id = p.session_id AND p.status = 'COMPLETED'
    GROUP BY s.city, s.station_name, c.charger_code
)
SELECT 
    city, station_name, charger_code, total_revenue,
    DENSE_RANK() OVER (PARTITION BY city ORDER BY total_revenue DESC) AS city_revenue_rank
FROM ChargerRevenue
LIMIT 8;
```
**Actual Output:**
```text
+-----------+------------------------------+--------------+---------------+-------------------+
| city      | station_name                 | charger_code | total_revenue | city_revenue_rank |
+-----------+------------------------------+--------------+---------------+-------------------+
| Bengaluru | Indiranagar EcoPower Station | IN-DC-02     |       1428.30 |                 1 |
| Bengaluru | Indiranagar EcoPower Station | IN-DC-01     |       1352.00 |                 2 |
| Bengaluru | Indiranagar EcoPower Station | IN-AC-01     |        969.00 |                 3 |
| Bengaluru | Whitefield TechCharge Hub    | WF-DC-01     |        638.25 |                 4 |
| Bengaluru | Whitefield TechCharge Hub    | WF-AC-01     |          0.00 |                 5 |
| Bengaluru | Whitefield TechCharge Hub    | WF-DC-02     |          0.00 |                 5 |
| Chennai   | Anna Nagar FastPoint         | AN-DC-01     |        676.80 |                 1 |
| Chennai   | Anna Nagar FastPoint         | AN-AC-01     |          0.00 |                 2 |
+-----------+------------------------------+--------------+---------------+-------------------+
```

#### Query 25: EXPLAIN Query Plan for Index Utilization
```sql
EXPLAIN
SELECT booking_id, charger_id, start_time, end_time
FROM bookings
WHERE charger_id = 2 
  AND status IN ('CONFIRMED', 'PENDING')
  AND start_time < '2026-11-01 10:00:00'
  AND '2026-11-01 09:00:00' < end_time;
```
**Actual Output:**
```text
+----+-------------+----------+------------+-------+-------------------------------+------------------------------+---------+------+------+----------+--------------------------+
| id | select_type | table    | partitions | type  | possible_keys                 | key                          | key_len | ref  | rows | filtered | Extra                    |
+----+-------------+----------+------------+-------+-------------------------------+------------------------------+---------+------+------+----------+--------------------------+
|  1 | SIMPLE      | bookings | NULL       | range | idx_bookings_conflict_search  | idx_bookings_conflict_search | 6       | NULL |    4 |    25.00 | Using where; Using index |
+----+-------------+----------+------------+-------+-------------------------------+------------------------------+---------+------+------+----------+--------------------------+
```
*Note:* The query executes with `type: range` and `Extra: Using index` directly on `idx_bookings_conflict_search`, confirming zero table scans and instant conflict detection.

---

### Section 5: Stored Procedure & Business Analytics Execution

#### Query 30: Detailed Bill Calculation via `sp_calculate_bill(1, ...)`
```text
+--------------+-----------------------+----------+----------------------+--------------------+----------------+
| customer     | station               | charger  | energy_consumed_kwh  | rate_snapshot_inr  | total_bill_inr |
+--------------+-----------------------+----------+----------------------+--------------------+----------------+
| Aarav Sharma | Gachibowli FastHub EV | GB-DC-01 |               42.500 |              19.50 |         828.75 |
+--------------+-----------------------+----------+----------------------+--------------------+----------------+
```

#### Query 31: Station Performance & Revenue Report via `sp_station_revenue_report(NULL)`
```text
+------------+------------------------------+-----------+-------------+----------------+----------------+----------------+---------------------+-------------------+
| station_id | station_name                 | city      | state       | total_chargers | total_bookings | total_sessions | total_kwh_delivered | total_revenue_inr |
+------------+------------------------------+-----------+-------------+----------------+----------------+----------------+---------------------+-------------------+
|          1 | Gachibowli FastHub EV        | Hyderabad | Telangana   |              3 |             11 |              6 |             223.200 |           4469.20 |
|          5 | BKC SuperCharge Junction     | Mumbai    | Maharashtra |              3 |             10 |              6 |             246.650 |           3873.98 |
|          3 | Indiranagar EcoPower Station | Bengaluru | Karnataka   |              3 |             11 |              6 |             237.900 |           3749.30 |
|          6 | Kothrud GreenPulse EV        | Pune      | Maharashtra |              3 |              9 |              4 |             184.600 |           2723.20 |
|          8 | Connaught Place PrimeCharge  | New Delhi | Delhi       |              3 |              5 |              2 |              93.700 |           1967.70 |
|          2 | Hitec City CyberCharge       | Hyderabad | Telangana   |              3 |              5 |              3 |              93.300 |            680.80 |
|          7 | Anna Nagar FastPoint         | Chennai   | Tamil Nadu  |              3 |              4 |              1 |              37.600 |            676.80 |
|          4 | Whitefield TechCharge Hub    | Bengaluru | Karnataka   |              3 |              5 |              2 |              50.700 |            638.25 |
+------------+------------------------------+-----------+-------------+----------------+----------------+----------------+---------------------+-------------------+
```
