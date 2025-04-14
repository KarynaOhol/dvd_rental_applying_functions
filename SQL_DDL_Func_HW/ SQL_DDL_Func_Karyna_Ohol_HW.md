# Task 6. Prepare answers to the following questions

*=========================================================================================================================================*

*What operations do the following functions
perform: `film_in_stock`, `film_not_in_stock`, `inventory_in_stock`,`get_customer_balance`,`inventory_held_by_customer`,*

*`rewards_report`, `last_day`? You can find these functions in dvd_rental database.*

*=========================================================================================================================================*

## 1. `film_in_stock`

**Purpose:** Checks which copies of a specific film are currently in stock at a given store.

**Parameters:**

- `p_film_id` - The ID of the film to check
- `p_store_id` - The ID of the store to check
- `OUT p_film_count` - Output parameter that returns the count of available copies

**Operation:**

- Returns the inventory IDs of all copies of the specified film that are currently in stock at the specified store
- Uses the `inventory_in_stock` function to determine if each inventory item is available
- Also returns the total count of available copies as an OUT parameter

**Use case:** Useful when a customer wants to rent a specific film and you need to check if it's available at a
particular store.

## 2. `film_not_in_stock`

**Purpose:** Identifies which copies of a specific film are currently checked out (not in stock) at a given store.

**Parameters:**

- `p_film_id` - The ID of the film to check
- `p_store_id` - The ID of the store to check
- `OUT p_film_count` - Output parameter that returns the count of unavailable copies

**Operation:**

- Returns the inventory IDs of all copies of the specified film that are currently NOT in stock at the specified store
- Uses the `NOT inventory_in_stock` condition to determine which inventory items are unavailable
- Also returns the total count of unavailable copies as an OUT parameter

**Use case:** Useful for inventory management and tracking which copies are currently rented out.

## 3. `inventory_in_stock`

**Purpose:** Determines if a specific inventory item (DVD copy) is currently available for rental.

**Parameters:**

- `p_inventory_id` - The ID of the inventory item to check

**Returns:** A boolean value (TRUE if in stock, FALSE if not in stock)

**Operation:**

- Checks if there are any rental records for the inventory item
- If there are no rental records, the item is considered in stock (returns TRUE)
- If there are rental records, it checks if any of them have a NULL return_date (indicating the item is still rented
  out)
- Returns TRUE if all rental records have a return_date (item has been returned)
- Returns FALSE if any rental record has a NULL return_date (item is currently rented out)

**Use case:** This is a core utility function used by other functions to determine if a specific copy of a film is
available for rental.

## 4. `get_customer_balance`

**Purpose:** Calculates the current outstanding balance for a customer as of a specified date.

**Parameters:**

- `p_customer_id` - The ID of the customer
- `p_effective_date` - The date up to which to calculate the balance

**Returns:** A numeric value representing the customer's outstanding balance

**Operation:** The function calculates the balance based on four components:

- Rental Fees (`v_rentfees`):
    - Sums up the rental rates for all films rented by the customer up to the effective date
    - These are the basic fees for renting the videos initially

- Late Fees (`v_overfees`):
    - Calculates $1 per day for each day a rental is overdue beyond the film's rental duration
    - The calculation converts the difference between return date and rental date (minus the allowed rental duration) to
      days
    - This incentivizes customers to return films on time

- Replacement Costs:
    - According to the comments, there should be logic to charge the replacement cost if a film is overdue by more than
      2× its rental duration
    - However, this logic doesn't appear to be implemented in the actual function code

- Payments Made (`v_payments`):
    - Subtracts all payments made by the customer up to the effective date
    - This includes any previous payments toward their account

- The final balance is calculated as: rental fees + late fees - payments

**Use case:** This function provides a comprehensive financial overview of a customer's account as of any specified
date.

- Determining if a customer has outstanding fees before allowing new rentals
- Generating billing statements for customers
- Tracking revenue and accounts receivable
- Calculating late fees for overdue rentals

