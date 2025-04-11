-- Advanced Data Management D326

-- Function to transform timestamp to month 
CREATE OR REPLACE FUNCTION get_month(payment_date TIMESTAMP) 
RETURNS VARCHAR(9) 
LANGUAGE plpgsql 
AS $$ 
BEGIN 
RETURN to_char(payment_date, 'Month'); 
END; $$;

-- Test function 
SELECT get_month('2025-08-25');

-- Drop tables 
DROP TABLE detailed_table 
DROP TABLE summary_table

-- Create detailed table 
CREATE TABLE detailed_table( 
	store_id SMALLINT, 
	payment_id INT, 
	month VARCHAR(9), 
	payment_date TIMESTAMP, 
	amount MONEY );

-- Create summary table 
CREATE TABLE summary_table( 
	store_id SMALLINT, 
	month VARCHAR(9), 
	total_rentals INT, 
	total_sales MONEY );

-- Verify table creation 
SELECT * FROM detailed_table 
SELECT * FROM summary_table

-- Trigger to update summary table when changes are made to detailed table 
CREATE OR REPLACE FUNCTION summary_trigger() 
RETURNS TRIGGER 
LANGUAGE plpgsql 
AS $$ 
BEGIN 
	TRUNCATE summary_table; 
	INSERT INTO summary_table 
		SELECT store_id, month, 
			COUNT(payment_id), 
			SUM(amount) 
	FROM detailed_table 
	GROUP BY store_id, month 
	ORDER BY store_id; 
RETURN NULL; 
END; $$;

CREATE TRIGGER update_summary 
AFTER INSERT OR DELETE ON detailed_table 
FOR EACH STATEMENT EXECUTE FUNCTION summary_trigger();

-- Populate detailed table 
TRUNCATE detailed_table; 
INSERT INTO detailed_table 
	SELECT 
		i.store_id, 
		p.payment_id, 
		get_month(p.payment_date), 
		p.payment_date::date, 
		p.amount::money 
	FROM payment AS p 
	INNER JOIN rental r ON p.rental_id = r.rental_id 
	INNER JOIN inventory i ON r.inventory_id = i.inventory_id 
	ORDER BY p.payment_id;

-- Verify data population 
SELECT * FROM detailed_table -- 14596 rows 
SELECT * FROM summary_table -- 8 rows

-- Procedure to refresh data in both tables 
CREATE OR REPLACE PROCEDURE tables_refresh() 
LANGUAGE plpgsql 
AS $$ 
BEGIN 
	TRUNCATE detailed_table; 
	INSERT INTO detailed_table 
		SELECT 
			i.store_id, 
			p.payment_id, 
			get_month(p.payment_date) AS month, 
			p.payment_date::date AS payment_date, 
			p.amount::money AS amount 
	FROM payment AS p 
	INNER JOIN rental AS r ON p.rental_id = r.rental_id 
	INNER JOIN inventory AS i ON r.inventory_id = i.inventory_id 
	ORDER BY p.payment_id DESC; 
END; $$;

-- Call the procedure 
CALL tables_refresh();

-- Verify data population 
SELECT * FROM detailed_table 
SELECT * FROM summary_table

-- Verify trigger 
SELECT COUNT(*) FROM detailed_table -- 14596 rows 
SELECT COUNT(*) FROM summary_table -- 8 rows

-- Add data to detailed table, count should increase by 1 
INSERT INTO detailed_table 
VALUES(3, 999999, 'March', '2025-03-03', 5.99);

-- Verify trigger 
SELECT COUNT(*) FROM detailed_table -- 14597 rows 
SELECT COUNT(*) FROM summary_table -- 9 rows

-- Remove data from detailed table, count should decrease by 1 
DELETE FROM detailed_table WHERE store_id = 3 RETURNING *;

-- Verify trigger 
SELECT COUNT(*) FROM detailed_table -- 14596 rows 
SELECT COUNT(*) FROM summary_table -- 8 rows
