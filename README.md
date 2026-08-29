# Gas Station Data Pipeline 🚗⛽

Bir end-to-end data processing pipeline layihəsi ki, Linux CLI, Docker və PostgreSQL/Metabase istifadə edərək gas stansiyası satış məlumatlarını temizləyir, transformasiya edir və modelləyir.

---

## 📋 Layihə Ümumi Baxışı

Bu pipeline aşağıdakı mərhələləri əhatə edir:
1. **Raw Dataset** - Qaynaq məlumatlarının toplanması
2. **Data Cleaning** - Linux komandları ilə məlumatların temizlənməsi
3. **Data Transformation** - SQL skripti ilə məlumatların transformasiyası
4. **Data Warehouse** - PostgreSQL-də star schema quruluşunun yaradılması
5. **Visualization** - Metabase ilə analitik hesabatların hazırlanması

---

## 📁 Layihə Struktur Tərifi

```
gas-station-data-pipeline/
├── raw dataset/              # İlkin raw məlumat faylları
│   ├── dim_customer_raw.csv
│   ├── dim_station_raw.csv
│   ├── fact_sale_raw.csv
│   ├── dim_product_raw.csv
│   ├── dim_employee_seed.csv
│   ├── dim_fuel_price_seed.csv
│   └── dim_payment_method_seed.csv
│
├── dataset/                  # Temizlənmiş və işlənmiş məlumatlar
│   └── [Processed CSV files]
│
├── Metabase/                 # Metabase visualization faylları
│   └── [Dashboard exports]
│
├── docker-compose.yaml       # Docker container konfigürasyonu
├── postgres.sql              # PostgreSQL DDL və ETL skripti
├── linux.txt                 # Linux CLI əmrləri və izahatları
├── ddl_erd.jpg              # Entity-Relationship Diagram
└── .gitignore               # Git ignore faylı
```

---

## 🔄 Data Pipeline Mərhələləri

### 1️⃣ Raw Dataset (Qaynaq Məlumatlar)

Raw dataset qovluğunda olan fayllar **orijinal, təmizlənməmiş məlumatlardır**. Bu məlumatlar aşağıdakı problemləri ehtiva edir:

- ❌ **Formatlaşdırma Xətaları** (nöqtə vs tire)
- ❌ **Tarix Formatı Fərqlilikləri** (GG-AA-IIII vs IIII-AA-GG)
- ❌ **Boş Dəyərlər** (N/A, sıfır-dəyərlər)
- ❌ **Dublikat Qeydlər**
- ❌ **Böyük-kiçik Hərf Tutarsızlığı** (Baku, baku, BAKU)
- ❌ **Səhv CSV Ayırıcıları** (`;` vs `,`)

**Misal - dim_customer_raw.csv:**
```csv
customer_id,full_name,birth_date,phone,city,loyalty_tier
C001,Elnur Mammadov,12.04.1988,+994501112233,Baku,Gold
C002,Sevinc Chiragova,12-09-1995,+994552223344,Ganja,Silver
C004,Aygun Ozdemir,02-11-1985,,Baku,Silver
C005,Rashad Aliyev,31.07.1992,+994774445566,Mingachevir,N/A
```

> **Qeyd:** Linux əmrləri ilə əsas temizlik bu raw faylların direkt casestudy qovluğunda olan versiyasına tətbiq edilir. Sonradan məlumatlar dataset qovluğuna atom tez kopyalanır.

---

### 2️⃣ Linux Komandları ilə Data Cleaning

#### **📝 Əmr 1: Nöqtələri Tireylə Əvəz Etmə**

```bash
sed -i "s/\./-/g" dim_customer_raw.csv
```

**Məqsəd:** Tarix və digər sahələrdə olan bütün nöqtə (`.`) simvollarını tire (`-`) ilə əvəz etmə.

**Nəticə:**
```
ƏVVƏL: birth_date: 12.04.1988
SONRA: birth_date: 12-04-1988
```

---

#### **📝 Əmr 2: Tarix Formatının Dəyişdirilməsi**

```bash
sed -i -E 's/([0-9]{2})-([0-9]{2})-([0-9]{4})/\3-\2-\1/g' dim_customer_raw.csv
```

**Məqsəd:** Tarix formatını GG-AA-IIII formatından IIII-AA-GG formatına çevirmə (PostgreSQL DATE tipində compatibility üçün).