This function provides a comprehensive financial overview of a customer's account as of any specified date.

## 5. `inventory_held_by_customer`

**Purpose:** This function identifies which customer currently has a specific inventory item (DVD) rented out.

**Parameters:**

- `p_inventory_id` - The ID of the inventory item to check

**Returns:** The customer_id of the customer currently renting the item, or NULL if the item is in stock

**Operation:**

- Searching the rental table for a record matching the given inventory ID where the return_date is NULL
- A NULL return_date indicates that the item has been rented out but not yet returned
- If such a record is found, it returns the customer_id of the customer who has the item
- If no matching record is found (either because the item was never rented or has been returned), the function returns
  NULL

**Use case:** Useful for tracking down who has a specific DVD when it needs to be located.

- This is a simple but essential utility function in the DVD rental system that helps maintain accountability for the
  physical inventory of DVDs.

## 6. `rewards_report`

**Purpose:** This function generates a report of customers who qualify for the store's rewards program based on their
rental activity over the past month.

**Parameters:**

- `min_monthly_purchases` - Minimum number of rentals required per month to qualify
- `min_dollar_amount_purchased` - Minimum amount spent required to qualify

**Returns:** A set of records with customer information who qualify for rewards

**Security Level:**
Defined with security definer, meaning it executes with the privileges of the function creator (postgres), not the
calling user

**Operation:**

- Validation Checks:
    - Verifies that minimum monthly purchases parameter is greater than 0
    - Verifies that minimum dollar amount parameter is greater than $0.00
- Date Calculation:
    - Sets last_month_start to the first day of the month 3 months ago
    - Sets last_month_end to the last day of that month using the LAST_DAY function
- Temporary Storage:
    - Creates a temporary table tmpCustomer to store qualifying customer IDs
- Customer Qualification: Dynamically builds and executes SQL to find customers who:
    - Made payments between the start and end dates
    - Spent more than the minimum dollar amount specified
    - Made more than the minimum number of purchases specified
- Report Generation:
    - Uses a loop to return complete customer records for all qualifying customers
    - The result is a set of full customer records that can be used by the calling application
- Cleanup: Drops the temporary table before finishing

**Use case:** This function helps the DVD rental store recognize and reward its most valuable customers based on both
frequency of rentals and total spend.

## 7. `last_day`

**Purpose:** Calculates the last day of the month for a given date.

**Parameters:**

- A timestamp with time zone value representing any date

**Returns:** A date representing the last day of the month for the input date

**Attributes:**

- immutable - The function always returns the same output for the same input
- strict - The function returns NULL if any input is NULL

**Operation:** The function uses a CASE statement with two conditions:

- For December (month 12):
    - Takes the next year's January 1st and subtracts 1 day
    - Example: For Dec 15, 2024 → Jan 1, 2025 - 1 day = Dec 31, 2024
- For all other months:
    - Takes the first day of the next month and subtracts 1 day
    - Example: For April 10, 2024 → May 1, 2024 - 1 day = April 30, 2024
- The function converts between date types as needed and uses PostgreSQL's concatenation operator (||) to construct date
  strings.

**Use case:** A utility function used in various date calculations, particularly for end-of-month reporting, billing
cycles, and due date calculations.

*=========================================================================================================================================*

*Why does `rewards_report` function return 0 rows? Correct and recreate the function, so that it's able to return rows
properly.*

*=========================================================================================================================================*

### Problem Analysis

The original `rewards_report` function in the DVD rental database returns 0 rows because it's searching for customer
payment data in a date range that doesn't match the actual data in the database. Specifically:

1. The function looks for payments from 3 months ago (from current date)

```sql
last_month_start := CURRENT_DATE - '3 month'::interval;
```

2. The DVD rental database contains historical data from 2005,2017(and 2 quater 2025 added to check task1)
3. When the function searches for recent payment data, it finds no matching records
4. This results in an empty result set, even when the minimum purchase requirements are set very low

