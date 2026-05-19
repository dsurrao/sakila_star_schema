CREATE 
    ALGORITHM = UNDEFINED 
    DEFINER = `root`@`localhost` 
    SQL SECURITY DEFINER
VIEW `sakila_star`.`vw_film_performance` AS
    SELECT 
        `f`.`title` AS `title`,
        `f`.`category` AS `category`,
        `s`.`city` AS `city`,
        `s`.`country` AS `country`,
        COUNT(DISTINCT `fr`.`rental_id`) AS `rental_count`,
        SUM(`fp`.`amount`) AS `total_revenue`,
        AVG(`fr`.`rental_rate`) AS `avg_rental_rate`,
        AVG(`fr`.`days_rented`) AS `avg_rental_days`
    FROM
        (((`sakila_star`.`dim_film` `f`
        LEFT JOIN `sakila_star`.`fact_rental` `fr` ON ((`f`.`film_key` = `fr`.`film_key`)))
        LEFT JOIN `sakila_star`.`fact_payment` `fp` ON ((`fr`.`rental_key` = `fp`.`rental_key`)))
        LEFT JOIN `sakila_star`.`dim_store` `s` ON ((`fr`.`store_key` = `s`.`store_key`)))
    GROUP BY `f`.`film_id` , `f`.`title` , `f`.`category` , `s`.`store_id` , `s`.`city` , `s`.`country`;
