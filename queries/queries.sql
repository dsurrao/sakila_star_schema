use sakila_star;

-- get the top 5 most valuable customers
select customer_name, rental_count, lifetime_value, avg_payment 
from vw_customer_lifetime_value
order by lifetime_value desc limit 5;

-- get the top 5 best performing films by revenue
select title, category, rental_count, total_revenue, avg_rental_days 
from vw_film_performance
order by total_revenue desc limit 5;