## Side-by-Side Comparison

| Component            | Original Function                                             | Fixed Function                                                                                                                                                        | Explanation                                                                                                           |
|----------------------|---------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------|
| **Date Calculation** | ```last_month_start := CURRENT_DATE - '3 month'::interval;``` | ```SELECT DATE_TRUNC('month', MIN(payment_date))::DATE, LAST_DAY(DATE_TRUNC('month', MAX(payment_date))::DATE) INTO last_month_start, last_month_end FROM payment;``` | Instead of looking 3 months back from current date, we dynamically find the actual payment date range in the database |
| **Debugging**        | *No error reporting*                                          | ```RAISE NOTICE 'Analyzing rewards for period: % to %', last_month_start, last_month_end;```                                                                          | Added notices to track execution and help debug                                                                       |
| **Temp Table**       | Simple creation                                               | ```DROP TABLE IF EXISTS tmpCustomer;``` before creation                                                                                                               | Added cleanup to prevent errors if the function is run multiple times                                                 |

## Complete Function Comparison

### Original Function

```sql
CREATE FUNCTION rewards_report(min_monthly_purchases integer, min_dollar_amount_purchased numeric)
    RETURNS SETOF customer
    SECURITY DEFINER
    LANGUAGE plpgsql
AS
$$
DECLARE
    last_month_start DATE;
    last_month_end   DATE;
    rr               RECORD;
    tmpSQL           TEXT;
BEGIN
    /* Some sanity checks... */
    IF min_monthly_purchases = 0 THEN
        RAISE EXCEPTION 'Minimum monthly purchases parameter must be > 0';
    END IF;
    IF min_dollar_amount_purchased = 0.00 THEN
        RAISE EXCEPTION 'Minimum monthly dollar amount purchased parameter must be > $0.00';
    END IF;

    last_month_start := CURRENT_DATE - '3 month'::interval;
    last_month_start :=
            to_date((extract(YEAR FROM last_month_start) || '-' || extract(MONTH FROM last_month_start) || '-01'),
                    'YYYY-MM-DD');
    last_month_end := LAST_DAY(last_month_start);

    /*
    Create a temporary storage area for Customer IDs.
    */
    CREATE TEMPORARY TABLE tmpCustomer
    (
        customer_id INTEGER NOT NULL PRIMARY KEY
    );

    /*
    Find all customers meeting the monthly purchase requirements
    */
    tmpSQL := 'INSERT INTO tmpCustomer (customer_id)
        SELECT p.customer_id
        FROM payment AS p
        WHERE DATE(p.payment_date) BETWEEN ' || quote_literal(last_month_start) || ' AND ' ||
              quote_literal(last_month_end) || '
        GROUP BY customer_id
        HAVING SUM(p.amount) > ' || min_dollar_amount_purchased || '
        AND COUNT(customer_id) > ' || min_monthly_purchases;

    EXECUTE tmpSQL;

    /*
    Output ALL customer information of matching rewardees.
    Customize output as needed.
    */
    FOR rr IN EXECUTE 'SELECT c.* FROM tmpCustomer AS t INNER JOIN customer AS c ON t.customer_id = c.customer_id'
        LOOP
            RETURN NEXT rr;
        END LOOP;

    /* Clean up */
    tmpSQL := 'DROP TABLE tmpCustomer';
    EXECUTE tmpSQL;

    RETURN;
END
$$;
```

### Fixed Function

