# Snowflake Schema Analysis

## Potential Snowflake Dimensions

### 1. dim_product → dim_category
- `category` sütununu ayrı cədvələ çıxarmaq olar.

### 2. dim_customer → dim_loyalty_tier
- `loyalty_tier` (Silver, Gold, Platinum) dəyərlərini ayrı cədvələ çıxarmaq olar.

### 3. dim_station və dim_customer → dim_location (dim_city / dim_region)
- Həm `dim_station`, həm də `dim_customer` daxilindəki `city` və `region` məlumatlarını ortaq `dim_location` iyerarxiyasına çıxarıb FK ilə bağlamaq mümkündür.

## Region və City Cədvəlinin Ortaq Bağlanması

### Normallaşdırma Perspektivi
- OLTP (3NF) baxımından `dim_location` (və ya `dim_region`) yaratmaq və həm `dim_customer`, həm də `dim_station` cədvəlini bura bağlamaq məlumat təkrarını aradan qaldırır.
- OLAP (Data Warehouse) baxımından isə `fact_sale` üzərindən atılan sorğularda `JOIN` sayı artdığı üçün sorğu performansını aşağı salır. Bu səbəbdən denormalize halda saxlanılması daha üstündür.

## Üstünlükləri və Çatışmazlıqları

### Üstünlükləri:
- Məlumat təkrarı (redundancy) azalır və veri bütünlüyü (data integrity) artır.
- İyerarxik atributların yenilənməsi (SCD idarəetməsi) tək cədvəl üzərindən daha rahat olur.

### Çatışmazlıqları:
- Analitik sorğularda `JOIN`-lərin sayı artır və Big Data mühitində performans düşür.
- BI alətləri (Metabase, Power BI) üçün datamart modeli mürəkkəbləşir.
- Müasir Cloud DWH sistemlərində disk sahəsinə qənaət sorğu sürətindən daha vacib deyil.

## Yekun Qərar

Mövcud layihədə cədvəllər sadə və atribut sayı az olduğu üçün **Star Schema**-da qalmaq (Snowflake etməmək) analitik sorğuların sürəti və modelin sadəliyi baxımından ən optimal yoldur.
