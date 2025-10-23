-- Output the number of movies in each category, sorted descending.--
SELECT 
    name, 
    COUNT(DISTINCT title) AS count_films
FROM (
    SELECT 
        f.title, 
        c.name
    FROM film f
    JOIN film_category fc ON f.film_id = fc.film_id
    JOIN category c ON fc.category_id = c.category_id
) AS cat_film
GROUP BY name
ORDER BY name DESC;

--Output the 10 actors whose movies rented the most, sorted in descending order.--
-- rental_rate является оценкой , поэтому расчет будет для среднего значения --
-- для film_id 257, 803, 323  нет записей в таблице film_actor , поэтому правильно сделать inner join --
--SELECT distinct film_id FROM film where film_id not in (select film_id from film_actor)--

SELECT 
    ROUND(AVG(rental_rate), 2) AS rate,
    full_afr.first_name || ' ' || full_afr.last_name AS actor_name
FROM (
    SELECT 
        f.rental_rate,
        a.first_name,
        a.last_name
    FROM film f
    JOIN film_actor fa ON f.film_id = fa.film_id
    JOIN actor a ON fa.actor_id = a.actor_id
) AS full_afr
GROUP BY full_afr.first_name, full_afr.last_name
ORDER BY rate DESC
LIMIT 10; 

--Output the category of movies on which the most money was spent.--
-- все join выполнены как inner join, т.к. любые nun в правых частях join ломают дальнейшую цепочку связей,-- 
--например, фильмы без инвентарного номера, или те, которе не брали в аренду --
SELECT 
    c.name AS category_name,
    SUM(p.amount) AS total_spent
FROM category c
JOIN film_category fc ON c.category_id = fc.category_id
JOIN inventory i ON fc.film_id = i.film_id
JOIN rental r ON i.inventory_id = r.inventory_id
JOIN payment p ON r.rental_id = p.rental_id
GROUP BY c.name
ORDER BY total_spent DESC
LIMIT 1;

-- Print the names of movies that are not in the inventory. Write a query without using the IN operator. --

SELECT 
    f.film_id, 
    f.title
FROM film f
LEFT JOIN inventory i ON f.film_id = i.film_id
WHERE i.inventory_id IS NULL;

--Output the top 3 actors who have appeared the most in movies in the “Children” category. --
--If several actors have the same number of movies, output all of them.--
-- объединение через inner join, причины описаны выше--
SELECT 
    actor_name,
    count_film
FROM (
    SELECT 
        a.first_name || ' ' || a.last_name AS actor_name,
        COUNT(fa.film_id) AS count_film,
        DENSE_RANK() OVER (ORDER BY COUNT(fa.film_id) DESC) AS rank_ch
    FROM film_actor fa
    JOIN film_category fc ON fa.film_id = fc.film_id
    JOIN actor a ON a.actor_id = fa.actor_id
    JOIN category c ON c.category_id = fc.category_id
    WHERE TRIM(LOWER(c.name)) = 'children'
    GROUP BY a.actor_id, a.first_name, a.last_name
) AS ranked_actors
WHERE rank_ch <= 3;


--Output cities with the number of active and inactive customers (active - customer.active = 1). --
--Sort by the number of inactive customers in descending order.--

SELECT 
    ct.city,
    SUM(CASE WHEN c.active = 1 THEN 1 ELSE 0 END) OVER (PARTITION BY ct.city_id) AS active_count,
    SUM(CASE WHEN c.active = 0 THEN 1 ELSE 0 END) OVER (PARTITION BY ct.city_id) AS inactive_count
FROM customer c
JOIN address ad ON c.address_id = ad.address_id
JOIN city ct ON ad.city_id = ct.city_id
ORDER BY inactive_count DESC;

--Output the category of movies that have the highest number of total rental hours in the city (customer.address_id in this city) --
--and that start with the letter “a”. Do the same for cities that have a “-” in them. Write everything in one query.


WITH rental_hours_cte AS (
    SELECT 
        ct.city,
        c.name AS category_name,
        ROUND(SUM(EXTRACT(EPOCH FROM (r.return_date - r.rental_date)) / 3600), 0)::INT AS rental_hours
    FROM rental r
    JOIN inventory inv ON r.inventory_id = inv.inventory_id
    JOIN film f ON f.film_id = inv.film_id
    JOIN film_category fc ON f.film_id = fc.film_id
    JOIN category c ON fc.category_id = c.category_id
    JOIN payment p ON p.rental_id = r.rental_id
    JOIN customer cus ON cus.customer_id = p.customer_id
    JOIN address a ON a.address_id = cus.address_id
    JOIN city ct ON ct.city_id = a.city_id
    WHERE LOWER(f.title) LIKE 'a%'
    GROUP BY ct.city, c.name
),
ranked_all AS (
    SELECT 
        city,
        category_name,
        rental_hours,
        RANK() OVER (PARTITION BY city ORDER BY rental_hours DESC) AS rnk
    FROM rental_hours_cte
),
ranked_dash AS (
    SELECT 
        city,
        category_name,
        rental_hours,
        RANK() OVER (PARTITION BY city ORDER BY rental_hours DESC) AS rnk
    FROM rental_hours_cte
    WHERE city LIKE '%-%'
)
SELECT 
    'All Cities' AS group_type,
    city,
    category_name,
    rental_hours
FROM ranked_all
WHERE rnk = 1

UNION ALL

SELECT 
    'Cities with Dash' AS group_type,
    city,
    category_name,
    rental_hours
FROM ranked_dash
WHERE rnk = 1

ORDER BY group_type, city;


 








