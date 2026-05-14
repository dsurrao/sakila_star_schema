-- Sakila Star Schema - Data Population Script
-- This script populates the star schema from the original Sakila database
-- Assumes both sakila and sakila_star schemas exist in the same database instance

USE sakila_star;

SET NAMES utf8mb4;
SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0;
SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0;
SET AUTOCOMMIT=0;

-- ============================================================================
-- POPULATE DIM_DATE
-- Generate date dimension from rental and payment dates
-- ============================================================================

DELIMITER //

CREATE PROCEDURE sp_populate_date_dimension()
BEGIN
  DECLARE v_start_date DATE;
  DECLARE v_end_date DATE;
  DECLARE v_current_date DATE;
  DECLARE v_date_id INT;
  DECLARE v_year_month INT;
  
  -- Get date range from sakila database
  SELECT MIN(DATE(rental_date)) INTO v_start_date FROM sakila.rental;
  SELECT MAX(DATE(return_date)) INTO v_end_date FROM sakila.rental;
  
  -- Set a buffer for safety
  IF v_end_date IS NULL THEN
    SELECT MAX(DATE(payment_date)) INTO v_end_date FROM sakila.payment;
  END IF;
  
  SET v_current_date = v_start_date;
  
  -- Loop through each date
  WHILE v_current_date <= v_end_date DO
    -- Create date_id as YYYYMMDD
    SET v_date_id = YEAR(v_current_date) * 10000 + MONTH(v_current_date) * 100 + DAY(v_current_date);
    
    -- Insert date record
    INSERT INTO dim_date (
      date_id,
      full_date,
      date_day,
      date_month,
      date_quarter,
      date_year,
      day_name,
      month_name,
      is_weekend
    )
    VALUES (
      v_date_id,
      v_current_date,
      DAY(v_current_date),
      MONTH(v_current_date),
      QUARTER(v_current_date),
      YEAR(v_current_date),
      DAYNAME(v_current_date),
      MONTHNAME(v_current_date),
      IF(DAYOFWEEK(v_current_date) IN (1, 7), TRUE, FALSE)
    )
    ON DUPLICATE KEY UPDATE date_id = date_id;
    
    -- Move to next date
    SET v_current_date = DATE_ADD(v_current_date, INTERVAL 1 DAY);
  END WHILE;
  
END//

DELIMITER ;

CALL sp_populate_date_dimension();

-- ============================================================================
-- POPULATE DIM_CUSTOMER
-- Denormalize customer information with location details
-- ============================================================================

INSERT INTO dim_customer (
  customer_id,
  first_name,
  last_name,
  email,
  customer_status,
  address,
  city,
  postal_code,
  country,
  store_id,
  date_created
)
SELECT 
  c.customer_id,
  c.first_name,
  c.last_name,
  c.email,
  IF(c.active = 1, 'active', 'inactive'),
  a.address,
  ci.city,
  a.postal_code,
  co.country,
  c.store_id,
  c.create_date
FROM sakila.customer c
LEFT JOIN sakila.address a ON c.address_id = a.address_id
LEFT JOIN sakila.city ci ON a.city_id = ci.city_id
LEFT JOIN sakila.country co ON ci.country_id = co.country_id;

-- ============================================================================
-- POPULATE DIM_CATEGORY
-- Film category information
-- ============================================================================

INSERT INTO dim_category (
  category_id,
  category_name
)
SELECT 
  category_id,
  name
FROM sakila.category;

-- ============================================================================
-- POPULATE DIM_FILM
-- Denormalized film information with category and language
-- ============================================================================

INSERT INTO dim_film (
  film_id,
  title,
  description,
  release_year,
  language,
  rating,
  length,
  rental_duration,
  rental_rate,
  replacement_cost,
  category
)
SELECT 
  f.film_id,
  f.title,
  f.description,
  f.release_year,
  l.name,
  f.rating,
  f.length,
  f.rental_duration,
  f.rental_rate,
  f.replacement_cost,
  GROUP_CONCAT(DISTINCT c.name ORDER BY c.name SEPARATOR ', ')
FROM sakila.film f
LEFT JOIN sakila.language l ON f.language_id = l.language_id
LEFT JOIN sakila.film_category fc ON f.film_id = fc.film_id
LEFT JOIN sakila.category c ON fc.category_id = c.category_id
GROUP BY f.film_id;

-- ============================================================================
-- POPULATE DIM_ACTOR
-- Actor information
-- ============================================================================

INSERT INTO dim_actor (
  actor_id,
  first_name,
  last_name
)
SELECT 
  actor_id,
  first_name,
  last_name
FROM sakila.actor;

-- ============================================================================
-- POPULATE DIM_STORE
-- Store information with location and manager details
-- ============================================================================

INSERT INTO dim_store (
  store_id,
  address,
  city,
  country,
  manager_name
)
SELECT 
  s.store_id,
  a.address,
  ci.city,
  co.country,
  CONCAT(st.first_name, ' ', st.last_name)
FROM sakila.store s
LEFT JOIN sakila.address a ON s.address_id = a.address_id
LEFT JOIN sakila.city ci ON a.city_id = ci.city_id
LEFT JOIN sakila.country co ON ci.country_id = co.country_id
LEFT JOIN sakila.staff st ON s.manager_staff_id = st.staff_id;

