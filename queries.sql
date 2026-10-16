USE harborwing;

-- ROW COUNTS (every table must be >= 50)
SELECT 'booking_agent' t, COUNT(*) n FROM booking_agent UNION ALL
SELECT 'passenger', COUNT(*) FROM passenger UNION ALL
SELECT 'airport', COUNT(*) FROM airport UNION ALL
SELECT 'calendar_date', COUNT(*) FROM calendar_date UNION ALL
SELECT 'flight_schedule', COUNT(*) FROM flight_schedule UNION ALL
SELECT 'flight_leg', COUNT(*) FROM flight_leg UNION ALL
SELECT 'reservation', COUNT(*) FROM reservation UNION ALL
SELECT 'payment', COUNT(*) FROM payment UNION ALL
SELECT 'flight_cost', COUNT(*) FROM flight_cost UNION ALL
SELECT 'reservation_payment', COUNT(*) FROM reservation_payment UNION ALL
SELECT 'reservation_leg', COUNT(*) FROM reservation_leg;

-- Q1: Reservation + passenger + agent + payments + legs (payments and legs are
-- aggregated in separate subqueries so totals are NOT inflated by the join)
SELECT r.reservation_id, r.status_code, r.party_size,
       CONCAT(p.first_name, ' ', p.last_name) AS passenger,
       a.agent_name,
       COALESCE(pay.payment_count, 0) AS payment_count,
       COALESCE(pay.total_linked_payments, 0) AS total_linked_payments,
       COALESCE(lg.leg_count, 0) AS leg_count,
       lg.flights
FROM reservation r
JOIN passenger p ON p.passenger_id = r.passenger_id
LEFT JOIN booking_agent a ON a.agent_id = r.agent_id
LEFT JOIN (SELECT rp.reservation_id, COUNT(*) AS payment_count, SUM(py.amount) AS total_linked_payments
           FROM reservation_payment rp JOIN payment py ON py.payment_id = rp.payment_id
           GROUP BY rp.reservation_id) pay ON pay.reservation_id = r.reservation_id
LEFT JOIN (SELECT rl.reservation_id, COUNT(*) AS leg_count,
                  GROUP_CONCAT(fl.flight_number ORDER BY fl.leg_id SEPARATOR ', ') AS flights
           FROM reservation_leg rl JOIN flight_leg fl ON fl.leg_id = rl.leg_id
           GROUP BY rl.reservation_id) lg ON lg.reservation_id = r.reservation_id
WHERE r.reservation_id = 1;

-- Q2: Reservations using a particular leg
SELECT r.reservation_id, r.status_code, CONCAT(p.first_name, ' ', p.last_name) AS passenger
FROM reservation_leg rl
JOIN reservation r ON r.reservation_id = rl.reservation_id
JOIN passenger p ON p.passenger_id = r.passenger_id
WHERE rl.leg_id = 1;

-- Q3: Payments linked to a reservation
SELECT py.payment_id, py.payment_status_code, py.payment_date, py.amount
FROM reservation_payment rp
JOIN payment py ON py.payment_id = rp.payment_id
WHERE rp.reservation_id = 1;

-- Q4: Flight cost for flight + aircraft type + date
SELECT flight_number, aircraft_type_code, valid_from, valid_to, cost_amount
FROM flight_cost
WHERE flight_number = 'HW101' AND aircraft_type_code = 'DH8D'
  AND '2026-08-15' BETWEEN valid_from AND valid_to;