```sql
create function rewards_report(
    min_monthly_purchases integer,
    min_dollar_amount_purchased numeric) returns SETOF customer
    security definer
    language plpgsql
as
$$
DECLARE
    last_month_start DATE;
    last_month_end   DATE;
    rr               RECORD;
    tmpSQL           TEXT;
BEGIN

    /* Some sanity checks... */
    IF min_monthly_purchases = 0 THEN
        RAISE EXCEPTION 'Minimum monthly purchases parameter must be > 0';
    END IF;
    IF min_dollar_amount_purchased = 0.00 THEN
        RAISE EXCEPTION 'Minimum monthly dollar amount purchased parameter must be > $0.00';
    END IF;

    --     last_month_start := CURRENT_DATE - '3 month'::interval;
--     last_month_start :=
--             to_date((extract(YEAR FROM last_month_start) || '-' || extract(MONTH FROM last_month_start) || '-01'),
--                     'YYYY-MM-DD');
--     last_month_end := LAST_DAY(last_month_start);

    SELECT DATE_TRUNC('month', MIN(payment_date))::DATE,
           LAST_DAY(DATE_TRUNC('month', MAX(payment_date))::DATE)
    INTO
        last_month_start,
        last_month_end
    FROM payment;
    RAISE NOTICE 'Analyzing rewards for period: % to %', last_month_start, last_month_end;

    /*
    Create a temporary storage area for Customer IDs.
    */
    CREATE TEMPORARY TABLE tmpCustomer
    (
        customer_id INTEGER NOT NULL PRIMARY KEY
    );

    /*
    Find all customers meeting the monthly purchase requirements
    */

    tmpSQL := 'INSERT INTO tmpCustomer (customer_id)
        SELECT p.customer_id
        FROM payment AS p
        WHERE DATE(p.payment_date) BETWEEN ' || quote_literal(last_month_start) || ' AND ' ||
              quote_literal(last_month_end) || '
        GROUP BY customer_id
        HAVING SUM(p.amount) > ' || min_dollar_amount_purchased || '
        AND COUNT(customer_id) > ' || min_monthly_purchases;

    EXECUTE tmpSQL;

    /*
    Output ALL customer information of matching rewardees.
    Customize output as needed.
    */
    FOR rr IN EXECUTE 'SELECT c.* FROM tmpCustomer AS t INNER JOIN customer AS c ON t.customer_id = c.customer_id'
        LOOP
            RETURN NEXT rr;
        END LOOP;


    /* Clean up */
    DROP TABLE IF EXISTS tmpCustomer;

    tmpSQL := 'DROP TABLE tmpCustomer';
    EXECUTE tmpSQL;

    RETURN;
END
$$;
```

## Usage Example

To use either function with reasonable parameters:

```sql
-- Using the fixed function 
SELECT *
FROM rewards_report(1, 1);
```

*=========================================================================================================================================*

*Is there any function that can potentially be removed from the dvd_rental codebase? If so, which one and why?*

*=========================================================================================================================================*

## `film_not_in_stock`

If the critical functionality failure in `rewards_report` has been fixed (addressing the date range issue),
then `film_not_in_stock` would be the better candidate for removal from the DVD rental database.

**Explanetion**

- *Pure Redundancy:* `film_not_in_stock `essentially performs the exact inverse operation of `film_in_stock`, with
  almost identical code.
  It's simply applying a NOT to the same condition.
- *Easy Consolidation:* The functionality of `film_not_in_stock` could be completely incorporated into `film_in_stock`
  with an additional boolean parameter (e.g., p_in_stock BOOLEAN DEFAULT TRUE).
- *Maintenance Overhead:* Having two separate functions that maintain nearly identical logic creates unnecessary
  maintenance burden
  any bug fix or enhancement to one function would need to be replicated in the other.

**A good approach would be to:**

- Remove film_not_in_stock
- Enhance film_in_stock to handle both cases with a parameter:

```sql
CREATE OR REPLACE FUNCTION film_inventory_status(
    p_film_id INTEGER,
    p_store_id INTEGER,
    p_find_in_stock BOOLEAN DEFAULT TRUE,
    OUT p_film_count INTEGER
) RETURNS SETOF INTEGER
```

*=========================================================================================================================================*

*The ‘get_customer_balance’ function describes the business requirements for calculating the client balance.*

