# Comprehensive Academic Normalization Analysis
## EV Charging Station Management System

### 1. Introduction to Normalization
Database Normalization is the systematic mathematical technique of decomposing tables to eliminate data redundancy (duplicate information) and undesirable insert, update, and delete anomalies while preserving lossless join capability and functional dependencies.

In this project, normalization is evaluated from an **Unnormalized Form (UNF)** through **1NF**, **2NF**, and **3NF** using a realistic baseline scenario, followed by rigorous mathematical justification of the production six-table schema.

---

### 2. Demonstration via Hypothetical Unnormalized Relation (UNF)
Consider a naive spreadsheet tracking charging station operations where all data is combined into a single flat file.

#### The Unnormalized Entity: `UNF_EV_Log`
```text
UNF_EV_Log (
    UserName, UserEmail, UserPhone,
    StationName, StationAddress, StationCity, StationState,
    ChargersInstalled [Repeating Group: ChargerCode, Type, PowerKW, RatePerKWh],
    BookingsMade [Repeating Group: BookingStart, BookingEnd, BookingStatus],
    SessionStart, SessionEnd, EnergyUsedKWh,
    PaymentAmount, PaymentMethod, PaymentStatus
)
```

**Anomalies Present in UNF:**
1. **Insertion Anomaly:** A new charging station or hardware charger cannot be registered unless a user immediately books it.
2. **Update Anomaly:** If a station's address or a user's phone number changes, hundreds of historical rows must be modified. Incomplete updates lead to data inconsistency.
3. **Deletion Anomaly:** Deleting a user's cancelled booking purges the technical specifications of the charger and station from the system.

---

### 3. Step-by-Step Formal Decomposition

#### Step 1: First Normal Form (1NF) — Atomicity & Elimination of Repeating Groups
* **Definition:** A relation $R$ is in 1NF if and only if all underlying domains contain only atomic (indivisible) values, and there are no repeating groups or multivalued attributes.
* **Transformation:** We flatten repeating groups by introducing a composite primary key.

```text
FLAT_CHARGING_LOG (
    UserEmail, StationName, ChargerCode, BookingStart,
    UserName, UserPhone, StationAddress, StationCity, StationState,
    ChargerType, PowerKW, RatePerKWh, BookingEnd, BookingStatus,
    SessionStart, SessionEnd, EnergyUsedKWh,
    PaymentAmount, PaymentMethod, PaymentStatus
)
```
* **Composite Candidate Key:** `{UserEmail, StationName, ChargerCode, BookingStart}`
* **Condition:** Now in 1NF (all column cells hold single scalar values), but severe partial dependencies exist.

---

#### Step 2: Second Normal Form (2NF) — Elimination of Partial Dependencies
* **Definition:** A relation is in 2NF if it is in 1NF and every non-prime attribute is **fully functionally dependent** on the entire primary key (no attribute depends on a proper subset of a composite candidate key).

**Identified Partial Dependencies in 1NF relation:**
- `{UserEmail} -> {UserName, UserPhone}` (Depends only on user, not charger or time).
- `{StationName} -> {StationAddress, StationCity, StationState}` (Depends only on station).
- `{StationName, ChargerCode} -> {ChargerType, PowerKW, RatePerKWh}` (Depends on charger, not user or booking).

**Decomposition into 2NF Relations:**
1. **User_2NF** (<ins>UserEmail</ins>, UserName, UserPhone)
2. **Station_2NF** (<ins>StationName</ins>, StationAddress, StationCity, StationState)
3. **Charger_2NF** (<ins>StationName, ChargerCode</ins>, ChargerType, PowerKW, RatePerKWh)
4. **Booking_Session_Payment_2NF** (<ins>UserEmail, StationName, ChargerCode, BookingStart</ins>, BookingEnd, BookingStatus, SessionStart, SessionEnd, EnergyUsedKWh, PaymentAmount, PaymentMethod, PaymentStatus)

All partial dependencies are resolved.

---

#### Step 3: Third Normal Form (3NF) — Elimination of Transitive Dependencies
* **Definition:** A relation is in 3NF if it is in 2NF and for every non-trivial functional dependency $X \to Y$, either $X$ is a superkey, or $Y$ is a prime attribute (i.e., no non-prime attribute transitively depends on the primary key through another non-prime attribute: $PK \to A \to B$).

**Identified Transitive Dependencies in `Booking_Session_Payment_2NF`:**
- A booking identifies a charging session: `Booking -> SessionStart, SessionEnd, EnergyUsedKWh`.
- A session uniquely determines payment: `Session -> PaymentAmount, PaymentMethod, PaymentStatus`.
- Transitive chain: `BookingKey -> Session -> Payment`.

