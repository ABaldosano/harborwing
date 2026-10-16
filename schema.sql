-- HarborWing Air schema (MySQL 8.0.16+). Running this file RESETS the database.
DROP DATABASE IF EXISTS harborwing;
CREATE DATABASE harborwing CHARACTER SET utf8mb4;
USE harborwing;

-- All DATETIME columns are stored in UTC.
-- Codes for airline, aircraft type, status, ticket type, travel class are EXTERNALLY MANAGED
-- values. No local reference tables, so no foreign keys to them.

CREATE TABLE booking_agent (
  agent_id INT AUTO_INCREMENT PRIMARY KEY,
  agent_name VARCHAR(100) NOT NULL,
  details TEXT NULL
) ENGINE=InnoDB;

CREATE TABLE passenger (
  passenger_id INT AUTO_INCREMENT PRIMARY KEY,
  first_name VARCHAR(50) NOT NULL,
  second_name VARCHAR(50) NULL,
  last_name VARCHAR(50) NOT NULL,
  phone VARCHAR(30) NOT NULL,
  email VARCHAR(120) NOT NULL,
  address_line1 VARCHAR(120) NOT NULL,
  address_line2 VARCHAR(120) NULL,
  city VARCHAR(80) NOT NULL,
  state_province VARCHAR(80) NULL,
  country VARCHAR(80) NOT NULL,
  other_details TEXT NULL,
  UNIQUE KEY uq_passenger_email (email),
  KEY idx_passenger_last_name (last_name)
) ENGINE=InnoDB;

CREATE TABLE airport (
  airport_code CHAR(3) PRIMARY KEY,
  name VARCHAR(120) NOT NULL,
  location VARCHAR(120) NOT NULL,
  other_details TEXT NULL
) ENGINE=InnoDB;

CREATE TABLE calendar_date (
  cal_date DATE PRIMARY KEY,
  day_of_month TINYINT UNSIGNED NOT NULL,
  is_business_day BOOLEAN NOT NULL
) ENGINE=InnoDB;

CREATE TABLE flight_schedule (
  flight_number VARCHAR(10) PRIMARY KEY,
  airline_code CHAR(2) NOT NULL,
  aircraft_type_code VARCHAR(10) NOT NULL,
  origin_airport CHAR(3) NOT NULL,
  destination_airport CHAR(3) NOT NULL,
  scheduled_departure DATETIME NOT NULL,
  scheduled_arrival DATETIME NOT NULL,
  CONSTRAINT fk_sched_origin FOREIGN KEY (origin_airport) REFERENCES airport(airport_code) ON DELETE RESTRICT,
  CONSTRAINT fk_sched_dest FOREIGN KEY (destination_airport) REFERENCES airport(airport_code) ON DELETE RESTRICT,
  CONSTRAINT chk_sched_airports CHECK (origin_airport <> destination_airport),
  CONSTRAINT chk_sched_times CHECK (scheduled_arrival > scheduled_departure),
  KEY idx_sched_departure (scheduled_departure),
  KEY idx_sched_route (origin_airport, destination_airport)
) ENGINE=InnoDB;

CREATE TABLE flight_leg (
  leg_id INT AUTO_INCREMENT PRIMARY KEY,
  flight_number VARCHAR(10) NOT NULL,
  origin_airport CHAR(3) NOT NULL,
  destination_airport CHAR(3) NOT NULL,
  actual_departure DATETIME NULL,
  actual_arrival DATETIME NULL,
  CONSTRAINT fk_leg_flight FOREIGN KEY (flight_number) REFERENCES flight_schedule(flight_number) ON DELETE RESTRICT,
  CONSTRAINT fk_leg_origin FOREIGN KEY (origin_airport) REFERENCES airport(airport_code) ON DELETE RESTRICT,
  CONSTRAINT fk_leg_dest FOREIGN KEY (destination_airport) REFERENCES airport(airport_code) ON DELETE RESTRICT,
  CONSTRAINT chk_leg_airports CHECK (origin_airport <> destination_airport),
  CONSTRAINT chk_leg_times CHECK (actual_arrival IS NULL OR actual_departure IS NULL OR actual_arrival > actual_departure)
) ENGINE=InnoDB;

