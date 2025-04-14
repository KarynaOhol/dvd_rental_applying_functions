-- ========================================================
-- Task 1. Create a view
-- ========================================================
---Create a view called 'sales_revenue_by_category_qtr' that shows the film category and total sales revenue
-- for the current quarter and year. The view should only display categories with at least one sale in the current quarter.
--Note: when the next quarter begins, it will be considered as the current quarter.

-- Create the view
CREATE OR REPLACE VIEW public.sales_revenue_by_category_qtr AS
SELECT c.name        AS category_name,
       SUM(p.amount) AS total_sales_revenue
FROM category c
         JOIN film_category fc ON c.category_id = fc.category_id
         JOIN film f ON fc.film_id = f.film_id
         JOIN inventory i ON f.film_id = i.film_id
         JOIN rental r ON i.inventory_id = r.inventory_id
         JOIN payment p ON r.rental_id = p.rental_id
WHERE EXTRACT(YEAR FROM p.payment_date) = EXTRACT(YEAR FROM CURRENT_DATE)
  AND EXTRACT(QUARTER FROM p.payment_date) = EXTRACT(QUARTER FROM CURRENT_DATE)
GROUP BY c.name
HAVING SUM(p.amount) > 0
ORDER BY total_sales_revenue DESC;

-- add some test data using the rent_movie_by_title function
-- We'll insert rentals for the current quarter so to insert the payment_date into the table payment, we need can create
-- a new partition (as example from the scripts to install the training database)

