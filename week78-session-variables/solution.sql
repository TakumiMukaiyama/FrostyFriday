SET sales_avg = (SELECT AVG(sales_amount) FROM w78);

SELECT *
FROM w78
WHERE sales_amount between $sales_avg - 50 and $sales_avg +50;

-- Set multiple session variables for dynamic analysis
SET sales_avg = (SELECT AVG(sales_amount) FROM w78);
SET sales_stddev = (SELECT STDDEV(sales_amount) FROM w78);
SET percentile_75 = (SELECT PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY sales_amount) FROM w78);
SET min_quantity_threshold = 5;
SET date_range_days = 90;

-- Complex query using multiple session variables with window functions and conditional logic
WITH sales_stats AS (
    SELECT 
        sales_id,
        product_name,
        quantity_sold,
        sales_date,
        sales_amount,
        -- Calculate z-score using session variables
        (sales_amount - $sales_avg) / NULLIF($sales_stddev, 0) AS z_score,
        -- Rank products by sales amount
        RANK() OVER (PARTITION BY product_name ORDER BY sales_amount DESC) AS product_rank,
        -- Calculate running total
        SUM(sales_amount) OVER (
            PARTITION BY product_name 
            ORDER BY sales_date 
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS running_total
    FROM w78
    WHERE 
        -- Filter by date range using session variable
        sales_date >= DATEADD('day', -$date_range_days, CURRENT_DATE())
        -- Filter by quantity threshold using session variable
        AND quantity_sold >= $min_quantity_threshold
),
filtered_sales AS (
    SELECT 
        *,
        -- Flag outliers using session variables
        CASE 
            WHEN ABS(z_score) > 2 THEN 'Outlier'
            WHEN sales_amount > $percentile_75 THEN 'High Value'
            WHEN sales_amount BETWEEN $sales_avg - $sales_stddev AND $sales_avg + $sales_stddev THEN 'Normal'
            ELSE 'Low Value'
        END AS sales_category
    FROM sales_stats
    WHERE 
        -- Dynamic filtering based on session variables
        sales_amount BETWEEN $sales_avg - (2 * $sales_stddev) AND $sales_avg + (2 * $sales_stddev)
)
SELECT 
    product_name,
    sales_category,
    COUNT(*) AS transaction_count,
    SUM(sales_amount) AS total_sales,
    AVG(sales_amount) AS avg_sales,
    MIN(sales_amount) AS min_sales,
    MAX(sales_amount) AS max_sales,
    -- Compare against session variable thresholds
    SUM(CASE WHEN sales_amount > $sales_avg THEN 1 ELSE 0 END) AS above_avg_count,
    SUM(CASE WHEN sales_amount > $percentile_75 THEN 1 ELSE 0 END) AS above_75th_percentile_count,
    -- Calculate percentage of total
    ROUND(SUM(sales_amount) * 100.0 / (SELECT SUM(sales_amount) FROM filtered_sales), 2) AS pct_of_total
FROM filtered_sales
GROUP BY product_name, sales_category
HAVING 
    -- Dynamic HAVING clause using session variables
    AVG(sales_amount) > $sales_avg * 0.8
ORDER BY total_sales DESC;