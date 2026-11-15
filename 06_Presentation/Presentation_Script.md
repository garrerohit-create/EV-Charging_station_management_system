# College PBL Project Presentation Script & Viva Defense Guide
## EV Charging Station Management System

### Slide 1: Project Title & Overview
- **Visuals:** Project Title, Course Code, Student Details, Faculty Mentor, MySQL 8.4 LTS badge.
- **Speaker Script:**
  > "Good morning, respected members of the evaluation committee and my project guide. Today, I am presenting my DBMS Project-Based Learning project titled **'EV Charging Station Management System'**, developed on MySQL Community Server 8.4 LTS. As personal and commercial electric vehicle adoption accelerates across Indian metropolitan cities, managing the underlying charging infrastructure—specifically slot scheduling, telemetry logging, and transparent billing—becomes a critical database engineering problem. This project implements a fully normalized, ACID-compliant relational backend designed to eliminate reservation conflicts and ensure immutable financial audit trails."

---

### Slide 2: Problem Statement & Existing Limitations
- **Visuals:** Comparison table contrasting traditional manual scheduling vs. database-driven management.
- **Speaker Script:**
  > "In existing municipal and uncoordinated commercial setups, EV drivers face three primary bottlenecks: First, unpredictable charger availability and double-booking collisions where two vehicles reserve the same plug for overlapping intervals. Second, price volatility and retrospective billing disputes caused by dynamic tariff drift. Third, severe data redundancy and update anomalies resulting from unnormalized flat files. Our mission was to eliminate these vulnerabilities at the database engine level."

---

### Slide 3: Objectives & Proposed Solution
- **Visuals:** Core pillars: 3NF Relational Architecture, Interval Concurrency Control, Rate Snapshot Preservation, Pre-computed Analytics.
- **Speaker Script:**
  > "Our primary objectives were: 
  > 1. Formulate a 3NF relational schema consisting of six normalized entities.
  > 2. Prevent overlapping reservations through exclusive row locking (`SELECT FOR UPDATE`) and interval collision logic inside stored procedures.
  > 3. Implement an automated rate-snapshot mechanism so that historical charging invoices remain legally protected and tamper-proof regardless of catalog price changes.
  > 4. Deploy comprehensive analytical views, CTEs, and window functions to give operators real-time revenue and utilization metrics."

---

### Slide 4: System Architecture & Operational Workflow
- **Visuals:** Flowchart depicting User Registration $\to$ Station Discovery $\to$ Slot Booking $\to$ Session Telemetry $\to$ Bill Calculation $\to$ Payment Reconciliation.
- **Speaker Script:**
  > "Here we see the operational lifecycle. The driver registers in `users`, browses active hardware via the `vw_active_chargers` view, and initiates a slot booking via `sp_book_charger_slot`. When the driver plugs in their vehicle, `sp_start_charging_session` locks the catalog rate at that exact timestamp. Upon completion, telemetry records total kilowatt-hours delivered, immediately computes the bill with decimal accuracy, and generates a payment invoice in `payments`."

---

### Slide 5: Database Entities & Schema Definition
- **Visuals:** Six entities: `users`, `stations`, `chargers`, `bookings`, `charging_sessions`, `payments`.
- **Speaker Script:**
  > "The schema is strictly partitioned into six core tables. Notice the intentional separation between `stations` and individual `chargers` to support multi-gun charging posts with distinct AC Level 2 and DC Fast capacities. Notice also that `bookings` does not store redundant station IDs because station location is cleanly resolved through its foreign key relationship with `chargers`. Furthermore, all tables utilize InnoDB with `ON DELETE RESTRICT` to protect audit trails from accidental cascaded deletion."

---

### Slide 6: Entity Relationship Diagram & Cardinalities
- **Visuals:** Crows-foot notation diagram illustrating $1:N$ and $1:1$ relationships.
- **Speaker Script:**
  > "This slide illustrates our Entity Relationship architecture:
  > - One Station hosts Many Chargers ($1:N$).
  > - One User places Many Bookings ($1:N$).
  > - One Charger can be reserved across Many non-overlapping Bookings ($1:N$).
  > - One Booking maps to at most One Charging Session ($1:0..1$), enforced by a unique key on `booking_id`.
  > - One Charging Session maps to at most One Payment record ($1:0..1$), enforced by a unique key on `session_id`."

