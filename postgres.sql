

CREATE TABLE fact_sale (
    sale_sk        BIGSERIAL PRIMARY KEY,
    date_sk        BIGINT,
    customer_sk    BIGINT,
    station_sk     BIGINT,
    product_sk     BIGINT,
    payment_sk     BIGINT,
    employee_sk    BIGINT,
    sale_id        VARCHAR(50),
    quantity       NUMERIC(10,3),
    unit_price     NUMERIC(10,4),
    total_amount   NUMERIC(18,2)
);

CREATE TABLE dim_customer (
    customer_sk    BIGSERIAL PRIMARY KEY,
    customer_id    VARCHAR(50),
    full_name      VARCHAR(150),
    birth_date     DATE,
    phone          VARCHAR(20),
    city           VARCHAR(100),
    loyalty_tier   VARCHAR(20),
    effective_date DATE,
    end_date       DATE,
    is_current     BOOLEAN
);

CREATE TABLE dim_station (
    station_sk     BIGSERIAL PRIMARY KEY,
    station_id     VARCHAR(50),
    station_name   VARCHAR(150),
    city           VARCHAR(100),
    region         VARCHAR(100),
    opened_date    DATE
);

CREATE TABLE dim_product (
    product_sk     BIGSERIAL PRIMARY KEY,
    product_id     VARCHAR(50),
    product_name   VARCHAR(150),
    category       VARCHAR(50),
    unit           VARCHAR(20)
);

CREATE TABLE dim_payment_method (
    payment_sk     BIGSERIAL PRIMARY KEY,
    payment_id     VARCHAR(50),
    payment_name   VARCHAR(50)
);

CREATE TABLE dim_employee (
    employee_sk    BIGSERIAL PRIMARY KEY,
    employee_id    VARCHAR(50),
    full_name      VARCHAR(150),
    station_sk     BIGINT,
    effective_date DATE,
    end_date       DATE,
    is_current     BOOLEAN
);

CREATE TABLE dim_date (
    date_sk        BIGINT PRIMARY KEY,
    full_date      DATE,
    day            INT,
    month          INT,
    month_name     VARCHAR(20),
    quarter        INT,
    year           INT,
    week_of_year   INT,
    is_weekend     BOOLEAN
);

CREATE TABLE dim_fuel_price (
    price_date     DATE,
    product_id     VARCHAR(50),
    unit_price     NUMERIC(10,4)
);



CREATE TABLE staging_employee (
    employee_id   VARCHAR(50),
    full_name     VARCHAR(150),
    station_id    VARCHAR(50),
    hire_date     VARCHAR(20)
);

CREATE TABLE staging_sale (
    sale_id       VARCHAR(50),
    customer_id   VARCHAR(50),
    station_id    VARCHAR(50),
    product_id    VARCHAR(50),
    payment_id    VARCHAR(50),
    employee_id   VARCHAR(50),
    sale_date     VARCHAR(20),
    quantity      VARCHAR(20),
    unit_price    VARCHAR(20),
    total_amount  VARCHAR(20)
);

CREATE TABLE staging_customer (
    customer_id  VARCHAR(50),
    full_name    VARCHAR(150),
    birth_date   DATE,
    phone        VARCHAR(50),
    city         VARCHAR(100),
    loyalty_tier VARCHAR(20)
);



COPY staging_customer (customer_id, full_name, birth_date, phone, city, loyalty_tier) 
FROM '/csv_data/dim_customer_raw.csv' 
WITH (FORMAT csv, HEADER true, NULL '');

COPY staging_sale (sale_id, customer_id, station_id, product_id, payment_id, employee_id, sale_date, quantity, unit_price, total_amount) 
FROM '/csv_data/fact_sale_raw.csv' 
WITH (FORMAT csv, HEADER true, NULL '');

COPY staging_employee (employee_id, full_name, station_id, hire_date) 
FROM '/csv_data/dim_employee_seed.csv' 
WITH (FORMAT csv, HEADER true, NULL '');

COPY dim_fuel_price (price_date, product_id, unit_price) 
FROM '/csv_data/dim_fuel_price_seed.csv' 
WITH (FORMAT csv, HEADER true, NULL '');