**Regex Izahı:**
- `([0-9]{2})` - Gün (2 rəqəm) → Group 1
- `([0-9]{2})` - Ay (2 rəqəm) → Group 2  
- `([0-9]{4})` - İl (4 rəqəm) → Group 3
- `\3-\2-\1` - Əvəzləmə: Il-Ay-Gün

**Nəticə:**
```
ƏVVƏL: 12-04-1988
SONRA: 1988-04-12
```

---

#### **📝 Əmr 3: Sətrin Sonundakı N/A Dəyərlərini Silmə**

```bash
sed -i 's/,N\/A$/,/g' dim_customer_raw.csv
```

**Məqsəd:** Sətrin sonundakı `,N/A` dəyərlərini boş dəyərə (`virgül`) çevirmə.

**Nəticə:**
```
ƏVVƏL: C005,Rashad Aliyev,1992-07-31,+994774445566,Mingachevir,N/A
SONRA: C005,Rashad Aliyev,1992-07-31,+994774445566,Mingachevir,
```

---

#### **📝 Əmr 4: Sətir Silmə**

```bash
sed -i "5d" dim_station_raw.csv
```

**Məqsəd:** Səhv olan 5-ci sətri silmə.

---

#### **📝 Əmr 5: Böyük-Kiçik Hərf Normalizasiyası**

```bash
sed -i "s/Baku/Baku/gI" dim_station_raw.csv
```

**Məqsəd:** "baku", "BAKU", "Baku" kimi bütün variantları standart "Baku" şəklinə çevirmə.

**Nəticə:**
```
ƏVVƏL: socar Nizami,Baku,baku
SONRA: socar Nizami,Baku,Baku
```

---

#### **📝 Əmr 6: İki Ardıcıl Vergülü Əvəz Etmə**

```bash
sed -i "s/,,/,Sumgait,/" dim_station_raw.csv
```

**Məqsəd:** Çatışmayan şəhər adını doldurmak (iki ardıcıl vergülün yerinə şəhər adını yazma).

**Nəticə:**
```
ƏVVƏL: S04,SOCAR Sumgait North,,Sumgait-Absheron,2011-11-11
SONRA: S04,SOCAR Sumgait North,Sumgait,Sumgait-Absheron,2011-11-11
```

---

#### **📝 Əmr 7: CSV Ayırıcı Dəyişdirmə**

```bash
sed -i "s/\;/,/g" fact_sale_raw.csv
```

**Məqsəd:** Sıfırla vergülü (`;`) normal vergül (`,`) ilə əvəz edərək faylı standart CSV formatına çevirmə.

**Nəticə:**
```
ƏVVƏL: S001;C001;P123;2026-01-15;50;1.25;62.50
SONRA: S001,C001,P123,2026-01-15,50,1.25,62.50
```

---

### 3️⃣ Dataset Qovluğu (Temizlənmiş Məlumatlar)

Dataset qovluğunda raw qovluğundakı faylların **temizlənmiş versiyaları** yerləşir:
- Linux əmrləri tətbiq edilib
- Tarix formatları düzəldililib
- Boş dəyərlər standartlaşdırılıb
- Dublikatlar üzərindən işlənib

Bu məlumatlar PostgreSQL-ə load edildikdən sonra SQL transformasyonlarına hazırlanır.

---

## 🐳 Docker Konfigürasyonu

### **docker-compose.yaml Izahı**

```yaml
version: "3.8"

services:
  postgres:
    image: postgres:16
    container_name: pg-db
    restart: always
    environment:
      POSTGRES_PASSWORD: admin              # PostgreSQL admin şifrəsi
    ports:
      - "5432:5432"                        # Port mapping
    volumes:
      - ./data:/var/lib/postgresql/data    # Database data persistence
      - /home/mahammad/casestudy:/csv_data # Raw CSV fayllarının mount edilməsi

  metabase:
    image: metabase/metabase:latest
    container_name: metabase
    restart: always
    ports:
      - "3000:3000"                        # Metabase UI port
    depends_on:
      - postgres                           # PostgreSQL-dən asılıdır

volumes: {}
```

#### **Açıklamalar:**

| Parametr | Izahat |
|----------|--------|
| `postgres:16` | PostgreSQL 16 versiyası istifadə edilir |
| `POSTGRES_PASSWORD: admin` | Admin şifrəsi "admin" olaraq təyin edilib |
| `5432:5432` | Host machine-in 5432 portunu container-in 5432 portuna map etmə |
| `/home/mahammad/casestudy:/csv_data` | Hostdakı CSV fayllar container içində `/csv_data` yolunda əlçatan olur |
| `depends_on: postgres` | Metabase yalnız PostgreSQL işə düşdükdən sonra başlayır |

