SET sales_avg = (SELECT AVG(sales_amount) FROM w78);

SELECT *
FROM w78
WHERE sales_amount between $sales_avg - 50 and $sales_avg +50;