*Unfortunately, not all of them are implemented in this function. Try to change function using the requirements from the
comments.*

*=========================================================================================================================================*

- Added the missing replacement cost calculation for films that are more than twice their rental duration overdue
- Improved the overfees calculation to handle both returned and non-returned rentals
- Changed `v_overfees `to DECIMAL(5,2) for consistency with other monetary values
- Added a new v_replacementfees variable to track replacement costs separately
- Added the replacement fees to the final return calculation

### Fixed Function

```sql
-- Improved get_customer_balance function to implement all requirements from comments
CREATE OR REPLACE FUNCTION get_customer_balance(
    p_customer_id INTEGER,
    p_effective_date TIMESTAMP WITH TIME ZONE
)
    RETURNS NUMERIC
    LANGUAGE plpgsql
AS
$$
    --#OK, WE NEED TO CALCULATE THE CURRENT BALANCE GIVEN A CUSTOMER_ID AND A DATE
    --#THAT WE WANT THE BALANCE TO BE EFFECTIVE FOR. THE BALANCE IS:
    --#   1) RENTAL FEES FOR ALL PREVIOUS RENTALS
    --#   2) ONE DOLLAR FOR EVERY DAY THE PREVIOUS RENTALS ARE OVERDUE
    --#   3) IF A FILM IS MORE THAN RENTAL_DURATION * 2 OVERDUE, CHARGE THE REPLACEMENT_COST
    --#   4) SUBTRACT ALL PAYMENTS MADE BEFORE THE DATE SPECIFIED
DECLARE
    v_rentfees        DECIMAL(5, 2); --#FEES PAID TO RENT THE VIDEOS INITIALLY
    v_overfees        DECIMAL(5, 2); --#LATE FEES FOR PRIOR RENTALS
    v_replacementfees DECIMAL(7, 2); --#REPLACEMENT FEES FOR VERY OVERDUE FILMS
    v_payments        DECIMAL(5, 2); --#SUM OF PAYMENTS MADE PREVIOUSLY
BEGIN
    -- 1) Rental fees for all previous rentals
    SELECT COALESCE(SUM(film.rental_rate), 0)
    INTO v_rentfees
    FROM film,
         inventory,
         rental
    WHERE film.film_id = inventory.film_id
      AND inventory.inventory_id = rental.inventory_id
      AND rental.rental_date <= p_effective_date
      AND rental.customer_id = p_customer_id;

    -- 2) One dollar for every day the previous rentals are overdue
    -- Note: Changed to DECIMAL(5,2) to match other monetary values and to handle partial days if needed
    SELECT COALESCE(SUM(
                            CASE
                                -- For rentals that have been returned
                                WHEN rental.return_date IS NOT NULL AND
                                     (rental.return_date - rental.rental_date) >
                                     (film.rental_duration * '1 day'::interval)
                                    THEN
                                    EXTRACT(epoch FROM ((rental.return_date - rental.rental_date) -
                                                        (film.rental_duration * '1 day'::interval)))::DECIMAL / 86400

                                -- For rentals that have not been returned yet (using effective date as the return date for calculation)
                                WHEN rental.return_date IS NULL AND
                                     (p_effective_date - rental.rental_date) >
                                     (film.rental_duration * '1 day'::interval)
                                    THEN
                                    EXTRACT(epoch FROM ((p_effective_date - rental.rental_date) -
                                                        (film.rental_duration * '1 day'::interval)))::DECIMAL / 86400

                                ELSE 0
                                END), 0)
    INTO v_overfees
    FROM rental,
         inventory,
         film
    WHERE film.film_id = inventory.film_id
      AND inventory.inventory_id = rental.inventory_id
      AND rental.rental_date <= p_effective_date
      AND rental.customer_id = p_customer_id;

    -- 3) If a film is more than rental_duration * 2 overdue, charge the replacement_cost
    SELECT COALESCE(SUM(
                            CASE
                                -- For rentals that have been returned
                                WHEN rental.return_date IS NOT NULL AND
                                     (rental.return_date - rental.rental_date) >
                                     (film.rental_duration * 2 * '1 day'::interval)
                                    THEN
                                    film.replacement_cost

                                -- For rentals that have not been returned yet (using effective date)
                                WHEN rental.return_date IS NULL AND
                                     (p_effective_date - rental.rental_date) >
                                     (film.rental_duration * 2 * '1 day'::interval)
                                    THEN
                                    film.replacement_cost

                                ELSE 0
                                END), 0)
    INTO v_replacementfees
    FROM rental,
         inventory,
         film
    WHERE film.film_id = inventory.film_id
      AND inventory.inventory_id = rental.inventory_id
      AND rental.rental_date <= p_effective_date
      AND rental.customer_id = p_customer_id;

    -- 4) Subtract all payments made before the date specified
    SELECT COALESCE(SUM(payment.amount), 0)
    INTO v_payments
    FROM payment
    WHERE payment.payment_date <= p_effective_date
      AND payment.customer_id = p_customer_id;

    -- Return the final balance calculation
    RETURN v_rentfees + v_overfees + v_replacementfees - v_payments;
END
$$;
```

