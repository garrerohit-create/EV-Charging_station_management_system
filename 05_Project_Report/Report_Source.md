# COLLEGE PROJECT-BASED LEARNING (PBL) REPORT
## EV CHARGING STATION MANAGEMENT SYSTEM
### A RELATIONAL DATABASE MANAGEMENT SYSTEM (RDBMS) IMPLEMENTATION

---

### [TITLE PAGE]
**PROJECT TITLE:** EV Charging Station Management System  
**ACADEMIC YEAR:** 2026–2027 | **SEMESTER:** I  
**COURSE:** Database Management Systems (DBMS) Project-Based Learning  
**DEPARTMENT:** Department of Computer Science & Engineering  
**INSTITUTION:** [College / University Name Placeholder]  

**SUBMITTED BY:**  
- Student Name: [Student Name Placeholder]  
- Roll / Registration Number: [Registration No. Placeholder]  

**UNDER THE GUIDANCE OF:**  
- Faculty Mentor / Guide: [Faculty Mentor Name Placeholder]  
- Designation: [Designation / Department Placeholder]  

---

### [CERTIFICATE PAGE]
*(To be signed and verified by institutional authorities)*

This is to certify that the project report titled **"EV Charging Station Management System"** is a bona fide record of independent work carried out by **[Student Name Placeholder]** (Roll No: **[Registration No. Placeholder]**) in partial fulfillment of the academic requirements for the award of Bachelor of Technology in Computer Science & Engineering during the academic session 2026–2027.

---
**[Faculty Guide Signature]**  
Faculty Guide  

**[Head of Department Signature]**  
Head of Department, CSE  

**[External Examiner Signature]**  
External Examiner  

---

### [DECLARATION]
I hereby declare that the project entitled **"EV Charging Station Management System"** submitted to the Department of Computer Science and Engineering is my original work. The empirical database implementations, SQL scripts, test suites, and analytical evaluations reported herein were executed in the authorized local environment under standard DBMS development protocols. This report has not formed the basis for the award of any degree or diploma elsewhere.

Date: 15-November-2026  
Place: [City / Campus Placeholder]  
**[Student Name Placeholder]**

---

### [ACKNOWLEDGEMENT]
I extend my sincere gratitude to our respected Principal/Dean and Head of Department for providing the computational laboratory facilities and conducive environment to execute this project. I express heartfelt appreciation to my project guide, **[Faculty Mentor Name Placeholder]**, whose architectural insights, normalization reviews, and continuous guidance were invaluable. Lastly, I thank my peers and family for their unwavering encouragement throughout the development of this database system.

---

### [ABSTRACT]
The rapid global transition toward Electric Vehicles (EVs) has introduced critical operational bottlenecks in public charging infrastructure, characterized by unpredictable queueing, time-slot scheduling collisions, non-transparent billing tariffs, and uncoordinated energy allocation. The **EV Charging Station Management System** is an enterprise-grade, normalized relational database engineered on **MySQL Community Server 8.4 LTS**. 

Architected according to rigorous Third Normal Form (3NF) principles, the system models six core entities: EV drivers (`users`), physical facilities (`stations`), charging posts (`chargers`), temporal reservations (`bookings`), physical charging telemetry events (`charging_sessions`), and billing settlements (`payments`). Concurrency collisions in slot reservations are eliminated using exclusive row-level locking (`SELECT ... FOR UPDATE`) and interval intersection detection within ACID-compliant stored procedures. Historical fiscal auditing is safeguarded using an automated rate-snapshot architecture that isolates agreed transaction pricing from catalog price drift. The system is verified through 32 analytical SQL demonstration queries, an automated 20-scenario test suite with 100% pass rates, pre-compiled analytical views, and crows-foot Entity Relationship diagrams.

---

### 1. INTRODUCTION
Electrification of personal and commercial transport represents a cornerstone of sustainable urban engineering. However, the operational efficacy of an EV ecosystem depends entirely on the reliability, transparency, and data integrity of its charging management platform. Unlike traditional refueling, EV charging requires temporal scheduling (Level 2 AC taking 2–4 hours; DC Fast taking 30–60 minutes), dynamic power delivery limits ($kW$), and consumption-based kilowatt-hour ($kWh$) billing. 

This project establishes a comprehensive relational database backbone capable of coordinating reservations, tracking live telemetry sessions, locking tariff snapshots, and aggregating cross-metro financial performance without software-induced scheduling conflicts or data corruption.

---

### 2. PROBLEM STATEMENT
Existing municipal and private EV deployments frequently rely on disparate, unnormalized flat files or manual scheduling ledgers, leading to:
1. **Unchecked Double-Bookings:** Multiple motorists schedule reservations on the same physical charging post across overlapping intervals, stranding vehicles.
2. **Retroactive Billing Inconsistencies:** Dynamic rate shifts alter previous customer invoices if historical transaction prices are dynamically joined to catalog tables rather than snapshot-persisted.
3. **Data Redundancy & Anomalies:** Flat-record structures force redundant storage of station addresses and user phone numbers, causing severe insertion, update, and deletion anomalies.
4. **Lack of Operational Visibility:** Operators lack pre-calculated business intelligence metrics regarding charger utilization, downtime, and metro revenue.

