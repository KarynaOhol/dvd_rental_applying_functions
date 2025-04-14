# PostgreSQL DVD Rental Database - Data Definition and Function Exercises

## Overview
This repository contains SQL scripts for a series of advanced PostgreSQL functions, views, and procedures implemented for the DVD Rental sample database. The scripts demonstrate various SQL techniques including view creation, query language functions, and procedural language functions.

## Database Context
These functions work with the PostgreSQL DVD Rental database, which models a DVD rental store with tables for films, customers, actors, payments and more.

## Features

### 1. Quarterly Sales Revenue by Category
- **View**: `sales_revenue_by_category_qtr`
- **Function**: `get_sales_revenue_by_category_qtr(p_year INT, p_quarter INT)`
- **Description**: Shows film categories and their total sales revenue for a specified quarter and year.
- **Usage Example**:
  ```sql
  -- Using the view (current quarter and year)
  SELECT * FROM public.sales_revenue_by_category_qtr;
  
  -- Using the function with specific parameters
  SELECT * FROM public.get_sales_revenue_by_category_qtr(2017, 1);
  
  -- Using named parameters
  SELECT * FROM public.get_sales_revenue_by_category_qtr(p_quarter := 2);
  ```

### 2. Most Popular Films by Country
- **Function**: `most_popular_films_by_countries(p_countries TEXT[])`
- **Description**: Returns the most rented films for each specified country.
- **Usage Example**:
  ```sql
  SELECT * FROM public.most_popular_films_by_countries(
    ARRAY['Afghanistan', 'Brazil', 'United States']
  );
  ```
- **Output**: Returns country, film title, rating, language, length, and release year.

### 3. Films in Stock by Title Pattern
- **Function**: `films_in_stock_by_title(p_title_pattern TEXT)`
- **Description**: Lists all films matching a title pattern, showing availability status.
- **Usage Example**:
  ```sql
  SELECT * FROM public.films_in_stock_by_title('%love%');
  ```
- **Output**: Returns row number, film title, language, customer name (if rented), and rental date.

### 4. New Movie Creation
- **Function**: `new_movie(p_title TEXT, p_release_year INT, p_language TEXT)`
- **Description**: Inserts a new film with specified parameters and default values.
- **Usage Example**:
  ```sql
  -- With default values (current year, Klingon language)
  SELECT new_movie('The Great Adventure');
  
  -- With custom values
  SELECT new_movie('Space Odyssey', 2030, 'English');
  ```
- **Default Values**:
  - Release year: Current year
  - Language: Klingon (automatically added if not present)
  - Rental rate: $4.99
  - Rental duration: 3 days
  - Replacement cost: $19.99

## Technical Implementation Details

### View Implementation
- The view filters data using `EXTRACT()` functions on date fields
- Uses `HAVING` clause to filter for categories with sales
- Orders results by descending revenue

### Function Types
- **SQL Language Functions**: Simple, query-based functions (Task 2)
- **PL/pgSQL Functions**: More complex functions with variables, loops, and error handling (Tasks 3-5)

### Advanced Techniques Used
- Common Table Expressions (CTEs)
- Dynamic SQL (EXECUTE format())
- Temporary tables
- Exception handling
- Query optimization through indexing
- Row numbering
- Parameter validation

## Installation and Usage
1. Ensure you have the PostgreSQL DVD Rental sample database installed
2. Run the script file to create all functions and views
3. Test each function with the example queries provided

## Error Handling
All functions include proper error handling:
- Validation for non-existent languages
- Checks for films not in stock
- Appropriate error messages with RAISE EXCEPTION
