# Project Abstract & System Requirements
## EV Charging Station Management System

### 1. Abstract
The rapid global transition toward Electric Vehicles (EVs) has introduced critical operational challenges in infrastructure management, specifically charging station congestion, slot scheduling conflicts, uncoordinated power delivery, and non-transparent tariff calculation. The **EV Charging Station Management System** is a robust, normalized Relational Database Management System (RDBMS) engineered on MySQL Community Server 8.4 LTS. Designed for high transaction integrity and operational concurrency, the system captures the end-to-end operational lifecycle: EV owner registration, geospatial charging station tracking, charger capability cataloging (AC Slow vs. DC Fast), time-slot booking reservation, telemetry session monitoring, kilowatt-hour electricity billing, and financial payment reconciliation.

By enforcing strict database-level constraints, ACID-compliant stored procedures, automated state triggers, and business intelligence views, this project eliminates double-booking conflicts, protects historical billing records via rate-snapshotting, and provides instantaneous station utilization analytics.

---

### 2. Problem Statement
Existing municipal and commercial EV charging deployments frequently suffer from:
1. **Unpredictable Charger Availability:** Drivers arrive at stations only to find chargers occupied, out of service, or mismatched in connector/power ratings.
2. **Scheduling Conflicts & Overbooking:** Poor slot reservation logic permits overlapping time intervals, stranding motorists and degrading station reputation.
3. **Billing Volatility & Discrepancies:** Dynamic tariff shifts lead to retroactive billing disputes if charging rates are not locked at transaction inception.
4. **Data Silos & Weak Integrity:** Fragmented storage prevents station operators from evaluating charger efficiency, peak revenue hours, and regional charging demand.

---

### 3. Existing System vs. Proposed System

| Metric / Feature | Existing System (Manual / Legacy) | Proposed MySQL RDBMS |
|:---|:---|:---|
| **Booking Architecture** | Manual queue or first-come first-served queueing | Transactional pre-booking with overlapping slot prevention |
| **Data Integrity** | Spreadsheets / isolated flat files with duplicate records | 3NF normalized schema with strict Foreign Key & CHECK constraints |
| **Tariff Locking** | Variable rates computed at checkout, risking price drift | Immutable historical rate snapshot captured in session records |
| **Charger State Management** | Infrequent manual status log | Trigger-assisted and procedure-enforced status validation |
| **Audit & Reporting** | Time-consuming manual aggregation | Pre-compiled SQL views, CTEs, and analytical aggregation queries |

---

### 4. Objectives & Scope
#### Objectives:
- Implement a relational database adhering to 3NF standards with 6 core entities.
- Guarantee zero double-bookings using ACID transactions with exclusive row locking (`FOR UPDATE`) and interval overlap detection.
- Maintain immutable audit trails for electricity consumed ($kWh$) and financial collections ($INR$).
- Deliver actionable operational analytics through SQL views (revenue per station, charger utilization, user booking frequencies).

#### Scope:
- **In-Scope:** Database modeling, DDL schema, referential integrity constraints, automated stored procedures, validation triggers, analytical views, realistic Indian sample dataset, comprehensive test suite, academic documentation, and PowerPoint presentation.
- **Out-of-Scope:** Physical IoT hardware telemetry integration, live payment gateway integration (simulated via ENUM status), mobile front-end application development.

---

### 5. Functional & Non-Functional Requirements
#### Functional Requirements (FR):
- **FR1 (User Management):** Secure registration with unique email and valid phone format.
- **FR2 (Station & Charger Catalog):** Categorization of stations by city/state, and chargers by power output ($kW$), connector type, and operational status.
- **FR3 (Conflict-Free Booking):** Verification that requested time range $[t_{start}, t_{end})$ does not intersect any confirmed booking for the target charger.
- **FR4 (Session Tracking):** Activation of session linked 1-to-1 with a confirmed booking, capturing start time, end time, and final meter reading ($kWh$).
- **FR5 (Tariff Enforcement):** Calculation of bill as $\text{Energy } (kWh) \times \text{Rate } (₹/kWh)$, persisted with decimal precision.
- **FR6 (Payment Reconciliation):** Tracking payment method (UPI, CARD, CASH) and status transitions (PENDING $\to$ COMPLETED / FAILED).

#### Non-Functional Requirements (NFR):
- **NFR1 (Data Integrity):** Strict referential integrity; foreign key deletion behavior default to `RESTRICT` on financial and transactional tables.
- **NFR2 (ACID Compliance):** InnoDB engine utilized across all tables for complete multi-statement transactional atomicity.
- **NFR3 (Performance):** B-Tree indexes on search keys, foreign keys, and temporal ranges to guarantee sub-millisecond query evaluation.
- **NFR4 (Accuracy):** Use of `DECIMAL(8,2)` and `DECIMAL(8,3)` to prevent floating-point rounding errors in currency and meter telemetry.

---

### 6. System Workflow Diagram

```text
       [EV Driver]
            │
            ▼
    1. Register User ───────────────► INSERT INTO users
            │
            ▼
   2. Search Stations & Chargers ───► SELECT FROM vw_active_chargers
            │
            ▼
   3. Request Time Slot Booking ────► CALL sp_book_charger_slot()
            │                         (Locks charger, verifies interval)
            ▼
   4. Arrive & Start Charging ──────► CALL sp_start_charging_session()
            │                         (Captures locked rate_per_kwh)
            ▼
   5. Finalize Session (kWh) ───────► CALL sp_complete_charging_session()
            │                         (Records actual energy consumed)
            ▼
   6. Generate Billing & Payment ───► CALL sp_process_payment()
            │                         (Computes Amount = kWh * Rate)
            ▼
   7. Operational & Viva Analytics ─► SELECT FROM vw_station_revenue_summary
```