-- Calculate the current quarter's start and end dates
DO
$$
    DECLARE
        current_year         INT := EXTRACT(YEAR FROM CURRENT_DATE);
        current_quarter      INT := EXTRACT(QUARTER FROM CURRENT_DATE);
        partition_start_date TIMESTAMP WITH TIME ZONE;
        partition_end_date   TIMESTAMP WITH TIME ZONE;
        partition_name       TEXT;
    BEGIN
        -- Set the start and end dates based on the current quarter
        CASE current_quarter
            WHEN 1 THEN partition_start_date := make_timestamptz(current_year, 1, 1, 0, 0, 0, 'UTC');
                        partition_end_date := make_timestamptz(current_year, 4, 1, 0, 0, 0, 'UTC');
            WHEN 2 THEN partition_start_date := make_timestamptz(current_year, 4, 1, 0, 0, 0, 'UTC');
                        partition_end_date := make_timestamptz(current_year, 7, 1, 0, 0, 0, 'UTC');
            WHEN 3 THEN partition_start_date := make_timestamptz(current_year, 7, 1, 0, 0, 0, 'UTC');
                        partition_end_date := make_timestamptz(current_year, 10, 1, 0, 0, 0, 'UTC');
            WHEN 4 THEN partition_start_date := make_timestamptz(current_year, 10, 1, 0, 0, 0, 'UTC');
                        partition_end_date := make_timestamptz(current_year + 1, 1, 1, 0, 0, 0, 'UTC');
            END CASE;

        -- Create the partition name
        partition_name := 'payment_p' || current_year || '_q' || current_quarter;

        -- Create the partition if it doesn't exist
        EXECUTE format('
        CREATE TABLE IF NOT EXISTS %I
        PARTITION OF payment
        (
            FOREIGN KEY (customer_id) REFERENCES customer,
            FOREIGN KEY (rental_id) REFERENCES rental,
            FOREIGN KEY (staff_id) REFERENCES staff
        )
        FOR VALUES FROM (%L) TO (%L)
    ', partition_name, partition_start_date, partition_end_date);

        -- Create necessary indexes as in example
        EXECUTE format('
        CREATE INDEX IF NOT EXISTS idx_fk_%I_customer_id ON %I (customer_id)
    ', partition_name, partition_name);

        EXECUTE format('
        CREATE INDEX IF NOT EXISTS idx_fk_%I_rental_id ON %I (rental_id)
    ', partition_name, partition_name);

        EXECUTE format('
        CREATE INDEX IF NOT EXISTS idx_fk_%I_staff_id ON %I (staff_id)
    ', partition_name, partition_name);

        RAISE NOTICE 'Created partition % for period from % to %', partition_name, partition_start_date, partition_end_date;
    END
$$;
-- SELECT * FROM public.payment_p2025_q2;
-- SELECT * FROM payment
-- WHERE payment_date BETWEEN '2025-04-01 00:00:00+00' AND '2025-07-01 00:00:00+00';

-- STEP 2: Find existing rentals to use for test payments

-- Create a temporary table to store valid rental IDs that don't already have payments in the current quarter
CREATE TEMP TABLE public.valid_rentals AS
SELECT r.rental_id, r.customer_id, r.staff_id
FROM rental r
WHERE NOT EXISTS (SELECT 1
                  FROM payment p
                  WHERE p.rental_id = r.rental_id
                    AND EXTRACT(YEAR FROM p.payment_date) = EXTRACT(YEAR FROM CURRENT_DATE)
                    AND EXTRACT(QUARTER FROM p.payment_date) = EXTRACT(QUARTER FROM CURRENT_DATE))
LIMIT 500;-- reduce number of rentals to work with
SELECT *
FROM public.valid_rentals;

-- Insert payments for different categories to test the view
DO
$$
    DECLARE
        current_year       INT    := EXTRACT(YEAR FROM CURRENT_DATE);
        current_quarter    INT    := EXTRACT(QUARTER FROM CURRENT_DATE);
        quarter_start_date DATE;
        quarter_end_date   DATE;
        random_date        TIMESTAMP WITH TIME ZONE;
        rental_record      RECORD;
        category_counts    JSONB;
        next_payment_id    INT;
        category_name      TEXT;
        categories         TEXT[] := ARRAY ['Action', 'Animation', 'Children', 'Classics', 'Comedy', 'Documentary',
            'Drama', 'Family', 'Foreign', 'Games', 'Horror', 'Music', 'New',
            'Sci-Fi', 'Sports', 'Travel'];
        target_count       INT;
        rental_id          INT;
        customer_id        INT;
        staff_id           INT;
        amount             NUMERIC(5, 2);
    BEGIN
        -- Set the quarter date range
        CASE current_quarter
            WHEN 1 THEN quarter_start_date := make_date(current_year, 1, 1);
                        quarter_end_date := make_date(current_year, 3, 31);
            WHEN 2 THEN quarter_start_date := make_date(current_year, 4, 1);
                        quarter_end_date := make_date(current_year, 6, 30);
            WHEN 3 THEN quarter_start_date := make_date(current_year, 7, 1);
                        quarter_end_date := make_date(current_year, 9, 30);
            WHEN 4 THEN quarter_start_date := make_date(current_year, 10, 1);
                        quarter_end_date := make_date(current_year, 12, 31);
            END CASE;

        -- Get the next payment_id
        SELECT COALESCE(MAX(payment_id), 0) + 1 INTO next_payment_id FROM payment;

        -- Initialize category counts - we'll generate more data for some categories than others
        category_counts := '{}'::JSONB;
        FOREACH category_name IN ARRAY categories
            LOOP
                -- Randomize the number of payments per category (0-30)
                target_count := floor(random() * 30)::INT;
                category_counts := jsonb_set(category_counts, ARRAY [category_name], to_jsonb(target_count));
            END LOOP;

        -- Get random rentals from our valid_rentals table and create payments
        FOR rental_record IN
            SELECT vr.rental_id,
                   vr.customer_id,
                   vr.staff_id,
                   c.name AS category
            FROM valid_rentals vr
                     JOIN rental r ON vr.rental_id = r.rental_id
                     JOIN inventory i ON r.inventory_id = i.inventory_id
                     JOIN film f ON i.film_id = f.film_id
                     JOIN film_category fc ON f.film_id = fc.film_id
                     JOIN category c ON fc.category_id = c.category_id
            ORDER BY random()
            LOOP
                -- Check if we still need payments for this category
                IF (category_counts -> rental_record.category)::INT > 0 THEN
                    -- Generate a random payment date within the current quarter
                    random_date :=
                            (quarter_start_date + (random() * (quarter_end_date - quarter_start_date))::INT)::date;
                    -- Add a random time component
                    random_date := random_date +
                                   make_interval(hours => floor(random() * 24)::INT,
                                                 mins => floor(random() * 60)::INT,
                                                 secs => floor(random() * 60)::INT);

                    -- Generate a random payment amount between $0.99 and $9.99
                    amount := 0.99 + (random() * 9)::NUMERIC(5, 2);

                    -- Insert the payment record
                    INSERT INTO payment (payment_id, customer_id, staff_id, rental_id,
                                         amount, payment_date)
                    VALUES (next_payment_id, rental_record.customer_id, rental_record.staff_id, rental_record.rental_id,
                            amount, random_date);

                    -- Increment the payment_id for the next record
                    next_payment_id := next_payment_id + 1;

                    -- Decrement the count for this category
                    category_counts := jsonb_set(
                            category_counts,
                            ARRAY [rental_record.category],
                            to_jsonb((category_counts -> rental_record.category)::INT - 1)
                                       );
                END IF;

                -- Check if we've completed all categories
                IF (SELECT sum((value::text)::INT) FROM jsonb_each(category_counts)) = 0 THEN
                    EXIT; -- Exit the loop if all categories have reached their target count
                END IF;
            END LOOP;

        RAISE NOTICE 'Inserted payments for the current quarter (Year: %, Quarter: %)', current_year, current_quarter;
    END
$$;

-- Check how many payments we inserted by category
SELECT c.name              AS category_name,
       COUNT(p.payment_id) AS payment_count,
       SUM(p.amount)       AS total_amount
FROM category c
         JOIN film_category fc ON c.category_id = fc.category_id
         JOIN film f ON fc.film_id = f.film_id
         JOIN inventory i ON f.film_id = i.film_id
         JOIN rental r ON i.inventory_id = r.inventory_id
         JOIN payment p ON r.rental_id = p.rental_id
WHERE EXTRACT(YEAR FROM p.payment_date) = EXTRACT(YEAR FROM CURRENT_DATE)
  AND EXTRACT(QUARTER FROM p.payment_date) = EXTRACT(QUARTER FROM CURRENT_DATE)
GROUP BY c.name
ORDER BY total_amount DESC;

-- View the results from sales_revenue_by_category_qtr view
SELECT *
FROM public.sales_revenue_by_category_qtr;

-- Clean up
DELETE
FROM payment
WHERE EXTRACT(YEAR FROM payment_date) = EXTRACT(YEAR FROM CURRENT_DATE)
  AND EXTRACT(QUARTER FROM payment_date) = EXTRACT(QUARTER FROM CURRENT_DATE);

DROP TABLE IF EXISTS public.valid_rentals;

-- ========================================================
-- Task 2. Create a query language functions
-- ========================================================
---Create a query language function called 'get_sales_revenue_by_category_qtr' that accepts one parameter representing
-- the current quarter and year and returns the same result as the 'sales_revenue_by_category_qtr' view.
-- Function to get sales revenue by category for a specific quarter and year
CREATE OR REPLACE FUNCTION public.get_sales_revenue_by_category_qtr(
    p_year INT DEFAULT EXTRACT(YEAR FROM CURRENT_DATE)::INT,
    p_quarter INT DEFAULT EXTRACT(QUARTER FROM CURRENT_DATE)::INT
)
    RETURNS TABLE
            (
                category_name       TEXT,
                total_sales_revenue NUMERIC
            )
    LANGUAGE SQL
AS
$$
SELECT c.name        AS category_name,
       SUM(p.amount) AS total_sales_revenue
FROM category c
         JOIN film_category fc ON c.category_id = fc.category_id
         JOIN film f ON fc.film_id = f.film_id
         JOIN inventory i ON f.film_id = i.film_id
         JOIN rental r ON i.inventory_id = r.inventory_id
         JOIN payment p ON r.rental_id = p.rental_id
WHERE EXTRACT(YEAR FROM p.payment_date) = p_year
  AND EXTRACT(QUARTER FROM p.payment_date) = p_quarter
GROUP BY c.name
HAVING SUM(p.amount) > 0
ORDER BY total_sales_revenue DESC;
$$;

-- View the results from 'get_sales_revenue_by_category_qtr' function
-- Current quarter and year (default parameters)
SELECT *
FROM public.get_sales_revenue_by_category_qtr();

-- Specific quarter and year
SELECT *
FROM public.get_sales_revenue_by_category_qtr(2017, 1);

-- Just override quarter (keep current year)
SELECT *
FROM public.get_sales_revenue_by_category_qtr(p_quarter := 2);

-- Just override year (keep current quarter)
SELECT *
FROM public.get_sales_revenue_by_category_qtr(p_year := 2017);

-- test that 'get_sales_revenue_by_category_qtr' function returns the same result as the 'sales_revenue_by_category_qtr' view.
    (SELECT * FROM public.get_sales_revenue_by_category_qtr())
    EXCEPT
    (SELECT * FROM public.sales_revenue_by_category_qtr);

-- ========================================================
-- Task 3. Create procedure language functions
-- ========================================================
-- Create a function that takes a country as an input parameter and returns the most popular film in that specific country.
--The function should format the result set as follows:

-- Query (example):select * from core.most_popular_films_by_countries(array['Afghanistan','Brazil','United States’]);

-- |   Country   |   Film       |    Rating      |   Language   |   Length       |    Release year     |
-- |-------------|--------------|--------------- |--------------|----------------|-------------------- |
-- | Country 1   | Film A       | PG             | English      | 100            | 2006                |
-- | Country 1   | Film B       | PG-13          | English      | 100            | 2006                |


-- Function to find most popular films by countries
CREATE OR REPLACE FUNCTION public.most_popular_films_by_countries(
    p_countries TEXT[]
)
    RETURNS TABLE
            (
                country      TEXT,
                film         TEXT,
                rating       TEXT,
                language     TEXT,
                length       INT,
                release_year INT
            )
    LANGUAGE plpgsql
AS
$$
BEGIN
    RETURN QUERY
        -- Step 1: Get rental counts for each film in each specified country
        WITH film_rental_counts AS (SELECT co.country::TEXT   AS country_name,
                                           f.title::TEXT      AS film_title,
                                           f.rating::TEXT,
                                           l.name::TEXT       AS film_language,
                                           f.length::INT,
                                           f.release_year::INT,
                                           COUNT(r.rental_id) AS rental_count
                                    FROM country co
                                             JOIN city ci ON co.country_id = ci.country_id
                                             JOIN address a ON ci.city_id = a.city_id
                                             JOIN customer cu ON a.address_id = cu.address_id
                                             JOIN rental r ON cu.customer_id = r.customer_id
                                             JOIN inventory i ON r.inventory_id = i.inventory_id
                                             JOIN film f ON i.film_id = f.film_id
                                             JOIN language l ON f.language_id = l.language_id
                                    WHERE co.country = ANY (p_countries)
                                    GROUP BY co.country, f.title, f.rating, l.name, f.length, f.release_year),
             -- Step 2: Get max rental count for each country
             country_max_rentals AS (SELECT country_name,
                                            MAX(rental_count) AS max_rental_count
                                     FROM film_rental_counts
                                     GROUP BY country_name)
        -- Step 3: Join the two CTEs to get films with the max rental count for each country
        SELECT frc.country_name,
               frc.film_title,
               frc.rating,
               frc.film_language,
               frc.length,
               frc.release_year
        FROM film_rental_counts frc
                 JOIN country_max_rentals cmr ON
            frc.country_name = cmr.country_name AND
            frc.rental_count = cmr.max_rental_count
        ORDER BY frc.country_name, frc.film_title;
END;
$$;
-- test case
SELECT *
FROM public.most_popular_films_by_countries(ARRAY ['Afghanistan', 'Brazil', 'United States']);

-- ========================================================
-- Task 4. Create procedure language functions
-- ========================================================
-- Create a function that generates a list of movies available in stock based on a partial title match
-- (e.g., movies containing the word 'love' in their title).
-- The titles of these movies are formatted as '%...%', and if a movie with the specified title is not in stock,
-- return a message indicating that it was not found.
-- The function should produce the result set in the following format
-- (note: the 'row_num' field is an automatically generated counter field, starting from 1 and incrementing
-- for each entry, e.g., 1, 2, ..., 100, 101, ...).
--
--                     Query (example):select * from core.films_in_stock_by_title('%love%’);
-- |   Row_num   |   Film_title |    Language    | Customer_name |   Rental_date      |
-- |-------------|--------------|---------------|----------------|--------------------|
-- | 100         | Lovely film  | English       |   Customer 1  | 2006-02-01 15:09:03 |
-- | 101         | Love film    | English       |   Customer 2  | 2007-07-04 15:09:03 |

CREATE OR REPLACE FUNCTION public.films_in_stock_by_title(
    p_title_pattern TEXT
)
    RETURNS TABLE
            (
                row_num       BIGINT,
                film_title    TEXT,
                language      TEXT,
                customer_name TEXT,
                rental_date   TIMESTAMP
            )
    LANGUAGE plpgsql
AS
$$
DECLARE
    v_count   INTEGER;
    v_row_num BIGINT := 1;
    v_record  RECORD;
BEGIN
    -- Check if any films match the pattern
    SELECT COUNT(*)
    INTO v_count
    FROM film f
    WHERE f.title ILIKE p_title_pattern;

    -- If no films match the pattern, raise an exception with a message
    IF v_count = 0 THEN
        RAISE EXCEPTION 'No films found with title matching pattern "%"', p_title_pattern;
    END IF;

    -- Create a temporary table to store our results and add row numbers
    CREATE TEMP TABLE temp_results AS
    SELECT f.title::TEXT AS film_title,
           l.name::TEXT  AS language,
           CASE
               WHEN c.first_name IS NOT NULL THEN -- The name of the customer currently renting it
                   (c.first_name || ' ' || c.last_name)::TEXT
               ELSE
                   'Available'::TEXT -- or "Available" if not rented
               END       AS customer_name,
           CASE
               WHEN r.rental_date IS NOT NULL THEN
                   r.rental_date
               ELSE
                   NULL::TIMESTAMP
               END       AS rental_date
    FROM film f
             JOIN language l ON f.language_id = l.language_id
             JOIN inventory i ON f.film_id = i.film_id
             LEFT JOIN rental r ON i.inventory_id = r.inventory_id AND r.return_date IS NULL
             LEFT JOIN customer c ON r.customer_id = c.customer_id
    WHERE f.title ILIKE p_title_pattern
    ORDER BY f.title, r.rental_date;

    -- Check if we have any results
    GET DIAGNOSTICS v_count = ROW_COUNT; -- GET DIAGNOSTICS retrieves statistics about the most recently executed statement
    IF v_count = 0 THEN
        DROP TABLE temp_results;
        RAISE EXCEPTION 'Films matching pattern "%" exist but none are in stock', p_title_pattern;
    END IF;

    -- Return the results with row numbers
    FOR v_record IN SELECT * FROM temp_results
        LOOP
            row_num := v_row_num;
            film_title := v_record.film_title;
            language := v_record.language;
            customer_name := v_record.customer_name;
            rental_date := v_record.rental_date;

            RETURN NEXT;
            v_row_num := v_row_num + 1;
        END LOOP;

    -- Clean up the temporary table
    DROP TABLE temp_results;
END;
$$;

-- Example usage:
SELECT *
FROM public.films_in_stock_by_title('%love%');
-- DVD rental database typically has multiple inventory copies
-- , and query is showing each inventory item separately.
SELECT COUNT(*)
FROM film f
WHERE f.title ILIKE '%love%';

-- ========================================================
-- Task 5. Create procedure language functions
-- ========================================================
-- Create a procedure language function called 'new_movie' that takes a movie title as a parameter and
-- inserts a new movie with the given title in the film table. The function should generate a new unique film ID,
-- set the rental rate to 4.99, the rental duration to three days, the replacement cost to 19.99.
-- The release year and language are optional and by default should be current year and Klingon respectively.
-- The function should also verify that the language exists in the 'language' table. Then, ensure that no such function
-- has been created before; if so, replace it.

CREATE OR REPLACE FUNCTION public.new_movie(
    p_title TEXT,
    p_release_year INT DEFAULT EXTRACT(YEAR FROM CURRENT_DATE)::INT,
    p_language TEXT DEFAULT 'Klingon'
)
    RETURNS INT -- new created film ID
    LANGUAGE plpgsql
AS
$$
DECLARE
    v_language_id      INT;
    v_new_film_id      INT;
    v_existing_film_id INT;
    v_film_id_seq      TEXT;
BEGIN
    -- First check if a film with the same title already exists
    SELECT film_id
    INTO v_existing_film_id
    FROM film
    WHERE title = p_title;

    IF v_existing_film_id IS NOT NULL THEN
        RAISE NOTICE 'A film with title "%" already exists with ID: %', p_title, v_existing_film_id;
        RETURN v_existing_film_id; -- Return the existing film ID instead of creating a duplicate
    END IF;
    -- Check if the language exists
    SELECT language_id
    INTO v_language_id
    FROM language
    WHERE name = p_language;

    IF v_language_id IS NULL THEN
        -- If specifically Klingon is missing, add it
        IF p_language = 'Klingon' THEN
            -- Insert Klingon language using the sequence
            INSERT INTO language (name,
                                  last_update)
            VALUES ('Klingon',
                    NOW())
            RETURNING language_id INTO v_language_id;
            RAISE NOTICE 'Added Klingon language with ID: %', v_language_id;
        ELSE
            -- For other languages, still raise an exception
            RAISE EXCEPTION 'Language "%" does not exist in the language table', p_language;
        END IF;
    END IF;


    -- Insert the new film
    INSERT INTO film (title,
                      description,
                      release_year,
                      language_id,
                      rental_duration,
                      rental_rate,
                      length,
                      replacement_cost,
                      rating,
                      last_update,
                      special_features,
                      fulltext)
    VALUES (p_title,
            'New film added via new_movie function',
            p_release_year,
            v_language_id,
            3, -- rental_duration: 3 days
            4.99, -- rental_rate: $4.99
            90, -- default length: 90 minutes
            19.99, -- replacement_cost: $19.99
            'PG', -- default rating: PG
            NOW(), -- last_update: current timestamp
            ARRAY ['Deleted Scenes', 'Behind the Scenes']::text[], -- default special features
            to_tsvector('english', p_title) -- fulltext search vector
           )
    RETURNING film_id INTO v_new_film_id; -- Capture the new film_id


    RAISE NOTICE 'New film added: ID = %, Title = "%", Language = "%", Release Year = %',
        v_new_film_id, p_title, p_language, p_release_year;
    RETURN v_new_film_id;
END;
$$;

-- Example usage of function:
SELECT new_movie('The Great Adventure');
SELECT new_movie('Space Odyssey', 2030, 'English');