## Usage Example

To use either function with reasonable parameters:

```sql
SELECT get_customer_balance(1, CURRENT_TIMESTAMP);
SELECT get_customer_balance(1, '2005-08-01'::TIMESTAMP);
```

*=========================================================================================================================================*

* How do ‘group_concat’ and ‘_group_concat’ functions work? (database creation script might help) Where are they used?*

*=========================================================================================================================================*

The `group_concat` aggregate function and its supporting `_group_concat` function work together to concatenate text
values
from multiple rows into a single string, similar to PostgreSQL's built-in `string_agg` function.

**`_group_concat` Function** This is a helper function that:

- Takes two text parameters
- Returns the first if the second is NULL
- Returns the second if the first is NULL
- Otherwise, concatenates them with a comma and space separator
- Is marked as immutable since it always returns the same output for the same inputs

**`group_concat` Aggregate**

- Uses _group_concat as its state transition function (`sfunc`)
- Maintains a running text value as its state (`stype`)
- Incrementally builds a comma-separated list by repeatedly calling `_group_concat`

**Usage in the DVD Rental Database**

##### The function `group_concat` was created but isn't currently being used in any database objects( checked pg_views,pg_proc,pg_matviews,pg_trigger)

This function would typically be used when you want to combine text values from multiple rows. For example:

```sql
-- List all actors for each film
SELECT f.title,
       group_concat(a.first_name || ' ' || a.last_name) AS actors
FROM film f
         JOIN film_actor fa ON f.film_id = fa.film_id
         JOIN actor a ON fa.actor_id = a.actor_id
GROUP BY f.title;
```

This would produce results like:

| title | actors |
|-------|--------|
| "ACADEMY DINOSAUR" | "PENELOPE GUINESS, CHRISTIAN GABLE, LUCILLE TRACY, SANDRA PECK, ..." |
| "ACE GOLDFINGER" | "BOB FAWCETT, MINNIE ZELLWEGER, SEAN GUINESS, CHRIS DEPP" |
| "ADAPTATION HOLES" | "NICK WAHLBERG, BOB FAWCETT, CAMERON STREEP" |

*=========================================================================================================================================*

*What does ‘last_updated’ function do? Where is it used?*

*=========================================================================================================================================*

The `last_updated` function in the DVD rental database is a trigger function designed to automatically update the `last_update` column of tables 
whenever a row is inserted or modified.

**The function `last_updated`:**
- Is defined as a trigger function (returns trigger)
- Sets the `last_update` column of the NEW row to the current timestamp 
- Returns the modified NEW row to be saved to the database

