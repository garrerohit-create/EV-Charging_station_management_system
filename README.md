# EV Charging Station Management System
## College DBMS Project-Based Learning (PBL) — Academic Year 2026–27 (Semester I)

[![MySQL](https://img.shields.io/badge/MySQL-8.4_LTS-00758F?logo=mysql&logoColor=white)](https://dev.mysql.com/)
[![Engine](https://img.shields.io/badge/Engine-InnoDB-orange.svg)]()
[![Normalization](https://img.shields.io/badge/Normalization-3NF_Verified-success.svg)]()
[![Automated Tests](https://img.shields.io/badge/Tests-20%2F20_Passed_(100%25)-brightgreen.svg)]()

A comprehensive, normalized, transaction-safe Relational Database Management System (RDBMS) engineered on **MySQL Community Server 8.4 LTS**. Designed to simulate the complete operational lifecycle of a commercial Electric Vehicle (EV) charging network across Indian metropolitan hubs.

---

## 1. Project Overview & Key Features

The system models personal and commercial EV charging operations with strict database-level integrity, ACID transaction management, and business intelligence reporting.

### Core Architectural Capabilities:
- **3NF Relational Architecture:** 6 core entities (`users`, `stations`, `chargers`, `bookings`, `charging_sessions`, `payments`) with zero transitive or partial redundancy.
- **Interval Collision Prevention:** Stored procedures use exclusive row locking (`SELECT ... FOR UPDATE`) and interval intersection logic (`existing.start < requested.end AND requested.start < existing.end`) to guarantee zero double-bookings.
- **Automated Rate Snapshotting:** Captures and preserves catalog charging tariffs ($₹/kWh$) at session inception, protecting historical billing records from future price drift.
- **Strict Referential Security:** Enforces `ON DELETE RESTRICT` on historical transactional and financial records to prevent orphan data or cascaded ledger destruction.
- **Pre-Compiled Analytical Views:** Instantaneous access to operational charger status, user histories, financial audit trails, and metro-wise revenue summaries.
- **Automated Test Harness:** Built-in stored procedure (`sp_run_automated_tests`) running 20 rigorous positive, negative, concurrency, and constraint tests with 100% pass rates.

---

## 2. Technology Stack & Prerequisites

- **DBMS:** MySQL Community Server 8.4 LTS (or 8.0+ compatible)
- **Default Database:** `ev_charging_management`
- **Storage Engine:** InnoDB (Strict Mode enabled)
- **Database Client:** MySQL Workbench 8.0+ / MySQL CLI / Antigravity MySQL MCP
- **Operating System:** Windows 10/11 64-bit

---

## 3. Directory Organization

```text
EV_Charging_Station_Management/
│
├── 01_Database_Design/
│   ├── ER_Diagram.png             # High-resolution architectural ER Diagram
│   ├── ER_Diagram.mmd             # Mermaid ER diagram source code
│   ├── Database_Schema.md         # Relational schema & integrity constraint matrix
│   ├── Data_Dictionary.md         # Detailed field specifications and domain rules
│   └── Normalization_Analysis.md  # Formal UNF -> 1NF -> 2NF -> 3NF proof & justification
│
├── 02_SQL_Scripts/
│   ├── 01_create_database.sql     # Database creation and session environment
│   ├── 02_create_tables.sql       # DDL creating 6 core tables with PKs, FKs & Checks
│   ├── 03_constraints_indexes.sql # B-Tree indexes for fast range & conflict lookups
│   ├── 04_triggers.sql            # Automated rate snapshots & timestamp triggers
│   ├── 05_stored_procedures.sql   # ACID booking, session, billing & payment procedures
│   ├── 06_views.sql               # 5 operational and financial reporting views
│   ├── 07_demo_queries.sql        # 32 categorized demonstration SQL queries
│   └── 08_full_project_setup.sql  # Master idempotent installation script
│
├── 03_Sample_Data/
│   ├── 01_seed_data.sql           # Realistic Indian dataset (20 users, 8 stations, 24 chargers, 60 bookings, 30 sessions, 25 payments)
│   └── Sample_Data_Reference.md   # Dataset distribution and entity breakdown
│
├── 04_Query_Results/
│   └── Test_Results.md            # Verified execution outputs of all 32 demo queries
│
├── 05_Project_Report/
│   ├── Abstract.md                # Executive abstract, problem statement & workflow
│   ├── Final_PBL_Report.docx      # Formatted Microsoft Word academic report
│   └── Report_Source.md           # 33-section comprehensive academic project report
│
├── 06_Presentation/
│   ├── Project_Presentation.pptx  # 10-slide academic defense presentation
│   └── Presentation_Script.md     # Slide speaker notes & 15 viva defense questions
│
├── 07_Testing/
│   ├── Test_Plan.md               # QA test strategy and traceability matrix
│   ├── Test_Cases.sql             # Automated test harness procedure (20 tests)
│   └── Test_Summary.md            # Verified QA report with 100% pass evidence
│
├── README.md                      # Project setup, execution & evaluation guide
└── PROJECT_STATUS.md              # Persistent project checklist and verification state
```

---

## 4. Fresh Installation & Setup Guide

### Method 1: One-Step Master Installation (Fastest)

Open Windows PowerShell or Command Prompt, navigate to the project directory, and execute:

```bash
mysql -u root -p < 02_SQL_Scripts/08_full_project_setup.sql
```
*(Enter your MySQL password when prompted)*

This executes DDL, indexes, triggers, stored procedures, views, and populates the sample dataset in exact dependency order in less than 2 seconds.

---

### Method 2: Step-by-Step Modular Execution in MySQL Workbench

Open **MySQL Workbench**, connect to your server, open the SQL Editor (`Ctrl + T`), and execute the scripts sequentially:

1. [01_create_database.sql](file:///c:/Users/garre/OneDrive/Desktop/EV_Charging_Station_Management/02_SQL_Scripts/01_create_database.sql) — Initializes database.
2. [02_create_tables.sql](file:///c:/Users/garre/OneDrive/Desktop/EV_Charging_Station_Management/02_SQL_Scripts/02_create_tables.sql) — Creates the 6 relational tables.
3. [03_constraints_indexes.sql](file:///c:/Users/garre/OneDrive/Desktop/EV_Charging_Station_Management/02_SQL_Scripts/03_constraints_indexes.sql) — Generates B-Tree indexes.
4. [04_triggers.sql](file:///c:/Users/garre/OneDrive/Desktop/EV_Charging_Station_Management/02_SQL_Scripts/04_triggers.sql) — Compiles business integrity triggers.
5. [05_stored_procedures.sql](file:///c:/Users/garre/OneDrive/Desktop/EV_Charging_Station_Management/02_SQL_Scripts/05_stored_procedures.sql) — Deploys workflow stored procedures.
6. [06_views.sql](file:///c:/Users/garre/OneDrive/Desktop/EV_Charging_Station_Management/02_SQL_Scripts/06_views.sql) — Compiles operational views.
7. [01_seed_data.sql](file:///c:/Users/garre/OneDrive/Desktop/EV_Charging_Station_Management/03_Sample_Data/01_seed_data.sql) — Seeds realistic sample records.

---

## 5. Verification & Running the Automated Test Suite

To run the automated 20-scenario test suite, execute in Workbench or CLI:

```sql
USE ev_charging_management;
CALL sp_run_automated_tests();
SELECT test_id, test_name, test_status, actual_result FROM test_execution_log;
```

**Expected Result:** All 20 tests display `PASS`:
- Negative tests verify rejection of duplicate emails, malformed formats, orphan foreign keys, negative power, inverted timestamps, double-bookings, and unauthorized parent deletions.
- Positive tests verify slot bookings, session initialization, rate snapshot preservation, billing calculations, and payment settlements.

---

## 6. How to Run Demonstration Queries

Execute the curated queries from [07_demo_queries.sql](file:///c:/Users/garre/OneDrive/Desktop/EV_Charging_Station_Management/02_SQL_Scripts/07_demo_queries.sql) or run the entire suite from CLI:

```bash
mysql -u root -p ev_charging_management --table < 02_SQL_Scripts/07_demo_queries.sql
```

Covers:
- **Basic CRUD & Filters:** High-speed DC chargers, latest users, active hardware.
- **Relational Joins:** 5-table lifecycle join (Station $\to$ Charger $\to$ Booking $\to$ Session $\to$ Payment).
- **Aggregations:** Energy delivered by charger type, revenue by payment instrument.
- **Advanced SQL:** Monthly revenue Common Table Expressions (CTEs), `DENSE_RANK()` window functions, running totals, `EXPLAIN` range-scan query plans.
- **Stored Procedures:** `sp_calculate_bill` and `sp_station_revenue_report`.

---

## 7. College Evaluation & Viva Demonstration Flow

When demonstrating this project to the examiner:

1. **Schema Structure:** Show [ER_Diagram.png](file:///c:/Users/garre/OneDrive/Desktop/EV_Charging_Station_Management/01_Database_Design/ER_Diagram.png) and explain the 6 entities and 3NF normalization.
2. **Double-Booking Prevention:** Open [05_stored_procedures.sql](file:///c:/Users/garre/OneDrive/Desktop/EV_Charging_Station_Management/02_SQL_Scripts/05_stored_procedures.sql) and show `sp_book_charger_slot` using `SELECT ... FOR UPDATE` and interval collision detection.
3. **Automated QA Evidence:** Run `CALL sp_run_automated_tests();` and show the 20/20 `PASS` score in `test_execution_log`.
4. **Rate Snapshot Proof:** Show that updating a charger's catalog price does NOT change past session rates or billed amounts.
5. **Business Intelligence:** Query `SELECT * FROM vw_station_revenue_summary;` to show real-time station revenue, delivered kWh, and active units.
6. **Viva Answers:** Review [Presentation_Script.md](file:///c:/Users/garre/OneDrive/Desktop/EV_Charging_Station_Management/06_Presentation/Presentation_Script.md#15-anticipated-viva-questions--model-answers) for technical responses to common examiner questions.

---

## 8. Known Limitations

- **Concurrency Scope:** Overlapping slot prevention is enforced at the stored procedure layer; direct out-of-band table writes bypassing procedures require interval triggers.
- **Tariff Modeling:** Uses flat base rates per kWh; does not include time-of-day dynamic surge pricing.