CREATE TABLE reservation (
  reservation_id INT AUTO_INCREMENT PRIMARY KEY,
  passenger_id INT NOT NULL,
  agent_id INT NULL,
  status_code VARCHAR(10) NOT NULL,
  ticket_type_code VARCHAR(10) NOT NULL,
  travel_class_code VARCHAR(10) NOT NULL,
  created_at DATETIME NOT NULL,
  party_size SMALLINT UNSIGNED NOT NULL,
  CONSTRAINT fk_res_passenger FOREIGN KEY (passenger_id) REFERENCES passenger(passenger_id) ON DELETE RESTRICT,
  CONSTRAINT fk_res_agent FOREIGN KEY (agent_id) REFERENCES booking_agent(agent_id) ON DELETE SET NULL,
  CONSTRAINT chk_party_size CHECK (party_size > 0),
  KEY idx_res_status (status_code),
  KEY idx_res_created (created_at)
) ENGINE=InnoDB;

CREATE TABLE payment (
  payment_id INT AUTO_INCREMENT PRIMARY KEY,
  payment_status_code VARCHAR(10) NOT NULL,
  payment_date DATE NOT NULL,
  amount DECIMAL(10,2) NOT NULL,
  CONSTRAINT chk_payment_amount CHECK (amount > 0),
  KEY idx_payment_date (payment_date)
) ENGINE=InnoDB;

CREATE TABLE flight_cost (
  flight_number VARCHAR(10) NOT NULL,
  aircraft_type_code VARCHAR(10) NOT NULL,
  valid_from DATE NOT NULL,
  valid_to DATE NOT NULL,
  cost_amount DECIMAL(10,2) NOT NULL,
  PRIMARY KEY (flight_number, aircraft_type_code, valid_from),
  CONSTRAINT fk_cost_flight FOREIGN KEY (flight_number) REFERENCES flight_schedule(flight_number) ON DELETE RESTRICT,
  CONSTRAINT fk_cost_from FOREIGN KEY (valid_from) REFERENCES calendar_date(cal_date) ON DELETE RESTRICT,
  CONSTRAINT fk_cost_to FOREIGN KEY (valid_to) REFERENCES calendar_date(cal_date) ON DELETE RESTRICT,
  CONSTRAINT chk_cost_dates CHECK (valid_to >= valid_from),
  CONSTRAINT chk_cost_amount CHECK (cost_amount >= 0)
) ENGINE=InnoDB;

CREATE TABLE reservation_payment (
  reservation_id INT NOT NULL,
  payment_id INT NOT NULL,
  PRIMARY KEY (reservation_id, payment_id),
  CONSTRAINT fk_rp_res FOREIGN KEY (reservation_id) REFERENCES reservation(reservation_id) ON DELETE CASCADE,
  CONSTRAINT fk_rp_pay FOREIGN KEY (payment_id) REFERENCES payment(payment_id) ON DELETE RESTRICT,
  KEY idx_rp_payment (payment_id)
) ENGINE=InnoDB;

CREATE TABLE reservation_leg (
  reservation_id INT NOT NULL,
  leg_id INT NOT NULL,
  PRIMARY KEY (reservation_id, leg_id),
  CONSTRAINT fk_rl_res FOREIGN KEY (reservation_id) REFERENCES reservation(reservation_id) ON DELETE CASCADE,
  CONSTRAINT fk_rl_leg FOREIGN KEY (leg_id) REFERENCES flight_leg(leg_id) ON DELETE RESTRICT,
  KEY idx_rl_leg (leg_id)
) ENGINE=InnoDB;