**Where `last_updated` used**
- This function is likely attached as a trigger to many tables in the database that contain a `last_update` column. 
- 
**To find all the tables that use this trigger with the following query:**
```sql
SELECT
    event_object_table AS table_name,
    trigger_name,
    event_manipulation AS trigger_event,
    action_timing AS trigger_timing
FROM
    information_schema.triggers
WHERE
    action_statement LIKE '%last_updated%';
```
| table\_name | trigger\_name | trigger\_event | trigger\_timing |
| :--- | :--- | :--- | :--- |
| actor | last\_updated | UPDATE | BEFORE |
| address | last\_updated | UPDATE | BEFORE |
| category | last\_updated | UPDATE | BEFORE |
| city | last\_updated | UPDATE | BEFORE |
| country | last\_updated | UPDATE | BEFORE |
| customer | last\_updated | UPDATE | BEFORE |
| film | last\_updated | UPDATE | BEFORE |
| film\_actor | last\_updated | UPDATE | BEFORE |
| film\_category | last\_updated | UPDATE | BEFORE |
| inventory | last\_updated | UPDATE | BEFORE |
| language | last\_updated | UPDATE | BEFORE |
| rental | last\_updated | UPDATE | BEFORE |
| staff | last\_updated | UPDATE | BEFORE |
| store | last\_updated | UPDATE | BEFORE |

*=========================================================================================================================================*

*What is `tmpSQL` variable for in `rewards_report` function? Can this function be recreated without EXECUTE statement and dynamic SQL? Why?*

*=========================================================================================================================================*

In the `rewards_report` function, the `tmpSQL` variable is used to store SQL statements as text strings that are then executed dynamically 
using the EXECUTE statement. This technique is called *dynamic SQL*.

- It first stores the INSERT statement that populates the temporary table with customer IDs
- Later it stores the DROP TABLE statement for cleanup

The function *can definitely be recreated without dynamic SQL*, and there are good reasons to do so:
- Security: Dynamic SQL can be vulnerable to SQL injection if not properly handled (though in this case, the risk is minimal since parameters are properly quoted)
- Performance: The PostgreSQL query planner can optimize static SQL better than dynamic SQL
- Readability: Static SQL is easier to read and maintain than string-concatenated SQL
- Debugging: Errors in static SQL are caught at function creation time, whereas dynamic SQL errors only appear at runtime

```sql
CREATE OR REPLACE FUNCTION rewards_report(
    min_monthly_purchases INTEGER,
    min_dollar_amount_purchased NUMERIC
) 
RETURNS SETOF customer
LANGUAGE plpgsql
AS $$
DECLARE
    last_month_start DATE;
    last_month_end DATE;
BEGIN
    /* Sanity checks */
    IF min_monthly_purchases = 0 THEN
        RAISE EXCEPTION 'Minimum monthly purchases parameter must be > 0';
    END IF;
    IF min_dollar_amount_purchased = 0.00 THEN
        RAISE EXCEPTION 'Minimum monthly dollar amount purchased parameter must be > $0.00';
    END IF;
    
    /* Get date range from actual payment data */
    SELECT 
        DATE_TRUNC('month', MIN(payment_date))::DATE,
        LAST_DAY(DATE_TRUNC('month', MAX(payment_date))::DATE)
    INTO
        last_month_start,
        last_month_end
    FROM payment;
    
    /* Return qualifying customers directly */
    RETURN QUERY
    SELECT c.*
    FROM customer c
    WHERE c.customer_id IN (
        SELECT p.customer_id
        FROM payment AS p
        WHERE DATE(p.payment_date) BETWEEN last_month_start AND last_month_end
        GROUP BY customer_id
        HAVING SUM(p.amount) > min_dollar_amount_purchased
        AND COUNT(customer_id) > min_monthly_purchases
    );
END
$$;
```
This version directly returns the query results without using temporary tables or dynamic SQL, making it simpler, more secure, and potentially faster.