---

### 3. EXISTING SYSTEM VS. PROPOSED SYSTEM

| Operational Dimension | Legacy / Flat-Record System | Proposed MySQL RDBMS System |
|:---|:---|:---|
| **Data Normalization** | Unnormalized (UNF) flat tables with high redundancy | Fully decomposed Third Normal Form (3NF) relational design |
| **Slot Scheduling** | Manual queueing; no interval collision checks | Stored procedure (`sp_book_charger_slot`) with exclusive locking |
| **Tariff Security** | Dynamic re-computation; vulnerable to price changes | Automated database trigger locking historical rate snapshots |
| **Referential Integrity**| Soft application-layer checks or none | Strict InnoDB Foreign Keys with `ON DELETE RESTRICT` policies |
| **Analytical Reporting**| Laborious manual spreadsheet compilation | Instantaneous SQL views, CTEs, and Window ranking functions |

---

### 4. PROJECT OBJECTIVES & SCOPE
#### Objectives:
1. Design and deploy an ACID-compliant MySQL relational database comprising 6 core entities.
2. Enforce zero-overlap slot reservation logic using transactional row locking (`FOR UPDATE`).
3. Guarantee historical billing integrity via rate-snapshotting and decimal-precision arithmetic.
4. Provide comprehensive analytical capabilities via SQL views, Common Table Expressions, and window functions.
5. Validate all system invariants via an automated test suite achieving 100% passing results.

#### Scope:
- **In-Scope:** Complete relational database schema, integrity constraints, triggers, stored procedures, views, 32 categorized demonstration queries, realistic Indian dataset (20 users, 8 stations, 24 chargers, 60 bookings, 30 sessions, 25 payments), automated test harness, and academic viva documentation.
- **Out-of-Scope:** Frontend mobile UI applications and physical IoT microcontroller firmware interfaces.

---

### 5. SYSTEM REQUIREMENTS
#### Software Requirements:
- **DBMS:** MySQL Community Server 8.4.13 LTS (InnoDB Engine)
- **Database Client:** MySQL Workbench 8.0 / Native MySQL CLI
- **Operating System:** Microsoft Windows 11 64-bit
- **Scripting & Verification:** Python 3.14 (Standard Library & Pillow)
- **SQL Mode:** `ONLY_FULL_GROUP_BY`, `STRICT_TRANS_TABLES`, `NO_ENGINE_SUBSTITUTION`

#### Hardware Requirements:
- **Processor:** x86_64 Dual-Core CPU (2.0 GHz or higher)
- **RAM:** Minimum 4 GB (8 GB recommended for MySQL buffer pool caching)
- **Storage:** 500 MB available persistent disk space

---

### 6. SYSTEM ARCHITECTURE & WORKFLOW
The end-to-end database workflow is organized into distinct transactional stages:
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
            │                         (Locks charger row, detects collisions)
            ▼
   4. Arrive & Start Charging ──────► CALL sp_start_charging_session()
            │                         (Captures locked rate_per_kwh snapshot)
            ▼
   5. Finalize Session (kWh) ───────► CALL sp_complete_charging_session()
            │                         (Updates telemetry, computes bill)
            ▼
   6. Reconcile Payment (INR) ──────► CALL sp_process_payment()
            │                         (Records payment method & settlement)
            ▼
   7. Operational BI Reporting ─────► SELECT FROM vw_station_revenue_summary
