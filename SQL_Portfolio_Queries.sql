--  first grab customer codes for Croma india

SELECT * FROM dim_customer WHERE customer like "%croma%" AND market="india";


-- Let's get all the sales transaction data from fact_sales_monthly table for the customer(croma: 90002002) in the fiscal_year 2021.
-- Ultimately, we will replace this method with a function, but this is the overarching query logic we want to use.

SELECT * FROM fact_sales_monthly 
	WHERE 
		customer_code=90002002 AND
		YEAR(DATE_ADD(date, INTERVAL 4 MONTH))=2021 
	ORDER BY date asc
	LIMIT 100000;
    
    
-- This isn't exactly ideal, so lets turn it into a function! This will be stored in the functions table, but I will show it here as well.
-- I had to add the ## to the beginning and ends of the function, as MySQL wasn't fond of putting a function here.

## CREATE FUNCTION `get_fiscal_year`(calendar_date DATE) 
	RETURNS int
    	DETERMINISTIC
	## BEGIN
        	DECLARE fiscal_year INT;
        	SET fiscal_year = YEAR(DATE_ADD(calendar_date, INTERVAL 4 MONTH));
        	RETURN fiscal_year;
	## END
    
    
-- Now, we can add our function to our original query!

SELECT * FROM fact_sales_monthly 
	WHERE 
            customer_code=90002002 AND
            get_fiscal_year(date)=2021 
	ORDER BY date asc
	LIMIT 100000;
    

-- Next, let's focus on pulling our gross sales report.
-- This will get us our product info.

SELECT s.date, s.product_code, p.product, p.variant, s.sold_quantity 
	FROM fact_sales_monthly s
	JOIN dim_product p
        ON s.product_code=p.product_code
	WHERE 
            customer_code=90002002 AND 
    	    get_fiscal_year(date)=2021     
	LIMIT 1000000;


-- To get our gross price, we need to join with dim_product and fact_gross_price.

SELECT 
    	    s.date, 
            s.product_code, 
            p.product, 
            p.variant, 
            s.sold_quantity, 
            g.gross_price,
            ROUND(s.sold_quantity*g.gross_price,2) as gross_price_total
	FROM fact_sales_monthly s
	JOIN dim_product p
            ON s.product_code=p.product_code
	JOIN fact_gross_price g
            ON g.fiscal_year=get_fiscal_year(s.date)
    	AND g.product_code=s.product_code
	WHERE 
    	    customer_code=90002002 AND 
            get_fiscal_year(s.date)=2021     
	LIMIT 1000000;


-- Now, lets generate our monthly gross sales report for all the years.

SELECT 
		s.date, 
		SUM(ROUND(s.sold_quantity*g.gross_price,2)) as monthly_sales
	FROM fact_sales_monthly s
	JOIN fact_gross_price g
        ON g.fiscal_year=get_fiscal_year(s.date) AND g.product_code=s.product_code
	WHERE 
             customer_code=90002002
	GROUP BY date;
    
    
    
    ------------------ STORED PROCEDURES ------------------------------
    
    -- Similarly to the function from earlier, I'm going to place ## around the BEGIN and END arguments, or MySQL will throw a fit
    
    
    -- We can generate a monhtly gross sales report for ANY customer if we create a stored procedure for it!
    
CREATE PROCEDURE `get_monthly_gross_sales_for_customer`(
        	in_customer_codes TEXT
	)
	
    ## BEGIN
        	SELECT 
                    s.date, 
                    SUM(ROUND(s.sold_quantity*g.gross_price,2)) as monthly_sales
        	FROM fact_sales_monthly s
        	JOIN fact_gross_price g
               	    ON g.fiscal_year=get_fiscal_year(s.date)
                    AND g.product_code=s.product_code
        	WHERE 
                    FIND_IN_SET(s.customer_code, in_customer_codes) > 0
        	GROUP BY s.date
        	ORDER BY s.date DESC;
	## END


-- We can also create a stored procedure that allows us to retrieve a market badge of Gold or Silver depending on the sold quantity. Greater than 5 million would be Gold, less would be Silver

CREATE PROCEDURE `get_market_badge`(
        	IN in_market VARCHAR(45),
        	IN in_fiscal_year YEAR,
        	OUT out_level VARCHAR(45)
	)
	## BEGIN
             DECLARE qty INT DEFAULT 0;
    
    	     # Default market is India
    	     IF in_market = "" THEN
                  SET in_market="India";
             ## END IF;
    
    	     # Retrieve total sold quantity for a given market in a given year
             SELECT 
                  SUM(s.sold_quantity) INTO qty
             FROM fact_sales_monthly s
             JOIN dim_customer c
             ON s.customer_code=c.customer_code
             WHERE 
                  get_fiscal_year(s.date)=in_fiscal_year AND
                  c.market=in_market;
        
             # Determine Gold vs Silver status
             IF qty > 5000000 THEN
                  SET out_level = 'Gold';
             ELSE
                  SET out_level = 'Silver';
             END IF;
	## END












    
    