COPY dim_product (product_id, product_name, category, unit) 
FROM '/csv_data/dim_product_raw.csv' 
WITH (FORMAT csv, HEADER true, NULL '');

COPY dim_station (station_id, station_name, city, region, opened_date) 
FROM '/csv_data/dim_station_raw.csv' 
WITH (FORMAT csv, HEADER true, NULL '');

COPY dim_payment_method (payment_id, payment_name) 
FROM '/csv_data/dim_payment_method_seed.csv' 
WITH (FORMAT csv, HEADER true, NULL '');


SELECT * FROM fact_sale;
SELECT * FROM dim_customer;
SELECT * FROM dim_station;
SELECT * FROM dim_product;
SELECT * FROM dim_payment_method;
SELECT * FROM dim_employee;
SELECT * FROM dim_date;
SELECT * FROM dim_fuel_price;
SELECT * FROM staging_sale;
SELECT * FROM staging_employee;
SELECT * FROM staging_customer;



INSERT INTO dim_employee (
    employee_id, full_name, station_sk, effective_date, end_date, is_current
)
SELECT 
    e.employee_id,
    e.full_name,
    s.station_sk,
    TO_DATE(e.hire_date, 'YYYY-MM-DD') AS effective_date,
    NULL::DATE AS end_date,
    TRUE AS is_current
FROM staging_employee e
LEFT JOIN dim_station s ON e.station_id = s.station_id;

SELECT * FROM dim_employee;
select * from dim_customer;




INSERT INTO dim_customer (
    customer_id, 
    full_name, 
    birth_date, 
    phone, 
    city, 
    loyalty_tier, 
    effective_date, 
    end_date, 
    is_current
)
WITH ranked_customers AS (
    SELECT 
        customer_id,
        full_name,
        birth_date,
        phone,
        city,
        loyalty_tier,
        ROW_NUMBER() OVER (
            PARTITION BY customer_id 
            ORDER BY 
                CASE loyalty_tier 
                    WHEN 'Bronze' THEN 1 
                    WHEN 'Silver' THEN 2 
                    WHEN 'Gold' THEN 3 
                    ELSE 4 
                END ASC
        ) AS row_num,
        COUNT(*) OVER (PARTITION BY customer_id) AS total_versions
    FROM staging_customer
)
SELECT 
    customer_id,
    full_name,
    birth_date,
    phone,
    city,
    loyalty_tier,
    CASE 
        WHEN row_num = 1 AND total_versions > 1 THEN '2025-01-01'::DATE
        ELSE '2026-01-01'::DATE
    END AS effective_date,
    CASE 
        WHEN row_num < total_versions THEN '2025-12-31'::DATE
        ELSE NULL
    END AS end_date,
    CASE 
        WHEN row_num = total_versions THEN TRUE
        ELSE FALSE
    END AS is_current
FROM ranked_customers
ORDER BY customer_id, row_num;



INSERT INTO dim_date (
    date_sk,
    full_date,
    day,
    month,
    month_name,
    quarter,
    year,
    week_of_year,
    is_weekend
)
SELECT 
    TO_CHAR(tarix, 'YYYYMMDD')::BIGINT AS date_sk,        
    tarix::DATE AS full_date,                             
    EXTRACT(DAY FROM tarix)::INT AS day,                 
    EXTRACT(MONTH FROM tarix)::INT AS month,             
    TRIM(TO_CHAR(tarix, 'Month')) AS month_name, 
    EXTRACT(QUARTER FROM tarix)::INT AS quarter,          
    EXTRACT(YEAR FROM tarix)::INT AS year,                
    EXTRACT(WEEK FROM tarix)::INT AS week_of_year,        
    CASE 
        WHEN EXTRACT(ISODOW FROM tarix) IN (6, 7) THEN TRUE 
        ELSE FALSE 
    END AS is_weekend                                     
FROM generate_series(
    '2026-01-01'::DATE, 
    '2027-12-31'::DATE, 
    '1 day'::INTERVAL
) AS tarix;

