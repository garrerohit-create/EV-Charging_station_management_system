# Sample Data Reference & Entity Breakdown
## EV Charging Station Management System

### 1. Dataset Overview
The dataset populated into `ev_charging_management` provides a realistic simulation of commercial EV charging infrastructure in urban India.

| Entity | Record Count | Geographic / Technical Scope |
|:---|:---:|:---|
| **Users** | 20 | Fictional Indian EV owners across metros with verified contact structures. |
| **Stations** | 8 | Major charging hubs in Hyderabad (2), Bengaluru (2), Mumbai (1), Pune (1), Chennai (1), New Delhi (1). |
| **Chargers** | 24 | Balanced mix of AC Type-2 (7.4–22 kW) and DC Fast (50–150 kW); 20 Active, 2 Maintenance, 2 Out-of-Service. |
| **Bookings** | 60 | 30 Historical Completed, 18 Confirmed Upcoming, 8 Cancelled, 4 Pending slot requests. |
| **Charging Sessions** | 30 | 27 Completed sessions with realistic telemetry ($kWh \in [16.2, 62.1]$) and 3 active In-Progress sessions. |
| **Payments** | 25 | 20 Settled (UPI, Card, Cash), 3 Pending, 2 Failed transactions with verified decimal accuracy ($₹$). |

---

### 2. Referential Integrity Verification
- **All Bookings reference valid Users ($user\_id \in [1, 20]$) and Chargers ($charger\_id \in [1, 24]$).**
- **All Sessions reference distinct valid Bookings ($1:1$ mapping for bookings 1–30).**
- **All Payments reference distinct valid Sessions ($1:1$ mapping for sessions 1–25).**
- **No overlapping reservations exist on any charger across identical intervals.**
- **Billed payment amounts strictly equal:**
  $$\text{Amount} = \text{ROUND}(\text{energy\_kwh} \times \text{rate\_per\_kwh}, 2)$$