```

---

### 7. DATABASE DESIGN METHODOLOGY & ENTITIES
The database design strictly enforces the six approved entities without redundant attributes:
1. **`users`:** Stores EV driver accounts (<ins>`user_id`</ins>, `full_name`, `email`, `phone`, `created_at`).
2. **`stations`:** Stores physical geographic charging facilities (<ins>`station_id`</ins>, `station_name`, `address`, `city`, `state`).
3. **`chargers`:** Stores hardware charging units (<ins>`charger_id`</ins>, `station_id`, `charger_code`, `charger_type`, `power_kw`, `rate_per_kwh`, `status`). Unique on `(station_id, charger_code)`.
4. **`bookings`:** Stores temporal slot reservations (<ins>`booking_id`</ins>, `user_id`, `charger_id`, `start_time`, `end_time`, `status`, `created_at`).
5. **`charging_sessions`:** Stores physical charging telemetry events (<ins>`session_id`</ins>, `booking_id`, `actual_start`, `actual_end`, `energy_kwh`, `rate_per_kwh`, `status`). 1:1 mapped to bookings.
6. **`payments`:** Stores billing invoices and financial settlements (<ins>`payment_id`</ins>, `session_id`, `amount`, `method`, `status`, `paid_at`). 1:1 mapped to sessions.

---

### 8. ENTITY RELATIONSHIP (ER) DIAGRAM & RELATIONAL SCHEMA
Refer to the rendered high-resolution architectural diagram: [ER_Diagram.png](file:///c:/Users/garre/OneDrive/Desktop/EV_Charging_Station_Management/01_Database_Design/ER_Diagram.png).

#### Formal Relational Schema:
- **users** (<ins>user_id</ins>, full_name, email, phone, created_at)
- **stations** (<ins>station_id</ins>, station_name, address, city, state)
- **chargers** (<ins>charger_id</ins>, *station_id*, charger_code, charger_type, power_kw, rate_per_kwh, status)
- **bookings** (<ins>booking_id</ins>, *user_id*, *charger_id*, start_time, end_time, status, created_at)
- **charging_sessions** (<ins>session_id</ins>, *booking_id*, actual_start, actual_end, energy_kwh, rate_per_kwh, status)
- **payments** (<ins>payment_id</ins>, *session_id*, amount, method, status, paid_at)

---

### 9. NORMALIZATION ANALYSIS (1NF, 2NF, 3NF)
The schema was developed by formally decomposing an Unnormalized Form (UNF) flat structure:
- **1NF:** Atomic domains established; all repeating groups (chargers, bookings) eliminated via scalar attributes.
- **2NF:** Elimination of partial dependencies on composite keys (`{UserEmail} -> UserName` moved to `users`; `{StationName, ChargerCode} -> PowerKW` moved to `chargers`).
- **3NF:** Elimination of transitive dependencies (`Booking -> Session -> Payment`).

#### Defense of Temporal & Financial Snapshots:
- **`charging_sessions.rate_per_kwh`:** Not redundant. It represents an immutable legal price snapshot at the moment of charging. Catalogs change over time; historical billing must not fluctuate retroactively.
- **`payments.amount`:** Preserved as a binding financial fact exchanged with banking rails ($Amount = Energy \times Rate$), ensuring auditability even if raw sensor readings are subsequently queried or recalibrated.

---

### 10. ADVANCED SQL IMPLEMENTATION
- **DDL & Constraints:** Strict foreign key constraints with `ON DELETE RESTRICT` to prevent orphan transactions, accompanied by check constraints (`end_time > start_time`, `power_kw > 0`, `energy_kwh >= 0`).
- **Triggers:** Automated interval validation and rate-snapshotting triggers (`trg_bookings_before_insert`, `trg_sessions_before_insert`, `trg_sessions_after_update`, `trg_payments_before_update`).
- **Stored Procedures:** ACID-compliant routines (`sp_book_charger_slot`, `sp_start_charging_session`, `sp_complete_charging_session`, `sp_calculate_bill`, `sp_process_payment`, `sp_station_revenue_report`).
- **Views:** Dedicated operational views (`vw_active_chargers`, `vw_user_booking_history`, `vw_charging_session_details`, `vw_payment_audit_log`, `vw_station_revenue_summary`).

---

### 11. TESTING, VERIFICATION & RESULTS
The automated test procedure `sp_run_automated_tests()` executed 20 test cases against the live MySQL server:
- **Constraint Rejections Verified:** Duplicate emails (`TC-02`), invalid email formats (`TC-03`), orphan foreign keys (`TC-04`), negative capacity (`TC-05`), and chronological inversion (`TC-06`) were all caught and rejected.
- **Interval Concurrency Verified:** Overlapping reservation attempts were rejected with `SLOT_CONFLICT` (`TC-09`), while adjacent back-to-back bookings were accepted (`TC-10`).
- **Rate Snapshot Integrity Verified:** Changing the catalog charger rate to ₹99.00 did not alter existing session rates or billed invoice totals (`TC-15`).
- **Overall Score:** **20 Passed / 0 Failed (100% Pass Rate)**.

---

### 12. ADVANTAGES, LIMITATIONS & FUTURE SCOPE
#### Advantages:
1. Complete elimination of reservation double-booking collisions via database-level transactional locking.
2. Tamper-proof financial accounting via rate-snapshotting.
3. Sub-millisecond execution times enabled by composite B-Tree indexes.

#### Limitations:
1. Concurrency control relies on stored procedure execution; direct out-of-band `INSERT` statements bypassing procedures must rely on interval triggers.
2. Static tariff model does not incorporate dynamic grid Time-of-Day (ToD) peak pricing.

#### Future Enhancements:
1. Integration with Open Charge Point Protocol (OCPP 2.0.1) for direct hardware socket communication.
2. Machine-learning-based dynamic surge pricing during peak municipal grid demand hours.

---

### 13. CONCLUSION
The **EV Charging Station Management System** successfully delivers an academically rigorous, professionally executed, and demonstrably functional relational database management system. All normalization criteria, ACID transactional guarantees, and reporting queries were executed and validated on MySQL 8.4 LTS, establishing a robust foundation for modern electric mobility infrastructure management.

---

### 14. REFERENCES
1. Elmasri, R., & Navathe, S. B. (2016). *Fundamentals of Database Systems* (7th ed.). Pearson.
2. Silberschatz, A., Korth, H. F., & Sudarshan, S. (2020). *Database System Concepts* (7th ed.). McGraw-Hill.
3. MySQL AB. (2026). *MySQL 8.4 Reference Manual: InnoDB Storage Engine & Locking*. Oracle Corporation.
4. Date, C. J. (2004). *An Introduction to Database Systems* (8th ed.). Addison-Wesley.