select * from dim_date;



INSERT INTO fact_sale (
    date_sk,
    customer_sk,
    station_sk,
    product_sk,
    payment_sk,
    employee_sk,
    sale_id,
    quantity,
    unit_price,
    total_amount
)
SELECT 
    TO_CHAR(TO_DATE(s.sale_date, 'YYYY-MM-DD'), 'YYYYMMDD')::BIGINT AS date_sk,
    
    c.customer_sk,
    st.station_sk,
    p.product_sk,
    pm.payment_sk,
    e.employee_sk,
    s.sale_id,
    s.quantity::NUMERIC(10,3),
    s.unit_price::NUMERIC(10,4),
    
    COALESCE(
        NULLIF(s.total_amount, '')::NUMERIC(18,2),
        (s.quantity::NUMERIC * s.unit_price::NUMERIC)::NUMERIC(18,2)
    ) AS total_amount

FROM staging_sale s

LEFT JOIN dim_customer c ON s.customer_id = c.customer_id AND c.is_current = TRUE

LEFT JOIN dim_station st ON s.station_id = st.station_id

LEFT JOIN dim_product p ON s.product_id = p.product_id

LEFT JOIN dim_payment_method pm ON s.payment_id = pm.payment_id

LEFT JOIN dim_employee e ON s.employee_id = e.employee_id AND e.is_current = TRUE;


select * from fact_sale;


ALTER TABLE fact_sale ADD CONSTRAINT fk_fact_sale_date FOREIGN KEY (date_sk) REFERENCES dim_date(date_sk);



ALTER TABLE fact_sale ADD CONSTRAINT fk_fact_sale_customer  FOREIGN KEY (customer_sk) REFERENCES dim_customer(customer_sk);




ALTER TABLE fact_sale ADD CONSTRAINT fk_fact_sale_station FOREIGN KEY (station_sk) REFERENCES dim_station(station_sk);




ALTER TABLE fact_sale ADD CONSTRAINT fk_fact_sale_product  FOREIGN KEY (product_sk) REFERENCES dim_product(product_sk);



ALTER TABLE fact_sale ADD CONSTRAINT fk_fact_sale_payment fOREIGN KEY (payment_sk) REFERENCES dim_payment_method(payment_sk);



ALTER TABLE fact_sale ADD CONSTRAINT fk_fact_sale_employee FOREIGN KEY (employee_sk) REFERENCES dim_employee(employee_sk);





SELECT 
    d.year,
    d.month_name,
    p.category,
    SUM(f.total_amount) AS total_revenue
FROM fact_sale f
JOIN dim_date d ON f.date_sk = d.date_sk
JOIN dim_product p ON f.product_sk = p.product_sk
GROUP BY d.year, d.month, d.month_name, p.category
ORDER BY d.year, d.month, total_revenue DESC;



SELECT 
    c.full_name AS customer_name,
    d.year,
    SUM(f.total_amount) AS total_spent
FROM fact_sale f
JOIN dim_customer c ON f.customer_sk = c.customer_sk
JOIN dim_date d ON f.date_sk = d.date_sk
GROUP BY c.customer_sk, c.full_name, d.year
ORDER BY total_spent DESC
LIMIT 10;


SELECT 
    CASE 
        WHEN p.category = 'Fuel' THEN 'Fuel'
        ELSE 'Non-Fuel'
    END AS category_group,
    SUM(f.total_amount) AS total_revenue,
    ROUND( (SUM(f.total_amount) * 100.0 / SUM(SUM(f.total_amount)) OVER()), 2) AS percentage
FROM fact_sale f
JOIN dim_product p ON f.product_sk = p.product_sk
GROUP BY 
    CASE 
        WHEN p.category = 'Fuel' THEN 'Fuel'
        ELSE 'Non-Fuel'
    END;


SELECT 
    st.region,
    COUNT(f.sale_sk) AS transaction_count,
    SUM(f.total_amount) AS total_volume
FROM fact_sale f
JOIN dim_station st ON f.station_sk = st.station_sk
GROUP BY st.region
ORDER BY transaction_count DESC;