**Decomposition into 3NF Relations (introducing surrogate keys for physical storage efficiency):**
1. **users** (<ins>user_id</ins>, full_name, email, phone, created_at)
2. **stations** (<ins>station_id</ins>, station_name, address, city, state)
3. **chargers** (<ins>charger_id</ins>, station_id, charger_code, charger_type, power_kw, rate_per_kwh, status)
4. **bookings** (<ins>booking_id</ins>, user_id, charger_id, start_time, end_time, status, created_at)
5. **charging_sessions** (<ins>session_id</ins>, booking_id, actual_start, actual_end, energy_kwh, rate_per_kwh, status)
6. **payments** (<ins>payment_id</ins>, session_id, amount, method, status, paid_at)

---

### 4. Rigorous Functional Dependency (FD) Analysis of Final Schema

#### Table: `users`
- **Candidate Keys:** `{user_id}`, `{email}`
- **Functional Dependencies:**
  - `user_id -> full_name, email, phone, created_at`
  - `email -> user_id, full_name, phone, created_at`
- **Verdict:** All determinants are candidate keys $\implies$ **3NF & BCNF Satisfied**.

#### Table: `stations`
- **Candidate Keys:** `{station_id}`
- **Functional Dependencies:**
  - `station_id -> station_name, address, city, state`
- **Verdict:** Determinant is the primary key $\implies$ **3NF & BCNF Satisfied**.

#### Table: `chargers`
- **Candidate Keys:** `{charger_id}`, `{station_id, charger_code}`
- **Functional Dependencies:**
  - `charger_id -> station_id, charger_code, charger_type, power_kw, rate_per_kwh, status`
  - `{station_id, charger_code} -> charger_id, charger_type, power_kw, rate_per_kwh, status`
- **Verdict:** All determinants are candidate keys $\implies$ **3NF & BCNF Satisfied**.

#### Table: `bookings`
- **Candidate Keys:** `{booking_id}`
- **Functional Dependencies:**
  - `booking_id -> user_id, charger_id, start_time, end_time, status, created_at`
- **Verdict:** Determinant is the candidate key $\implies$ **3NF & BCNF Satisfied**.

#### Table: `charging_sessions`
- **Candidate Keys:** `{session_id}`, `{booking_id}`
- **Functional Dependencies:**
  - `session_id -> booking_id, actual_start, actual_end, energy_kwh, rate_per_kwh, status`
  - `booking_id -> session_id, actual_start, actual_end, energy_kwh, rate_per_kwh, status`
- **Verdict:** Determinants are candidate keys $\implies$ **3NF & BCNF Satisfied**.

#### Table: `payments`
- **Candidate Keys:** `{payment_id}`, `{session_id}`
- **Functional Dependencies:**
  - `payment_id -> session_id, amount, method, status, paid_at`
  - `session_id -> payment_id, amount, method, status, paid_at`
- **Verdict:** Determinants are candidate keys $\implies$ **3NF & BCNF Satisfied**.

---

### 5. Architectural & Financial Justification of Apparent Redundancies

#### Question 1: Why is `rate_per_kwh` stored in `charging_sessions` when it already exists in `chargers`?
* **Theoretical Concern:** Does storing `rate_per_kwh` in both `chargers` and `charging_sessions` violate 3NF?
* **Architectural Justification (Temporal Snapshot):**
  - In relational database design, **prices change over time**.
  - `chargers.rate_per_kwh` represents the **current catalog price**.
  - `charging_sessions.rate_per_kwh` represents the **immutable historical contract price** agreed upon when the session occurred.
  - If a station owner updates `chargers.rate_per_kwh` from ₹12.00 to ₹18.00 next month, dynamically recalculating historical sessions via a JOIN would retroactively inflate previous customer bills, creating accounting fraud and auditing violations.
  - Therefore, `charging_sessions.rate_per_kwh` is functionally dependent on `session_id` at transaction time, satisfying 3NF.

#### Question 2: Why is `amount` stored in `payments` instead of computing `energy_kwh * rate_per_kwh` on the fly?
* **Theoretical Concern:** Stored calculated values can violate 3NF if they transitively depend on base values.
* **Architectural Justification (Financial Audit Record):**
  - The payment `amount` is a legally binding financial settlement figure communicated to banking rails (UPI, Card).
  - Even if raw telemetry data in `charging_sessions` were recalibrated, subjected to disputes, or rounded, the settled financial transaction ledger must remain tamper-proof and immutable.
  - Furthermore, in enterprise systems, payments may reflect discounts, taxes (GST), or penalties that exist strictly within the financial domain.
  - Thus, storing `payments.amount` as an immutable monetary fact is standard practice in banking and fiscal database architecture.