---

### Slide 7: Mathematical Normalization Analysis (1NF, 2NF, 3NF)
- **Visuals:** Step-by-step decomposition from UNF flat log to 3NF relational tables.
- **Speaker Script:**
  > "We rigorously analyzed normalization starting from an unnormalized flat log:
  > - In 1NF, we eliminated repeating groups and enforced atomic column domains.
  > - In 2NF, we eliminated partial functional dependencies such as user details depending only on UserEmail rather than the composite key.
  > - In 3NF, we resolved transitive chains where booking determined session, and session determined payment.
  > A key defense in our viva is that storing `rate_per_kwh` in `charging_sessions` is NOT a normalization defect; it represents a temporal snapshot that preserves contract pricing against future catalog changes."

---

### Slide 8: Advanced SQL Features (Triggers & Stored Procedures)
- **Visuals:** Code snippets of `sp_book_charger_slot` interval logic and `trg_sessions_before_insert`.
- **Speaker Script:**
  > "Rather than relying on application code, critical business rules are enforced inside MySQL:
  > - `sp_book_charger_slot` locks the target charger with `SELECT ... FOR UPDATE` and evaluates the interval collision condition: `existing.start < requested.end AND requested.start < existing.end`. If any confirmed overlap is detected, the transaction rolls back immediately.
  > - Triggers automatically validate that session end times do not precede start times and populate payment settlement timestamps upon transaction completion."

---

### Slide 9: Query Results & Automated Testing Evidence
- **Visuals:** Test execution log (20/20 Passed) and sample analytical query outputs (CTE monthly revenue, DENSE_RANK()).
- **Speaker Script:**
  > "We verified the system empirically. Our automated test harness, `sp_run_automated_tests()`, tested 20 distinct negative and positive scenarios—including duplicate email attempts, invalid foreign keys, negative power capacities, double-booking attempts, and catalog rate changes. All 20 tests passed with 100% compliance. Furthermore, our 32 demonstration queries cover complex relational joins, aggregations, running totals, and query plan execution analyses with `EXPLAIN` showing sub-millisecond range index lookups."

---

### Slide 10: Conclusion & Future Scope
- **Visuals:** Key achievements summary, future IoT / OCPP integration roadmap.
- **Speaker Script:**
  > "In conclusion, the EV Charging Station Management System demonstrates that rigorous relational database design, combined with InnoDB ACID guarantees and stored procedures, can completely eliminate scheduling conflicts and maintain foolproof fiscal integrity. In the future, this backend can be coupled with real-time OCPP hardware protocol sockets and dynamic grid tariff surge pricing algorithms. Thank you, and I am now open to your questions."

---

### 15 ANTICIPATED VIVA QUESTIONS & MODEL ANSWERS

#### Q1: Why did you choose InnoDB over MyISAM?
**Answer:** InnoDB provides full ACID transaction support, foreign key constraint enforcement, row-level locking (`FOR UPDATE`), and crash recovery via write-ahead logging (redo logs). MyISAM only offers table-level locking and lacks foreign key support, making it unsuitable for concurrent booking and financial transactions.

#### Q2: How did you solve the double-booking problem in SQL?
**Answer:** We implemented an interval collision check inside the stored procedure `sp_book_charger_slot`. First, we acquire an exclusive row lock on the charger using `SELECT ... FOR UPDATE` to serialize concurrent requests. Then we evaluate the non-intersection rule:
`existing.start_time < requested.end_time AND requested.start_time < existing.end_time`
If any active booking satisfies this condition, the transaction rolls back with a `SLOT_CONFLICT` status.

#### Q3: Why is `rate_per_kwh` stored in both `chargers` and `charging_sessions`? Doesn't that violate 3NF?
**Answer:** No. It is an intentional temporal snapshot. `chargers.rate_per_kwh` represents the current catalog price, whereas `charging_sessions.rate_per_kwh` represents the historical contracted tariff agreed upon at the time of charging. If the catalog price changes in the future, recalculating past sessions via a dynamic JOIN would retroactively corrupt previous financial invoices.