#### **Docker Başlatmaq:**
```bash
docker-compose up -d
```

#### **PostgreSQL-ə Qoşulmaq:**
```bash
psql -h localhost -U postgres -p 5432
```

---

## 🗄️ PostgreSQL Schema və SQL Transformasyonları

### **Schema Dizayn (Star Schema)**

Pipeline **Star Schema** modelindən istifadə edir:

```
              ┌──────────────────┐
              │   FACT_SALE      │
              │   (Central)      │
              └──────────────────┘
                     │
       ┌─────────────┼─────────────┐
       │             │             │
    DIM_DATE    DIM_CUSTOMER   DIM_STATION
       │             │             │
    DIM_PRODUCT  DIM_EMPLOYEE  DIM_PAYMENT
```

---

### **1. Fact Cədvəli - fact_sale**

```sql
CREATE TABLE fact_sale (
    sale_sk        BIGSERIAL PRIMARY KEY,  -- Surrogate Key
    date_sk        BIGINT,                 -- Tarix Key
    customer_sk    BIGINT,                 -- Müşteri Key
    station_sk     BIGINT,                 -- Stansiya Key
    product_sk     BIGINT,                 -- Məhsul Key
    payment_sk     BIGINT,                 -- Ödəniş Key
    employee_sk    BIGINT,                 -- İşçi Key
    sale_id        VARCHAR(50),            -- Business Key
    quantity       NUMERIC(10,3),          -- Satış miqdarı
    unit_price     NUMERIC(10,4),          -- Vahid qiymət
    total_amount   NUMERIC(18,2)           -- Ümumi məbləğ
);
```

**Məqsəd:** Hər satış tranzaksiyonunu qeyd etmə.

---

### **2. Dimension Cədvəlləri**

#### **dim_customer - Müşteri Dimension**
```sql
CREATE TABLE dim_customer (
    customer_sk    BIGSERIAL PRIMARY KEY,
    customer_id    VARCHAR(50),
    full_name      VARCHAR(150),
    birth_date     DATE,
    phone          VARCHAR(20),
    city           VARCHAR(100),
    loyalty_tier   VARCHAR(20),
    effective_date DATE,                   -- SCD Type 2
    end_date       DATE,                   -- SCD Type 2
    is_current     BOOLEAN                 -- Cari olub-olmamaq
);
```

**Xüsusiyyət:** Slowly Changing Dimension (SCD Type 2) - müştərinin loqyalti dərəcəsi dəyişəndə yeni sətir əlavə edilir.

---

#### **dim_station - Stansiya Dimension**
```sql
CREATE TABLE dim_station (
    station_sk     BIGSERIAL PRIMARY KEY,
    station_id     VARCHAR(50),
    station_name   VARCHAR(150),
    city           VARCHAR(100),
    region         VARCHAR(100),
    opened_date    DATE
);
```

---

#### **dim_product - Məhsul Dimension**
```sql
CREATE TABLE dim_product (
    product_sk     BIGSERIAL PRIMARY KEY,
    product_id     VARCHAR(50),
    product_name   VARCHAR(150),
    category       VARCHAR(50),            -- Fuel / Non-Fuel
    unit           VARCHAR(20)             -- Liter / Qty
);
```

---

#### **dim_employee - İşçi Dimension**
```sql
CREATE TABLE dim_employee (
    employee_sk    BIGSERIAL PRIMARY KEY,
    employee_id    VARCHAR(50),
    full_name      VARCHAR(150),
    station_sk     BIGINT,                 -- Hansı stansiyada işləyir
    effective_date DATE,
    end_date       DATE,
    is_current     BOOLEAN
);
```

---

#### **dim_date - Tarix Dimension**
```sql
CREATE TABLE dim_date (
    date_sk        BIGINT PRIMARY KEY,     -- YYYYMMDD formatında
    full_date      DATE,
    day            INT,
    month          INT,
    month_name     VARCHAR(20),
    quarter        INT,
    year           INT,
    week_of_year   INT,
    is_weekend     BOOLEAN
);
```

---

### **3. Staging Cədvəlləri (ETL üçün Ara Mərhələ)**

Staging cədvəlləri CSV fayllarından raw məlumatı qəbul edir:

