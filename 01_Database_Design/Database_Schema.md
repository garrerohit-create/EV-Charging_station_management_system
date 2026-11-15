# Relational Database Schema Design
## EV Charging Station Management System

### 1. Schema Overview
The database schema for `ev_charging_management` comprises **6 core relational entities** designed to model the entire operational workflow of an electric vehicle charging network. All tables use the MySQL **InnoDB** storage engine to guarantee full ACID compliance, foreign key enforcement, and crash recovery.

---

### 2. Relational Schema Representation
Textual notation of relations with Primary Keys (underlined) and Foreign Keys:

- **users** (<ins>user_id</ins>, full_name, email, phone, created_at)
  - *Candidate Keys:* {user_id}, {email}
- **stations** (<ins>station_id</ins>, station_name, address, city, state)
  - *Candidate Keys:* {station_id}
- **chargers** (<ins>charger_id</ins>, *station_id*, charger_code, charger_type, power_kw, rate_per_kwh, status)
  - *Candidate Keys:* {charger_id}, {station_id, charger_code}
  - *Foreign Key:* `station_id` references `stations(station_id)` [ON DELETE RESTRICT ON UPDATE CASCADE]
- **bookings** (<ins>booking_id</ins>, *user_id*, *charger_id*, start_time, end_time, status, created_at)
  - *Candidate Keys:* {booking_id}
  - *Foreign Keys:*
    - `user_id` references `users(user_id)` [ON DELETE RESTRICT ON UPDATE CASCADE]
    - `charger_id` references `chargers(charger_id)` [ON DELETE RESTRICT ON UPDATE CASCADE]
- **charging_sessions** (<ins>session_id</ins>, *booking_id*, actual_start, actual_end, energy_kwh, rate_per_kwh, status)
  - *Candidate Keys:* {session_id}, {booking_id}
  - *Foreign Key:* `booking_id` references `bookings(booking_id)` [ON DELETE RESTRICT ON UPDATE CASCADE]
- **payments** (<ins>payment_id</ins>, *session_id*, amount, method, status, paid_at)
  - *Candidate Keys:* {payment_id}, {session_id}
  - *Foreign Key:* `session_id` references `charging_sessions(session_id)` [ON DELETE RESTRICT ON UPDATE CASCADE]

---

### 3. Entity-Relationship Integrity Matrix

| Parent Table | Child Table | Foreign Key Column | Cardinality | Deletion Policy | Business Justification |
|:---|:---|:---|:---:|:---:|:---|
| `stations` | `chargers` | `station_id` | $1 : N$ | RESTRICT | A physical station cannot be deleted while active hardware charging units are registered to it. |
| `users` | `bookings` | `user_id` | $1 : N$ | RESTRICT | A user profile cannot be purged while legal reservation and transactional history references their ID. |
| `chargers` | `bookings` | `charger_id` | $1 : N$ | RESTRICT | Preserves historical reservation scheduling and prevents orphan booking records. |
| `bookings` | `charging_sessions` | `booking_id` | $1 : 0..1$ | RESTRICT | A booking can spawn at most one session. Deletion of booked slot is prohibited once telemetry starts. |
| `charging_sessions` | `payments` | `session_id` | $1 : 0..1$ | RESTRICT | Strict financial auditing prevents deletion of charging telemetry linked to payment settlements. |

---

### 4. Integrity Constraints Summary
1. **CHECK Constraints:**
   - `chargers`: `CHECK (power_kw > 0.00 AND rate_per_kwh >= 0.00)`
   - `bookings`: `CHECK (end_time > start_time)`
   - `charging_sessions`: `CHECK (actual_end IS NULL OR actual_end >= actual_start)`
   - `charging_sessions`: `CHECK (energy_kwh IS NULL OR energy_kwh >= 0.000)`
   - `payments`: `CHECK (amount >= 0.00)`
2. **Uniqueness Rules:**
   - `users.email` is globally unique.
   - `(chargers.station_id, chargers.charger_code)` is unique (e.g., Station 1 can have 'CH-01', but cannot have two 'CH-01's).
   - `charging_sessions.booking_id` is unique (enforcing $1:1$ relationship).
   - `payments.session_id` is unique (enforcing $1:1$ relationship).