#### Q4: Why did you use `ON DELETE RESTRICT` instead of `CASCADE` on transactions?
**Answer:** For transactional and financial auditability. In a commercial system, deleting a user account or station should never cascade-delete historical bookings, energy telemetry, or payment settlements. `RESTRICT` prevents deletion of parent records while active transactional children exist.

#### Q5: Can an ordinary MySQL `CHECK` constraint prevent overlapping time intervals?
**Answer:** No. Standard SQL `CHECK` constraints can only evaluate columns within the single row currently being inserted or updated. They cannot query across other rows in the table. Overlapping interval detection requires multi-row querying, which must be enforced via stored procedures with locking or table triggers.

#### Q6: What is the purpose of the composite index `idx_bookings_conflict_search`?
**Answer:** It indexes `(charger_id, status, start_time, end_time)`. When `sp_book_charger_slot` evaluates overlapping bookings, MySQL performs a covering B-Tree range scan on this composite index without reading full table data pages, reducing execution time to under 1 millisecond.

#### Q7: What is the cardinality between `bookings` and `charging_sessions`? How is it enforced?
**Answer:** It is a $1 : 0..1$ relationship. A booking can either have zero sessions (if cancelled or upcoming) or exactly one session. It is enforced in SQL by defining a `UNIQUE` constraint on the foreign key `charging_sessions.booking_id`.

#### Q8: Why did you use `DECIMAL(8,2)` instead of `FLOAT` or `DOUBLE` for currency?
**Answer:** Floating-point numbers (`FLOAT`/`DOUBLE`) use IEEE 754 binary approximations and introduce cumulative rounding errors in financial transactions. `DECIMAL` stores numbers as exact base-10 representations, guaranteeing financial precision down to the exact paisa/cent.

#### Q9: What happens if payment fails? How is the database state updated?
**Answer:** The procedure `sp_process_payment` updates the `payments` record status to `'FAILED'`, leaving `paid_at` as `NULL`. The unpaid invoice remains flagged in `payments` and is surfaced by audit views for customer retry or collection.

#### Q10: How do you find chargers that are operational vs. available?
**Answer:** Operational status (`ACTIVE`, `MAINTENANCE`, `OUT_OF_SERVICE`) is a static hardware state stored in `chargers.status`. Slot availability is a temporal state calculated by checking if any confirmed booking overlaps with a requested time interval. Both are cleanly distinguished in our views.

#### Q11: Explain the purpose of `trg_sessions_after_update`.
**Answer:** When a charging session reaches `'COMPLETED'`, the trigger automatically synchronizes the corresponding parent record in `bookings`, transitioning its status from `'CONFIRMED'` to `'COMPLETED'`.

#### Q12: Why did you use surrogate integer keys (`user_id`, `station_id`) instead of natural keys?
**Answer:** Surrogate integer keys provide compact 4-byte indexes, accelerate foreign key joins, and insulate the database schema from changes in real-world identifiers (such as a user changing their email or phone number).

#### Q13: What does the EXPLAIN query plan show for your conflict search?
**Answer:** The `EXPLAIN` statement proves that the conflict query runs with `type: range` and `Extra: Using index` on `idx_bookings_conflict_search`. This confirms zero full-table scans.

#### Q14: How does your system support both AC and DC fast chargers?
**Answer:** Through the `charger_type` ENUM attribute in `chargers`, accompanied by `power_kw` (ranging from 7.4 kW for Level 2 AC to 150 kW for Ultra-fast DC) and distinct tariff rates (`rate_per_kwh`).

#### Q15: How can a college examiner verify your project?
**Answer:** By running `02_SQL_Scripts/08_full_project_setup.sql`, which sets up all tables, triggers, procedures, views, and seed data in under two seconds, followed by `CALL sp_run_automated_tests();` which displays 20 passed tests in the `test_execution_log` table.
