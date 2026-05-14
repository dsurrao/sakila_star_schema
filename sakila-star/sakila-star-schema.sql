-- Sakila Star Schema
-- Optimized for OLAP queries and analytical reporting
-- Version 1.0

SET NAMES utf8mb4;
SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0;
SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0;
SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='TRADITIONAL';

DROP SCHEMA IF EXISTS sakila_star;
CREATE SCHEMA sakila_star;
USE sakila_star;

-- ============================================================================
-- DIMENSION TABLES
-- ============================================================================

--
-- Dimension Table: dim_date
-- Contains date attributes for temporal analysis
--

CREATE TABLE dim_date (
  date_id INT NOT NULL,
  full_date DATE NOT NULL,
  date_day TINYINT UNSIGNED NOT NULL,
  date_month TINYINT UNSIGNED NOT NULL,
  date_quarter TINYINT UNSIGNED NOT NULL,
  date_year SMALLINT UNSIGNED NOT NULL,
  day_name VARCHAR(10) NOT NULL,
  month_name VARCHAR(10) NOT NULL,
  is_weekend BOOLEAN DEFAULT FALSE,
  PRIMARY KEY (date_id),
  UNIQUE KEY unique_date (full_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

--
-- Dimension Table: dim_customer
-- Denormalized customer information with location details
--

CREATE TABLE dim_customer (
  customer_key INT NOT NULL AUTO_INCREMENT,
  customer_id SMALLINT UNSIGNED NOT NULL,
  first_name VARCHAR(45) NOT NULL,
  last_name VARCHAR(45) NOT NULL,
  email VARCHAR(50),
  customer_status VARCHAR(10) DEFAULT 'active',
  address VARCHAR(50),
  city VARCHAR(50),
  postal_code VARCHAR(10),
  country VARCHAR(50),
  store_id TINYINT UNSIGNED,
  date_created DATETIME,
  PRIMARY KEY (customer_key),
  UNIQUE KEY unique_customer_id (customer_id),
  KEY idx_city_country (city, country),
  KEY idx_status (customer_status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

--
-- Dimension Table: dim_film
-- Denormalized film information with category and actor details
--

CREATE TABLE dim_film (
  film_key INT NOT NULL AUTO_INCREMENT,
  film_id SMALLINT UNSIGNED NOT NULL,
  title VARCHAR(128) NOT NULL,
  description TEXT,
  release_year YEAR,
  language VARCHAR(20),
  rating VARCHAR(5),
  length SMALLINT UNSIGNED,
  rental_duration TINYINT UNSIGNED,
  rental_rate DECIMAL(4,2),
  replacement_cost DECIMAL(5,2),
  category VARCHAR(25),
  PRIMARY KEY (film_key),
  UNIQUE KEY unique_film_id (film_id),
  KEY idx_title (title),
  KEY idx_release_year (release_year),
  KEY idx_category (category),
  KEY idx_rating (rating)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

--
-- Dimension Table: dim_actor
-- Actor information
--

CREATE TABLE dim_actor (
  actor_key INT NOT NULL AUTO_INCREMENT,
  actor_id SMALLINT UNSIGNED NOT NULL,
  first_name VARCHAR(45) NOT NULL,
  last_name VARCHAR(45) NOT NULL,
  PRIMARY KEY (actor_key),
  UNIQUE KEY unique_actor_id (actor_id),
  KEY idx_actor_name (last_name, first_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

--
-- Dimension Table: dim_store
-- Store information with location and manager details
--

CREATE TABLE dim_store (
  store_key INT NOT NULL AUTO_INCREMENT,
  store_id TINYINT UNSIGNED NOT NULL,
  address VARCHAR(50),
  city VARCHAR(50),
  country VARCHAR(50),
  manager_name VARCHAR(91),
  PRIMARY KEY (store_key),
  UNIQUE KEY unique_store_id (store_id),
  KEY idx_location (city, country)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

--
-- Dimension Table: dim_category
-- Film category information
--

CREATE TABLE dim_category (
  category_key INT NOT NULL AUTO_INCREMENT,
  category_id TINYINT UNSIGNED NOT NULL,
  category_name VARCHAR(25) NOT NULL,
  PRIMARY KEY (category_key),
  UNIQUE KEY unique_category_id (category_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================================
-- FACT TABLES
-- ============================================================================

--
-- Fact Table: fact_rental
-- Core fact table tracking rental transactions
--

CREATE TABLE fact_rental (
  rental_key INT NOT NULL AUTO_INCREMENT,
  rental_id INT NOT NULL,
  rental_date_id INT NOT NULL,
  return_date_id INT,
  customer_key INT NOT NULL,
  film_key INT NOT NULL,
  store_key INT NOT NULL,
  days_rented SMALLINT,
  rental_rate DECIMAL(4,2),
  PRIMARY KEY (rental_key),
  UNIQUE KEY unique_rental_id (rental_id),
  KEY idx_rental_date (rental_date_id),
  KEY idx_return_date (return_date_id),
  KEY idx_customer (customer_key),
  KEY idx_film (film_key),
  KEY idx_store (store_key),
  CONSTRAINT fk_rental_customer FOREIGN KEY (customer_key) REFERENCES dim_customer (customer_key),
  CONSTRAINT fk_rental_film FOREIGN KEY (film_key) REFERENCES dim_film (film_key),
  CONSTRAINT fk_rental_store FOREIGN KEY (store_key) REFERENCES dim_store (store_key),
  CONSTRAINT fk_rental_rental_date FOREIGN KEY (rental_date_id) REFERENCES dim_date (date_id),
  CONSTRAINT fk_rental_return_date FOREIGN KEY (return_date_id) REFERENCES dim_date (date_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

--
-- Fact Table: fact_payment
-- Core fact table tracking payment transactions
--

CREATE TABLE fact_payment (
  payment_key INT NOT NULL AUTO_INCREMENT,
  payment_id SMALLINT UNSIGNED NOT NULL,
  payment_date_id INT NOT NULL,
  customer_key INT NOT NULL,
  rental_key INT,
  amount DECIMAL(5,2) NOT NULL,
  PRIMARY KEY (payment_key),
  UNIQUE KEY unique_payment_id (payment_id),
  KEY idx_payment_date (payment_date_id),
  KEY idx_customer (customer_key),
  KEY idx_rental (rental_key),
  KEY idx_amount (amount),
  CONSTRAINT fk_payment_customer FOREIGN KEY (customer_key) REFERENCES dim_customer (customer_key),
  CONSTRAINT fk_payment_date FOREIGN KEY (payment_date_id) REFERENCES dim_date (date_id),
  CONSTRAINT fk_payment_rental FOREIGN KEY (rental_key) REFERENCES fact_rental (rental_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

--
-- Fact Table: fact_film_actor
-- Association fact table for film-actor relationships
--

CREATE TABLE fact_film_actor (
  film_key INT NOT NULL,
  actor_key INT NOT NULL,
  PRIMARY KEY (film_key, actor_key),
  CONSTRAINT fk_film_actor_film FOREIGN KEY (film_key) REFERENCES dim_film (film_key),
  CONSTRAINT fk_film_actor_actor FOREIGN KEY (actor_key) REFERENCES dim_actor (actor_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

--
-- Aggregation Table: agg_rental_by_film_store_month
-- Pre-aggregated data for common rental queries
--

CREATE TABLE agg_rental_by_film_store_month (
  `year_month` INT NOT NULL,
  film_key INT NOT NULL,
  store_key INT NOT NULL,
  rental_count INT DEFAULT 0,
  revenue DECIMAL(10,2) DEFAULT 0,
  avg_rental_days DECIMAL(10,2) DEFAULT 0,
  PRIMARY KEY (`year_month`, film_key, store_key),
  KEY idx_year_month (`year_month`),
  KEY idx_film (film_key),
  KEY idx_store (store_key),
  CONSTRAINT fk_agg_film FOREIGN KEY (film_key) REFERENCES dim_film (film_key),
  CONSTRAINT fk_agg_store FOREIGN KEY (store_key) REFERENCES dim_store (store_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

--
-- Aggregation Table: agg_payment_by_customer_month
-- Pre-aggregated data for customer payment analysis
--

CREATE TABLE agg_payment_by_customer_month (
  `year_month` INT NOT NULL,
  customer_key INT NOT NULL,
  total_payments INT DEFAULT 0,
  total_amount DECIMAL(10,2) DEFAULT 0,
  avg_payment DECIMAL(10,2) DEFAULT 0,
  PRIMARY KEY (`year_month`, customer_key),
  KEY idx_year_month (`year_month`),
  KEY idx_customer (customer_key),
  CONSTRAINT fk_agg_customer FOREIGN KEY (customer_key) REFERENCES dim_customer (customer_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================================
-- INDEXES FOR PERFORMANCE
-- ============================================================================

CREATE INDEX idx_date_full_date ON dim_date(full_date);
CREATE INDEX idx_date_year_month ON dim_date(date_year, date_month);
CREATE INDEX idx_dim_customer_city ON dim_customer(city);
CREATE INDEX idx_dim_film_category ON dim_film(category);
CREATE INDEX idx_fact_rental_dates ON fact_rental(rental_date_id, return_date_id);
CREATE INDEX idx_fact_payment_date ON fact_payment(payment_date_id);

-- ============================================================================
-- VIEWS FOR REPORTING
-- ============================================================================

--
-- View: vw_rental_summary
-- Provides comprehensive rental analysis
--

CREATE VIEW vw_rental_summary AS
SELECT 
  fr.rental_id,
  c.first_name AS customer_first_name,
  c.last_name AS customer_last_name,
  f.title AS film_title,
  f.category,
  s.city,
  s.country,
  dd.full_date AS rental_date,
  fr.days_rented,
  fr.rental_rate
FROM fact_rental fr
JOIN dim_customer c ON fr.customer_key = c.customer_key
JOIN dim_film f ON fr.film_key = f.film_key
JOIN dim_store s ON fr.store_key = s.store_key
JOIN dim_date dd ON fr.rental_date_id = dd.date_id;

--
-- View: vw_payment_summary
-- Provides comprehensive payment analysis
--

CREATE VIEW vw_payment_summary AS
SELECT 
  fp.payment_id,
  c.first_name AS customer_first_name,
  c.last_name AS customer_last_name,
  c.city,
  c.country,
  dd.full_date AS payment_date,
  fp.amount,
  CASE WHEN fp.rental_key IS NOT NULL THEN 'Rental' ELSE 'Other' END AS payment_type
FROM fact_payment fp
JOIN dim_customer c ON fp.customer_key = c.customer_key
JOIN dim_date dd ON fp.payment_date_id = dd.date_id;

--
-- View: vw_film_performance
-- Film performance metrics by store
--

CREATE VIEW vw_film_performance AS
SELECT 
  f.title,
  f.category,
  s.city,
  s.country,
  COUNT(DISTINCT fr.rental_id) AS rental_count,
  SUM(fp.amount) AS total_revenue,
  AVG(fr.rental_rate) AS avg_rental_rate,
  AVG(fr.days_rented) AS avg_rental_days
FROM dim_film f
LEFT JOIN fact_rental fr ON f.film_key = fr.film_key
LEFT JOIN fact_payment fp ON fr.rental_key = fp.rental_key
LEFT JOIN dim_store s ON fr.store_key = s.store_key
GROUP BY f.film_id, f.title, f.category, s.store_id, s.city, s.country;

--
-- View: vw_customer_lifetime_value
-- Customer lifetime value analysis
--

CREATE VIEW vw_customer_lifetime_value AS
SELECT 
  c.customer_id,
  CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
  c.city,
  c.country,
  COUNT(DISTINCT fr.rental_id) AS rental_count,
  SUM(fp.amount) AS lifetime_value,
  MAX(dd.full_date) AS last_payment_date,
  AVG(fp.amount) AS avg_payment
FROM dim_customer c
LEFT JOIN fact_rental fr ON c.customer_key = fr.customer_key
LEFT JOIN fact_payment fp ON c.customer_key = fp.customer_key
LEFT JOIN dim_date dd ON fp.payment_date_id = dd.date_id
GROUP BY c.customer_id, c.first_name, c.last_name, c.city, c.country;

--
-- View: vw_store_performance
-- Store performance metrics
--

CREATE VIEW vw_store_performance AS
SELECT 
  s.store_id,
  s.city,
  s.country,
  s.manager_name,
  COUNT(DISTINCT fr.rental_id) AS total_rentals,
  SUM(fp.amount) AS total_revenue,
  COUNT(DISTINCT fr.customer_key) AS unique_customers,
  AVG(fp.amount) AS avg_transaction_value
FROM dim_store s
LEFT JOIN fact_rental fr ON s.store_key = fr.store_key
LEFT JOIN fact_payment fp ON fr.rental_key = fp.rental_key
GROUP BY s.store_id, s.city, s.country, s.manager_name;

SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS;
SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS;
SET SQL_MODE=@OLD_SQL_MODE;
