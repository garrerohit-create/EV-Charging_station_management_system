# Database Quality Assurance & Test Plan
## EV Charging Station Management System

### 1. Objective & Scope
The Quality Assurance Plan establishes rigorous validation criteria to verify that `ev_charging_management` adheres to business rules, relational integrity, ACID transactional atomicity, concurrency control, and academic rubric requirements.

### 2. Test Environment
- **DBMS:** MySQL Community Server 8.4.13 LTS
- **Engine:** InnoDB (Strict Mode, Foreign Key Checks Active)
- **Isolation Level:** REPEATABLE READ (Default InnoDB)
- **Database:** `ev_charging_management`

---

### 3. Traceability Matrix & Test Matrix

| Test ID | Test Category | Target Component | Description / Scenario | Expected Outcome |
|:---|:---|:---|:---|:---|
| **TC-01** | Functional (Positive) | `users` | Insert new user with valid email & phone | Row inserted; Auto-increment PK generated |
| **TC-02** | Integrity (Negative) | `users` | Attempt insert with duplicate existing email | Error: Duplicate entry violation (`ER_DUP_ENTRY`) |
| **TC-03** | Integrity (Negative) | `users` | Attempt insert with malformed email | CHECK constraint violation (`chk_user_email_format`) |
| **TC-04** | Referential (Negative)| `chargers` | Insert charger with non-existent `station_id = 999` | Foreign Key failure (`ER_NO_REFERENCED_ROW_2`) |
| **TC-05** | Integrity (Negative) | `chargers` | Insert charger with non-positive power ($0.00\text{ kW}$) | CHECK constraint violation (`chk_charger_power`) |
| **TC-06** | Integrity (Negative) | `bookings` | Insert booking where $end\_time \le start\_time$ | CHECK constraint violation (`chk_booking_time_order`) |
| **TC-07** | Concurrency / Logic | `sp_book_charger_slot` | Book slot on charger under 'MAINTENANCE' | Booking rejected (`CHARGER_UNAVAILABLE`) |
| **TC-08** | Business (Positive) | `sp_book_charger_slot` | Valid booking reservation creation | Transaction committed; Status 'CONFIRMED' |
| **TC-09** | Concurrency / Logic | `sp_book_charger_slot` | Attempt overlapping double-booking on same charger | Transaction rolled back; Rejected (`SLOT_CONFLICT`) |
| **TC-10** | Business (Positive) | `sp_book_charger_slot` | Adjacent slot reservation (touching boundary) | Accepted; Zero interval intersection |
| **TC-11** | Business (Positive) | `sp_start_charging_session` | Start session for confirmed booking | Session created 'IN_PROGRESS'; Rate snapshot locked |
| **TC-12** | Integrity (Negative) | `sp_start_charging_session` | Duplicate session creation for same booking | Rejected (Unique Key on `booking_id`) |
| **TC-13** | Integrity (Negative) | `charging_sessions` | Insert session with negative energy ($-10.5\text{ kWh}$) | CHECK constraint violation (`chk_session_energy`) |
| **TC-14** | Workflow / Billing | `sp_complete_charging_session` | Complete session with $25.000\text{ kWh}$ @ ₹$12.00$ | Calculated bill = ₹$300.00$; Payment generated |
| **TC-15** | Rate Snapshot Test | `chargers` / `charging_sessions` | Modify catalog rate after billing | Session billed amount remains unchanged |
| **TC-16** | Integrity (Negative) | `payments` | Duplicate payment insertion for same session | Rejected (Unique Key on `session_id`) |
| **TC-17** | Workflow / Payment | `sp_process_payment` | Settle payment via UPI | Payment status 'COMPLETED'; Timestamp set |
| **TC-18** | Referential (Negative)| `stations` / `chargers` | Attempt `DELETE FROM stations WHERE station_id = 1` | Deletion blocked by `ON DELETE RESTRICT` |
| **TC-19** | Aggregation / Views | `vw_station_revenue_summary` | Revenue matches sum of completed payments | Mathematical consistency verified |
| **TC-20** | Atomicity / Rollback | `sp_book_charger_slot` | Failure simulation inside procedure | Entire transaction rolled back cleanly |
