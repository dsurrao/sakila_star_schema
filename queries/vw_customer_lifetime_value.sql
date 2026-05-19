CREATE 
    ALGORITHM = UNDEFINED 
    DEFINER = `root`@`localhost` 
    SQL SECURITY DEFINER
VIEW `sakila_star`.`vw_customer_lifetime_value` AS
    SELECT 
        `c`.`customer_id` AS `customer_id`,
        CONCAT(`c`.`first_name`, ' ', `c`.`last_name`) AS `customer_name`,
        `c`.`city` AS `city`,
        `c`.`country` AS `country`,
        COUNT(DISTINCT `fr`.`rental_id`) AS `rental_count`,
        SUM(`fp`.`amount`) AS `lifetime_value`,
        MAX(`dd`.`full_date`) AS `last_payment_date`,
        AVG(`fp`.`amount`) AS `avg_payment`
    FROM
        (((`sakila_star`.`dim_customer` `c`
        LEFT JOIN `sakila_star`.`fact_rental` `fr` ON ((`c`.`customer_key` = `fr`.`customer_key`)))
        LEFT JOIN `sakila_star`.`fact_payment` `fp` ON ((`c`.`customer_key` = `fp`.`customer_key`)))
        LEFT JOIN `sakila_star`.`dim_date` `dd` ON ((`fp`.`payment_date_id` = `dd`.`date_id`)))
    GROUP BY `c`.`customer_id` , `c`.`first_name` , `c`.`last_name` , `c`.`city` , `c`.`country`;
