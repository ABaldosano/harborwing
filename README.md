# HarborWing Air Database

Relational MySQL 8 database replacing HarborWing's spreadsheets.

## Setup (Windows)
```bat
py -m pip install -r requirements.txt
set DB_USER=root
set DB_PASSWORD=yourpassword
py seed.py
```
Then open `queries.sql` in MySQL Workbench (File > Open SQL Script) and run it (lightning bolt).
Mac/Linux: use `pip install -r requirements.txt`, `export DB_USER=root DB_PASSWORD=...`, `python3 seed.py`, `mysql -u root -p < queries.sql`.

**Reset:** run `py seed.py` again. It runs `schema.sql` (which drops the `harborwing` database) and reseeds with the same fixed seed (42), so the output is identical every time.

## Tables
| Table | Purpose |
|---|---|
| booking_agent | Agents who book on behalf of passengers |
| passenger | One row per person, stored once (no repeated info) |
| airport | Airport codes, names, locations (one consistent spelling) |
| calendar_date | One row per date with day of month and business-day flag |
| flight_schedule | Planned flights. Planned times only |
| flight_leg | Operated flight. Holds actual times (NULL until flown) |
| reservation | Booking: main passenger, optional agent, codes, party size |
| payment | A payment with status, date, amount |
| flight_cost | Cost per flight + aircraft + validity period |
| reservation_payment | Link: reservation <-> payment (many-to-many) |
| reservation_leg | Link: reservation <-> leg (many-to-many) |

Codes for airline, aircraft type, reservation status, ticket type, travel class and payment status are **externally managed values**. They have no local reference tables and no foreign keys to them.

## Relationships
- passenger 1 -> * reservation (required); booking_agent 1 -> * reservation (optional)
- flight_schedule 1 -> * flight_leg; airport 1 -> * schedule/leg (origin and destination)
- flight_schedule 1 -> * flight_cost; calendar_date 1 -> * flight_cost (valid_from and valid_to)
- reservation * <-> * payment via reservation_payment
- reservation * <-> * flight_leg via reservation_leg

## Why two linking tables?
A payment can cover several reservations, and a reservation can have several payments. The same goes for reservations and legs. A many-to-many relationship cannot be stored in one column, so a link table holds one row per pair. The composite primary key blocks duplicate pairs.

## Why scheduled and actual times are separate?
The schedule is the plan. The leg is what happened. Keeping them in different tables/columns means actual times never overwrite the plan, and actual times can be NULL until the flight operates.

## Why does flight_cost use a composite key?
(flight_number, aircraft_type_code, valid_from) identifies one cost record. Costs are inserted as new rows with new validity dates instead of updating old ones, so cost history is kept.

## Deletion rules
- reservation -> passenger: RESTRICT (can't delete a passenger who has reservations)
- reservation -> agent: SET NULL (deleting an agent keeps the reservation)
- link tables -> reservation: CASCADE (deleting a reservation removes its links)
- link tables -> payment / leg: RESTRICT; schedule/leg/cost -> airport/schedule/calendar: RESTRICT

## Constraints
Party size > 0, payment amount > 0, cost >= 0, origin <> destination, arrival > departure, valid_to >= valid_from. All tables are InnoDB. All timestamps are UTC.

## Simplifying assumption
Flight number is the unique schedule identifier. A real airline would need more, e.g. flight number + departure date + origin, because the same number (HW101) operates on many dates and can change route or aircraft.

## Advantages and trade-offs
+ No duplicated passenger/airport data, history preserved, constraints enforced by the DB.
- More joins to read one reservation. Link tables need care so joins don't inflate totals (see Q1 in `queries.sql`, which aggregates payments and legs in separate subqueries).

## Limitations
1. Shared payment links don't show how much of a payment belongs to each reservation.
2. Party size is a number, so individual travelers aren't identified.
3. Splitting data reduces duplication but requires joins.
4. Cost validity periods can overlap. The DB doesn't prevent it, so a policy is needed (e.g. the application checks for overlaps before inserting; the seed script generates non-overlapping periods).

## Files
`schema.sql` `seed.py` `queries.sql` `requirements.txt` `harborwing.mwb` + diagram image (create via Workbench, see below).