-- ============================================================================
-- POPULATE FACT_RENTAL
-- Core rental fact table
-- ============================================================================

INSERT INTO fact_rental (
  rental_id,
  rental_date_id,
  return_date_id,
  customer_key,
  film_key,
  store_key,
  days_rented,
  rental_rate
)
SELECT 
  r.rental_id,
  YEAR(r.rental_date) * 10000 + MONTH(r.rental_date) * 100 + DAY(r.rental_date),
  IF(r.return_date IS NOT NULL, 
     YEAR(r.return_date) * 10000 + MONTH(r.return_date) * 100 + DAY(r.return_date),
     NULL),
  dc.customer_key,
  df.film_key,
  ds.store_key,
  IF(r.return_date IS NOT NULL, DATEDIFF(r.return_date, r.rental_date), NULL),
  f.rental_rate
FROM sakila.rental r
JOIN sakila.inventory i ON r.inventory_id = i.inventory_id
JOIN sakila.film f ON i.film_id = f.film_id
JOIN dim_customer dc ON r.customer_id = dc.customer_id
JOIN dim_film df ON f.film_id = df.film_id
JOIN dim_store ds ON i.store_id = ds.store_id;

-- ============================================================================
-- POPULATE FACT_PAYMENT
-- Core payment fact table
-- ============================================================================

INSERT INTO fact_payment (
  payment_id,
  payment_date_id,
  customer_key,
  rental_key,
  amount
)
SELECT 
  p.payment_id,
  YEAR(p.payment_date) * 10000 + MONTH(p.payment_date) * 100 + DAY(p.payment_date),
  dc.customer_key,
  fr.rental_key,
  p.amount
FROM sakila.payment p
JOIN dim_customer dc ON p.customer_id = dc.customer_id
LEFT JOIN sakila.rental r ON p.rental_id = r.rental_id
LEFT JOIN fact_rental fr ON r.rental_id = fr.rental_id;

-- ============================================================================
-- POPULATE FACT_FILM_ACTOR
-- Association between films and actors
-- ============================================================================

INSERT INTO fact_film_actor (
  film_key,
  actor_key
)
SELECT DISTINCT
  df.film_key,
  da.actor_key
FROM sakila.film_actor fa
JOIN dim_film df ON fa.film_id = df.film_id
JOIN dim_actor da ON fa.actor_id = da.actor_id;

-- ============================================================================
-- POPULATE AGG_RENTAL_BY_FILM_STORE_MONTH
-- Pre-aggregated rental data
-- ============================================================================

INSERT INTO agg_rental_by_film_store_month (
  `year_month`,
  film_key,
  store_key,
  rental_count,
  revenue,
  avg_rental_days
)
SELECT 
  dd.date_year * 100 + dd.date_month,
  df.film_key,
  ds.store_key,
  COUNT(DISTINCT fr.rental_id),
  SUM(fp.amount),
  AVG(COALESCE(fr.days_rented, 0))
FROM fact_rental fr
JOIN dim_date dd ON fr.rental_date_id = dd.date_id
JOIN dim_film df ON fr.film_key = df.film_key
JOIN dim_store ds ON fr.store_key = ds.store_key
LEFT JOIN fact_payment fp ON fr.rental_key = fp.rental_key
GROUP BY 
  dd.date_year * 100 + dd.date_month,
  df.film_key,
  ds.store_key;

-- ============================================================================
-- POPULATE AGG_PAYMENT_BY_CUSTOMER_MONTH
-- Pre-aggregated payment data
-- ============================================================================

INSERT INTO agg_payment_by_customer_month (
  `year_month`,
  customer_key,
  total_payments,
  total_amount,
  avg_payment
)
SELECT 
  dd.date_year * 100 + dd.date_month,
  fp.customer_key,
  COUNT(DISTINCT fp.payment_id),
  SUM(fp.amount),
  AVG(fp.amount)
FROM fact_payment fp
JOIN dim_date dd ON fp.payment_date_id = dd.date_id
GROUP BY 
  dd.date_year * 100 + dd.date_month,
  fp.customer_key;

-- ============================================================================
-- CLEANUP AND COMMIT
-- ============================================================================

SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS;
SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS;

COMMIT;

-- Display row counts for verification
SELECT 'Date Dimension' AS Table_Name, COUNT(*) AS Row_Count FROM dim_date
UNION ALL
SELECT 'Customer Dimension', COUNT(*) FROM dim_customer
UNION ALL
SELECT 'Film Dimension', COUNT(*) FROM dim_film
UNION ALL
SELECT 'Actor Dimension', COUNT(*) FROM dim_actor
UNION ALL
SELECT 'Store Dimension', COUNT(*) FROM dim_store
UNION ALL
SELECT 'Category Dimension', COUNT(*) FROM dim_category
UNION ALL
SELECT 'Rental Facts', COUNT(*) FROM fact_rental
UNION ALL
SELECT 'Payment Facts', COUNT(*) FROM fact_payment
UNION ALL
SELECT 'Film-Actor Facts', COUNT(*) FROM fact_film_actor
UNION ALL
SELECT 'Rental Aggregation', COUNT(*) FROM agg_rental_by_film_store_month
UNION ALL
SELECT 'Payment Aggregation', COUNT(*) FROM agg_payment_by_customer_month
ORDER BY Table_Name;