```sql
CREATE TABLE staging_customer (
    customer_id    VARCHAR(50),
    full_name      VARCHAR(150),
    birth_date     DATE,
    phone          VARCHAR(50),
    city           VARCHAR(100),
    loyalty_tier   VARCHAR(20)
);

CREATE TABLE staging_sale (
    sale_id        VARCHAR(50),
    customer_id    VARCHAR(50),
    station_id     VARCHAR(50),
    product_id     VARCHAR(50),
    payment_id     VARCHAR(50),
    employee_id    VARCHAR(50),
    sale_date      VARCHAR(20),
    quantity       VARCHAR(20),
    unit_price     VARCHAR(20),
    total_amount   VARCHAR(20)
);
```

---

### **4. COPY Əmrləri - CSV Fayllarından Data Yükləmə**

```sql
COPY staging_customer (customer_id, full_name, birth_date, phone, city, loyalty_tier) 
FROM '/csv_data/dim_customer_raw.csv' 
WITH (FORMAT csv, HEADER true, NULL '');
```

**Məqsəd:** Docker container içində `/csv_data` yolunda bulunan CSV fayllarını PostgreSQL cədvəlinə yükləmə.

---

### **5. INSERT ... SELECT - ETL Transformasyonları**

#### **A. dim_employee Doldurulması**

```sql
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
```

**Nə etdi:**
- Staging cədvəldən müşteri məlumatını oxuyur
- `LEFT JOIN` ilə stansiya ID-sini stansiya surrogate key-ə çevirir
- Tarix formatını uyğun hale gətirir
- Cari vəziyyəti TRUE olaraq təyin edir

---

#### **B. dim_customer Doldurulması (SCD Type 2 Mantığı)**

```sql
INSERT INTO dim_customer (
    customer_id, full_name, birth_date, phone, city, loyalty_tier, 
    effective_date, end_date, is_current
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
```

**Nə etdi (SCD Type 2 - Versioning):**

1. **ROW_NUMBER()** - Müştərinin hər versiyasını sıralamaq (loqyalti dərəcəsinə əsas)
2. **Dublikat müştərilər uyğunlaştırılır** - C002 İD-si olan müştəri 2 dəfə gəlib (Silver → Gold)
3. **Effective/End Dates təyin edilir:**
   - Eski versiya: 2025-01-01 to 2025-12-31 (is_current = FALSE)
   - Yeni versiya: 2026-01-01 to NULL (is_current = TRUE)

---

#### **C. dim_date Doldurulması (Calendar Dimension)**

```sql
INSERT INTO dim_date (
    date_sk, full_date, day, month, month_name, quarter, year, 
    week_of_year, is_weekend
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
```

**Nə etdi:**
- 2026-01-01 ilə 2027-12-31 arasında hər gün üçün sətir yaradır
- `date_sk` = YYYYMMDD formatında (20260101 kimi)
- Ayın adı, rüb, həftə rəqəmi və weekend flag-ı hesablayır

---

#### **D. fact_sale Doldurulması (Mərkəzi Fakt Cədvəli)**

```sql
INSERT INTO fact_sale (
    date_sk, customer_sk, station_sk, product_sk, payment_sk, 
    employee_sk, sale_id, quantity, unit_price, total_amount
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
```

**Nə etdi:**
1. **Surrogate Keys ilə Joins:** Staging məlumatında olan business key-ləri dimension surrogate key-lerinə çevirir
2. **Tarix Transformasiyası:** VARCHAR tarix formatını BIGINT date_sk-a çevirir
3. **NULL Handling:** Boş total_amount dəyərlərini quantity × unit_price ilə hesablayır
4. **Cari Məlumat Seçilir:** `is_current = TRUE` ilə yalnız aktual müştəri və işçi məlumatı istifadə edilir

---

### **6. Foreign Key Əlaqələri**

```sql
ALTER TABLE fact_sale ADD CONSTRAINT fk_fact_sale_date 
    FOREIGN KEY (date_sk) REFERENCES dim_date(date_sk);

ALTER TABLE fact_sale ADD CONSTRAINT fk_fact_sale_customer 
    FOREIGN KEY (customer_sk) REFERENCES dim_customer(customer_sk);

ALTER TABLE fact_sale ADD CONSTRAINT fk_fact_sale_station 
    FOREIGN KEY (station_sk) REFERENCES dim_station(station_sk);

ALTER TABLE fact_sale ADD CONSTRAINT fk_fact_sale_product 
    FOREIGN KEY (product_sk) REFERENCES dim_product(product_sk);

ALTER TABLE fact_sale ADD CONSTRAINT fk_fact_sale_payment 
    FOREIGN KEY (payment_sk) REFERENCES dim_payment_method(payment_sk);

ALTER TABLE fact_sale ADD CONSTRAINT fk_fact_sale_employee 
    FOREIGN KEY (employee_sk) REFERENCES dim_employee(employee_sk);
```

