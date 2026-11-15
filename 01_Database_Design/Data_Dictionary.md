# Complete Data Dictionary
## EV Charging Station Management System

### Table 1: `users`
Stores registered EV owners and drivers authorized to reserve slots and initiate charging.

| Column Name | Data Type | Nullable | Key | Default | Description & Domain Rules |
|:---|:---|:---:|:---:|:---:|:---|
| `user_id` | INT | NO | PK | Auto Inc | Unique surrogate identifier for registered EV drivers. |
| `full_name` | VARCHAR(100) | NO | | None | Full legal or display name of the driver (1–100 chars). |
| `email` | VARCHAR(120) | NO | UK | None | Unique electronic mail address for account notifications. |
| `phone` | VARCHAR(15) | NO | | None | Contact mobile number (supports E.164 / 10-digit Indian standard). |
| `created_at` | DATETIME | NO | | CURRENT_TIMESTAMP | System timestamp recording user registration time. |

---

### Table 2: `stations`
Physical geographical charging premises hosting one or more physical charging posts.

| Column Name | Data Type | Nullable | Key | Default | Description & Domain Rules |
|:---|:---|:---:|:---:|:---:|:---|
| `station_id` | INT | NO | PK | Auto Inc | Unique identifier for the charging facility. |
| `station_name` | VARCHAR(100) | NO | | None | Commercial name of the station (e.g., 'Gachibowli FastHub'). |
| `address` | VARCHAR(255) | NO | | None | Street address, landmark, or premises location. |
| `city` | VARCHAR(80) | NO | | None | Municipality / City (e.g., 'Hyderabad', 'Bengaluru'). |
| `state` | VARCHAR(80) | NO | | None | State / Province jurisdiction (e.g., 'Telangana', 'Karnataka'). |

---

### Table 3: `chargers`
Hardware charging units/guns installed at stations with specific voltage/power profiles.

| Column Name | Data Type | Nullable | Key | Default | Description & Domain Rules |
|:---|:---|:---:|:---:|:---:|:---|
| `charger_id` | INT | NO | PK | Auto Inc | Unique surrogate identifier for the hardware unit. |
| `station_id` | INT | NO | FK | None | References `stations(station_id)`. |
| `charger_code` | VARCHAR(20) | NO | UK (Composite) | None | Station-local identifier label (e.g., 'CH-01', 'DC-FAST-02'). |
| `charger_type` | ENUM('AC','DC') | NO | | None | Electrical current delivery mechanism: AC (Level 2) or DC Fast. |
| `power_kw` | DECIMAL(6,2) | NO | | None | Peak electrical capacity output in Kilowatts ($kW > 0$). |
| `rate_per_kwh` | DECIMAL(8,2) | NO | | None | Current baseline price per Kilowatt-hour ($₹ \ge 0$). |
| `status` | ENUM | NO | | 'ACTIVE' | Operational status: 'ACTIVE', 'MAINTENANCE', 'OUT_OF_SERVICE'. |

*Constraint:* `UNIQUE (station_id, charger_code)`.

---

### Table 4: `bookings`
Temporal slot reservations scheduled by registered users for specific chargers.

| Column Name | Data Type | Nullable | Key | Default | Description & Domain Rules |
|:---|:---|:---:|:---:|:---:|:---|
| `booking_id` | INT | NO | PK | Auto Inc | Unique identifier for the reservation booking. |
| `user_id` | INT | NO | FK | None | References `users(user_id)`. |
| `charger_id` | INT | NO | FK | None | References `chargers(charger_id)`. |
| `start_time` | DATETIME | NO | | None | Scheduled start timestamp of the reserved charging window. |
| `end_time` | DATETIME | NO | | None | Scheduled conclusion timestamp (`end_time > start_time`). |
| `status` | ENUM | NO | | 'PENDING' | Status: 'PENDING', 'CONFIRMED', 'CANCELLED', 'COMPLETED'. |
| `created_at` | DATETIME | NO | | CURRENT_TIMESTAMP | Audit timestamp when the reservation record was created. |

---

### Table 5: `charging_sessions`
Real-time physical charging events capturing electrical telemetry and session duration.

| Column Name | Data Type | Nullable | Key | Default | Description & Domain Rules |
|:---|:---|:---:|:---:|:---:|:---|
| `session_id` | INT | NO | PK | Auto Inc | Unique surrogate identifier for the charging session. |
| `booking_id` | INT | NO | FK, UK | None | 1-to-1 reference to `bookings(booking_id)`. Unique key. |
| `actual_start` | DATETIME | NO | | None | Precise clock timestamp when power flow initiated. |
| `actual_end` | DATETIME | YES | | NULL | Timestamp when plug was released / session ended. |
| `energy_kwh` | DECIMAL(8,3) | YES | | NULL | Total electric energy transferred in kilowatt-hours ($\ge 0$). |
| `rate_per_kwh` | DECIMAL(8,2) | NO | | None | **Rate Snapshot:** Immutable rate locked at session inception ($₹$). |
| `status` | ENUM | NO | | 'IN_PROGRESS' | Session progression: 'IN_PROGRESS', 'COMPLETED'. |

---

### Table 6: `payments`
Financial billing transactions associated with completed charging sessions.

| Column Name | Data Type | Nullable | Key | Default | Description & Domain Rules |
|:---|:---|:---:|:---:|:---:|:---|
| `payment_id` | INT | NO | PK | Auto Inc | Unique identifier for financial transaction. |
| `session_id` | INT | NO | FK, UK | None | 1-to-1 reference to `charging_sessions(session_id)`. Unique key. |
| `amount` | DECIMAL(10,2) | NO | | None | Computed total billing amount: $\text{energy\_kwh} \times \text{rate\_per\_kwh}$. |
| `method` | ENUM | YES | | NULL | Payment instrument: 'UPI', 'CARD', 'CASH'. |
| `status` | ENUM | NO | | 'PENDING' | Transaction state: 'PENDING', 'COMPLETED', 'FAILED'. |
| `paid_at` | DATETIME | YES | | NULL | Settlement timestamp when transaction reached 'COMPLETED'. |
