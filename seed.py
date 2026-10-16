"""Reset + seed the HarborWing database. Fixed seed = repeatable output.
Usage: DB_USER=root DB_PASSWORD=yourpw python seed.py
"""
import os, random, datetime as dt, string
from faker import Faker
import mysql.connector

SEED = 42
random.seed(SEED)
Faker.seed(SEED)
fake = Faker()

conn = mysql.connector.connect(
    host=os.getenv("DB_HOST", "localhost"),
    user=os.getenv("DB_USER", "root"),
    password=os.getenv("DB_PASSWORD", ""),
)
cur = conn.cursor()

# ---- RESET: run schema.sql (drops and recreates the database) ----
lines = [l for l in open("schema.sql").read().splitlines() if not l.strip().startswith("--")]
for stmt in "\n".join(lines).split(";"):
    if stmt.strip():
        cur.execute(stmt)
cur.execute("USE harborwing")

def insert(table, cols, rows):
    sql = f"INSERT INTO {table} ({','.join(cols)}) VALUES ({','.join(['%s']*len(cols))})"
    cur.executemany(sql, rows)

AIRCRAFT = ["AT72", "DH8D", "E175", "B738", "A320"]   # externally managed codes
RES_STATUS = ["CONF", "PEND", "CANC"]
TICKET = ["ONEWAY", "ROUND"]
CLASS = ["ECO", "PRE", "BUS"]
PAY_STATUS = ["PAID", "PEND", "REFD"]

# ---- 1. parents first ----
# booking agents (50)
insert("booking_agent", ["agent_name", "details"],
       [(fake.company(), fake.catch_phrase()) for _ in range(50)])

# passengers (100)
passengers = []
for _ in range(100):
    passengers.append((
        fake.first_name(),
        fake.first_name() if random.random() < 0.3 else None,
        fake.last_name(),
        fake.phone_number()[:30],
        fake.unique.email(),
        fake.street_address(),
        fake.secondary_address() if random.random() < 0.2 else None,
        fake.city(),
        fake.state(),
        fake.country(),
        None,
    ))
insert("passenger", ["first_name", "second_name", "last_name", "phone", "email", "address_line1",
                     "address_line2", "city", "state_province", "country", "other_details"], passengers)

# airports (50, fictional unique codes)
codes = set()
while len(codes) < 50:
    codes.add("".join(random.choices(string.ascii_uppercase, k=3)))
codes = sorted(codes)
insert("airport", ["airport_code", "name", "location", "other_details"],
       [(c, f"{fake.city()} {random.choice(['Harbor','Island','Coastal','Regional'])} Airport",
         f"{fake.city()}, {fake.country()}", None) for c in codes])

# calendar 2026-2027
d, end, cal = dt.date(2026, 1, 1), dt.date(2027, 12, 31), []
while d <= end:
    cal.append((d, d.day, d.weekday() < 5))
    d += dt.timedelta(days=1)
insert("calendar_date", ["cal_date", "day_of_month", "is_business_day"], cal)

# ---- 2. flight schedules (60) ----
flights = []  # (number, aircraft, origin, dest)
sched_rows = []
for i in range(1, 61):
    num = f"HW{100+i}"
    ac = AIRCRAFT[i % 5]
    o, de = random.sample(codes, 2)
    dep = dt.datetime(2026, 1, 1) + dt.timedelta(days=random.randint(0, 700),
                                                 hours=random.randint(5, 20),
                                                 minutes=random.choice([0, 15, 30, 45]))
    arr = dep + dt.timedelta(minutes=random.randint(45, 240))
    flights.append((num, ac, o, de, dep, arr))
    sched_rows.append((num, "HW", ac, o, de, dep, arr))
insert("flight_schedule", ["flight_number", "airline_code", "aircraft_type_code", "origin_airport",
                           "destination_airport", "scheduled_departure", "scheduled_arrival"], sched_rows)

# ---- 3. flight legs (2 per flight = 120). Some actual times unknown (NULL) ----
leg_rows = []
for (num, ac, o, de, dep, arr) in flights:
    for day in (0, 1):
        if random.random() < 0.7:
            delay = dt.timedelta(minutes=random.randint(-5, 60))
            a_dep = dep + dt.timedelta(days=day) + delay
            a_arr = arr + dt.timedelta(days=day) + delay + dt.timedelta(minutes=random.randint(0, 20))
        else:
            a_dep = a_arr = None
        leg_rows.append((num, o, de, a_dep, a_arr))
insert("flight_leg", ["flight_number", "origin_airport", "destination_airport",
                      "actual_departure", "actual_arrival"], leg_rows)
n_legs = len(leg_rows)

# ---- 4. flight costs: 2 NON-overlapping validity periods per flight (120) ----
cost_rows = []
for (num, ac, *_rest) in flights:
    split = dt.date(2026, 3, 1) + dt.timedelta(days=random.randint(0, 240))
    cost_rows.append((num, ac, dt.date(2026, 1, 1), split - dt.timedelta(days=1), round(random.uniform(80, 600), 2)))
    cost_rows.append((num, ac, split, dt.date(2027, 12, 31), round(random.uniform(80, 600), 2)))
insert("flight_cost", ["flight_number", "aircraft_type_code", "valid_from", "valid_to", "cost_amount"], cost_rows)

# ---- 5. reservations (120): ~40% agent-assisted ----
res_rows = []
for _ in range(120):
    res_rows.append((
        random.randint(1, 100),
        random.randint(1, 50) if random.random() < 0.4 else None,
        random.choice(RES_STATUS), random.choice(TICKET), random.choice(CLASS),
        dt.datetime(2026, 1, 1) + dt.timedelta(days=random.randint(0, 280), minutes=random.randint(0, 1439)),
        random.randint(1, 6),
    ))
insert("reservation", ["passenger_id", "agent_id", "status_code", "ticket_type_code",
                       "travel_class_code", "created_at", "party_size"], res_rows)
n_res = len(res_rows)

# ---- 6. payments (100) ----
pay_rows = [(random.choice(PAY_STATUS),
             dt.date(2026, 1, 1) + dt.timedelta(days=random.randint(0, 280)),
             round(random.uniform(50, 1500), 2)) for _ in range(100)]
insert("payment", ["payment_status_code", "payment_date", "amount"], pay_rows)
n_pay = len(pay_rows)

# ---- 7. link tables (sets prevent duplicate pairs) ----
rp = set()
for pay in range(1, n_pay + 1):
    k = 3 if pay <= 20 else 1            # first 20 payments are SHARED by 3 reservations
    for r in random.sample(range(1, n_res + 1), k):
        rp.add((r, pay))
for r in random.sample(range(1, n_res + 1), 25):   # 25 reservations get extra payments
    for pay in random.sample(range(1, n_pay + 1), 2):
        rp.add((r, pay))
insert("reservation_payment", ["reservation_id", "payment_id"], sorted(rp))

rl = set()
for r in range(1, n_res + 1):
    for leg in random.sample(range(1, n_legs + 1), random.randint(1, 4)):  # 1-4 legs each
        rl.add((r, leg))
insert("reservation_leg", ["reservation_id", "leg_id"], sorted(rl))

conn.commit()

# ---- row counts ----
cur.execute("SHOW TABLES")
for (t,) in cur.fetchall():
    cur.execute(f"SELECT COUNT(*) FROM {t}")
    print(f"{t:22s} {cur.fetchone()[0]}")
conn.close()