**Məqsəd:** Fact cədvəlindəki surrogate key-lərin dimension cədvəllərinə işarə etməsini təmin etmə (Referential Integrity).

---

### **7. Analitik Sorğular**

#### **Sorğu 1: Kategoriya üzrə Aylıq Gəlir**
```sql
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
```

**Gətirir:** Hər ay üçün məhsul kategoriyası (Fuel/Non-Fuel) ilə gəlir.

---

#### **Sorğu 2: Top 10 Müştəri (Ən Çox Sərf Edin)**
```sql
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
```

**Gətirir:** Ən çox sərf edən 10 müştəri.

---

#### **Sorğu 3: Fuel vs Non-Fuel Gəliri**
```sql
SELECT 
    CASE 
        WHEN p.category = 'Fuel' THEN 'Fuel'
        ELSE 'Non-Fuel'
    END AS category_group,
    SUM(f.total_amount) AS total_revenue,
    ROUND((SUM(f.total_amount) * 100.0 / SUM(SUM(f.total_amount)) OVER()), 2) AS percentage
FROM fact_sale f
JOIN dim_product p ON f.product_sk = p.product_sk
GROUP BY category_group;
```

**Gətirir:** Yanacaq vs Digər məhsulların gəlir payını.

---

#### **Sorğu 4: Regionlar üzrə Satış Həcmi**
```sql
SELECT 
    st.region,
    COUNT(f.sale_sk) AS transaction_count,
    SUM(f.total_amount) AS total_volume
FROM fact_sale f
JOIN dim_station st ON f.station_sk = st.station_sk
GROUP BY st.region
ORDER BY transaction_count DESC;
```

**Gətirir:** Hər region üzrə tranzaksiya sayı və ümumi həcm.

---

## 📊 Metabase İntegrasiyonu

Metabase `docker-compose.yaml` vasitəsilə PostgreSQL-ə qoşulur:

1. **Metabase URL:** `http://localhost:3000`
2. **PostgreSQL Connection:**
   - Host: `postgres`
   - Port: `5432`
   - Database: `postgres`
   - User: `postgres`
   - Password: `admin`

3. **Dashboard Hazırlama:**
   - Dimension/Fact cədvəllərinə əsas sorğular
   - Vizualizasyon: Sütun diaqramları, Pie chart, Heatmap
   - Filterlər: Tarix, Kategoriya, Region

---

## 🚀 Pipeline Icrasının Addımları

### **1. Docker Konteynerlərini Başlatmaq**
```bash
docker-compose up -d
```

### **2. PostgreSQL-ə Qoşulmaq**
```bash
psql -h localhost -U postgres -p 5432
```

### **3. SQL Skriptini Icra Etmək**
```bash
psql -h localhost -U postgres -p 5432 < postgres.sql
```

### **4. Metabase-ə Girişi Etmək**
```
http://localhost:3000
```

---

## 📌 Xülasə

| Addım | Təsvir | Texnologiya |
|-------|--------|-------------|
| Raw Data | Əsas məlumatlar | CSV faylları |
| Cleaning | Linux CLI ilə temizlənmə | sed, bash |
| Loading | CSV → PostgreSQL | COPY əmri |
| Transformation | Business Logic | SQL INSERT-SELECT |
| Warehouse | Star Schema | PostgreSQL |
| Visualization | Analitik Reportlar | Metabase |

---

## 📖 Əlavə Resurslar

- **PostgreSQL Documentation:** https://www.postgresql.org/docs/
- **Metabase Documentation:** https://www.metabase.com/learn/
- **Data Warehouse Design:** Ralph Kimball Star Schema Pattern
- **SCD Types:** Slowly Changing Dimensions

---

**Hazırlayan:** Mahammad Rasulov  
**Tarix:** 2026-08-29  
**Layihə Tipi:** Data Pipeline & Analytics  
**Status:** ✅ Aktiv
