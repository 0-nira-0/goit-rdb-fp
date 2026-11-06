-- Фінальний проєкт: Relational Databases for DS
-- Mykyta Oliinyk
--
-- Запуск із кореня репозиторію (поруч має лежати infectious_cases.csv):
--   psql -v ON_ERROR_STOP=1 -f final_project.sql
-- Команда \copy виконується клієнтом psql, шлях рахується від каталогу запуску. CSV не зберігається в репозиторії, посилання є в README.
-- У notebook той самий імпорт зроблено через pandas to_sql.


-- ------------------------------------------------------------------------
-- Завдання 1. Схема та імпорт
-- ------------------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS pandemic;
SET search_path TO pandemic;

SELECT current_schema() AS default_schema,
       current_setting('search_path') AS search_path,
       current_setting('server_version') AS server_version;

DROP TABLE IF EXISTS disease_stats;
DROP TABLE IF EXISTS entities;
DROP TABLE IF EXISTS infectious_cases;

CREATE TABLE infectious_cases (
    entity               TEXT,
    code                 TEXT,
    year                 TEXT,
    number_yaws          TEXT,
    polio_cases          TEXT,
    cases_guinea_worm    TEXT,
    number_rabies        TEXT,
    number_malaria       TEXT,
    number_hiv           TEXT,
    number_tuberculosis  TEXT,
    number_smallpox      TEXT,
    number_cholera_cases TEXT
);

\copy infectious_cases FROM 'infectious_cases.csv' WITH (FORMAT csv, HEADER true, NULL '\N', ENCODING 'UTF8')

SELECT *
FROM infectious_cases
LIMIT 5;

SELECT ordinal_position, column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'pandemic'
  AND table_name = 'infectious_cases'
ORDER BY ordinal_position;

SELECT COUNT(*) AS total_rows,
       COUNT(DISTINCT (entity, code)) AS entity_code_pairs,
       COUNT(*) FILTER (WHERE code = '') AS blank_code,
       COUNT(*) FILTER (WHERE number_rabies = '') AS blank_number_rabies,
       MIN(year) AS min_year,
       MAX(year) AS max_year
FROM infectious_cases;

SELECT COUNT(DISTINCT entity) AS entities_without_code,
       string_agg(DISTINCT entity, ', ') AS entity_list
FROM infectious_cases
WHERE code = '';

SELECT t.column_name,
       COUNT(*) FILTER (WHERE t.value = '') AS blank,
       COUNT(*) FILTER (WHERE t.value ~ '^[0-9]+(\.[0-9]+)?$') AS numeric_values,
       COUNT(*) FILTER (WHERE t.value <> '' AND t.value !~ '^[0-9]+(\.[0-9]+)?$') AS other_values
FROM infectious_cases
CROSS JOIN LATERAL (
    VALUES
        ('year', year),
        ('number_yaws', number_yaws),
        ('polio_cases', polio_cases),
        ('cases_guinea_worm', cases_guinea_worm),
        ('number_rabies', number_rabies),
        ('number_malaria', number_malaria),
        ('number_hiv', number_hiv),
        ('number_tuberculosis', number_tuberculosis),
        ('number_smallpox', number_smallpox),
        ('number_cholera_cases', number_cholera_cases)
) AS t (column_name, value)
GROUP BY t.column_name
ORDER BY t.column_name;


-- ------------------------------------------------------------------------
-- Завдання 2. Нормалізація до 3NF
-- ------------------------------------------------------------------------
SELECT 'entity -> code' AS dependency, COUNT(*) AS violations
FROM (
    SELECT entity
    FROM infectious_cases
    GROUP BY entity
    HAVING COUNT(DISTINCT code) > 1
) AS v
UNION ALL
SELECT 'code -> entity', COUNT(*)
FROM (
    SELECT code
    FROM infectious_cases
    WHERE code <> ''
    GROUP BY code
    HAVING COUNT(DISTINCT entity) > 1
) AS v
UNION ALL
SELECT '(entity, year) -> row', COUNT(*)
FROM (
    SELECT entity, year
    FROM infectious_cases
    GROUP BY entity, year
    HAVING COUNT(*) > 1
) AS v;

DROP TABLE IF EXISTS disease_stats;
DROP TABLE IF EXISTS entities;

CREATE TABLE entities (
    entity_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    entity    TEXT NOT NULL,
    code      TEXT,
    CONSTRAINT uq_entities_entity UNIQUE (entity),
    CONSTRAINT uq_entities_code UNIQUE (code)
);

CREATE TABLE disease_stats (
    entity_id            INTEGER NOT NULL REFERENCES entities (entity_id),
    year                 INTEGER NOT NULL,
    number_yaws          NUMERIC,
    polio_cases          NUMERIC,
    cases_guinea_worm    NUMERIC,
    number_rabies        NUMERIC,
    number_malaria       NUMERIC,
    number_hiv           NUMERIC,
    number_tuberculosis  NUMERIC,
    number_smallpox      NUMERIC,
    number_cholera_cases NUMERIC,
    PRIMARY KEY (entity_id, year)
);

SELECT table_name, ordinal_position, column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'pandemic'
  AND table_name IN ('entities', 'disease_stats')
ORDER BY table_name DESC, ordinal_position;

SELECT conrelid::regclass AS table_name,
       conname AS constraint_name,
       pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE conrelid IN ('entities'::regclass, 'disease_stats'::regclass)
  AND contype IN ('p', 'u', 'f')
ORDER BY table_name DESC, contype, conname;

INSERT INTO entities (entity, code)
SELECT DISTINCT entity, NULLIF(code, '')
FROM infectious_cases
ORDER BY entity, NULLIF(code, '');

INSERT INTO disease_stats (
    entity_id,
    year,
    number_yaws,
    polio_cases,
    cases_guinea_worm,
    number_rabies,
    number_malaria,
    number_hiv,
    number_tuberculosis,
    number_smallpox,
    number_cholera_cases
)
SELECT
    e.entity_id,
    r.year::INTEGER,
    NULLIF(r.number_yaws, '')::NUMERIC,
    NULLIF(r.polio_cases, '')::NUMERIC,
    NULLIF(r.cases_guinea_worm, '')::NUMERIC,
    NULLIF(r.number_rabies, '')::NUMERIC,
    NULLIF(r.number_malaria, '')::NUMERIC,
    NULLIF(r.number_hiv, '')::NUMERIC,
    NULLIF(r.number_tuberculosis, '')::NUMERIC,
    NULLIF(r.number_smallpox, '')::NUMERIC,
    NULLIF(r.number_cholera_cases, '')::NUMERIC
FROM infectious_cases AS r
JOIN entities AS e
  ON e.entity = r.entity
 AND e.code IS NOT DISTINCT FROM NULLIF(r.code, '');

SELECT *
FROM entities
ORDER BY entity_id
LIMIT 5;

SELECT *
FROM disease_stats
WHERE number_rabies IS NOT NULL
ORDER BY entity_id, year
LIMIT 5;

SELECT 'infectious_cases: rows' AS check_name, COUNT(*) AS value
FROM infectious_cases
UNION ALL
SELECT 'disease_stats: rows', COUNT(*)
FROM disease_stats
UNION ALL
SELECT 'distinct (entity, code) in raw', COUNT(DISTINCT (entity, code))
FROM infectious_cases
UNION ALL
SELECT 'entities: rows', COUNT(*)
FROM entities
UNION ALL
SELECT 'entities: code IS NULL', COUNT(*)
FROM entities
WHERE code IS NULL
UNION ALL
SELECT 'disease_stats: rows of entities without code', COUNT(*)
FROM disease_stats AS s
JOIN entities AS e USING (entity_id)
WHERE e.code IS NULL
UNION ALL
SELECT 'rows if joined with plain e.code = r.code', COUNT(*)
FROM infectious_cases AS r
JOIN entities AS e
  ON e.entity = r.entity
 AND e.code = NULLIF(r.code, '');

WITH typed_raw AS (
    SELECT entity,
           NULLIF(code, '') AS code,
           year::INTEGER AS year,
           NULLIF(number_yaws, '')::NUMERIC AS number_yaws,
           NULLIF(polio_cases, '')::NUMERIC AS polio_cases,
           NULLIF(cases_guinea_worm, '')::NUMERIC AS cases_guinea_worm,
           NULLIF(number_rabies, '')::NUMERIC AS number_rabies,
           NULLIF(number_malaria, '')::NUMERIC AS number_malaria,
           NULLIF(number_hiv, '')::NUMERIC AS number_hiv,
           NULLIF(number_tuberculosis, '')::NUMERIC AS number_tuberculosis,
           NULLIF(number_smallpox, '')::NUMERIC AS number_smallpox,
           NULLIF(number_cholera_cases, '')::NUMERIC AS number_cholera_cases
    FROM infectious_cases
),
restored AS (
    SELECT e.entity, e.code, s.year,
           number_yaws, polio_cases, cases_guinea_worm,
           number_rabies, number_malaria, number_hiv,
           number_tuberculosis, number_smallpox, number_cholera_cases
    FROM disease_stats AS s
    JOIN entities AS e USING (entity_id)
)
SELECT
    (SELECT COUNT(*) FROM (SELECT * FROM typed_raw EXCEPT ALL SELECT * FROM restored) AS d) AS only_in_raw,
    (SELECT COUNT(*) FROM (SELECT * FROM restored EXCEPT ALL SELECT * FROM typed_raw) AS d) AS only_in_normalized;

DO $$
DECLARE
    v RECORD;
BEGIN
    FOR v IN
        SELECT *
        FROM (VALUES ('Africa', NULL), ('Africa', 'AFR'), ('New entity', 'AFG')) AS t (entity, code)
    LOOP
        BEGIN
            INSERT INTO entities (entity, code) VALUES (v.entity, v.code);
            RAISE EXCEPTION '(%, %) was accepted', v.entity, v.code;
        EXCEPTION
            WHEN unique_violation THEN
                RAISE NOTICE '(%, %) rejected: %', v.entity, v.code, SQLERRM;
        END;
    END LOOP;
END $$;


-- ------------------------------------------------------------------------
-- Завдання 3. Агрегати Number_rabies, топ-10
-- ------------------------------------------------------------------------
SELECT e.entity_id, e.entity, e.code,
       COUNT(s.number_rabies) AS years_with_value,
       AVG(s.number_rabies) AS avg_rabies
FROM entities AS e
JOIN disease_stats AS s USING (entity_id)
GROUP BY e.entity_id, e.entity, e.code
ORDER BY avg_rabies DESC, e.entity_id
LIMIT 3;

SELECT COUNT(*) AS entities_total,
       COUNT(*) FILTER (WHERE years_with_value = 0) AS entities_without_values,
       COUNT(*) FILTER (WHERE years_with_value > 0) AS entities_with_values
FROM (
    SELECT s.entity_id, COUNT(s.number_rabies) AS years_with_value
    FROM disease_stats AS s
    GROUP BY s.entity_id
) AS per_entity;

SELECT e.entity_id,
       e.entity,
       e.code,
       COUNT(s.number_rabies) AS years_with_value,
       ROUND(AVG(s.number_rabies), 2) AS avg_rabies,
       ROUND(MIN(s.number_rabies), 2) AS min_rabies,
       ROUND(MAX(s.number_rabies), 2) AS max_rabies,
       ROUND(SUM(s.number_rabies), 2) AS sum_rabies
FROM entities AS e
JOIN disease_stats AS s USING (entity_id)
WHERE s.number_rabies IS NOT NULL
GROUP BY e.entity_id, e.entity, e.code
ORDER BY AVG(s.number_rabies) DESC, e.entity_id
LIMIT 10;

SELECT entity, code
FROM entities
WHERE code LIKE 'OWID%'
ORDER BY code;

SELECT e.entity_id,
       e.entity,
       e.code,
       COUNT(s.number_rabies) AS years_with_value,
       ROUND(AVG(s.number_rabies), 2) AS avg_rabies,
       ROUND(MIN(s.number_rabies), 2) AS min_rabies,
       ROUND(MAX(s.number_rabies), 2) AS max_rabies,
       ROUND(SUM(s.number_rabies), 2) AS sum_rabies
FROM entities AS e
JOIN disease_stats AS s USING (entity_id)
WHERE s.number_rabies IS NOT NULL
  AND e.code IS NOT NULL
  AND e.code NOT LIKE 'OWID%'
GROUP BY e.entity_id, e.entity, e.code
ORDER BY AVG(s.number_rabies) DESC, e.entity_id
LIMIT 10;


-- ------------------------------------------------------------------------
-- Завдання 4. Різниця в роках через вбудовані функції
-- ------------------------------------------------------------------------
SELECT e.entity,
       s.year,
       make_date(s.year, 1, 1) AS year_start,
       CURRENT_DATE AS today,
       EXTRACT(YEAR FROM age(CURRENT_DATE, make_date(s.year, 1, 1)))::INTEGER AS years_diff
FROM disease_stats AS s
JOIN entities AS e USING (entity_id)
ORDER BY e.entity, s.year
LIMIT 10;

WITH diff AS (
    SELECT s.year,
           EXTRACT(YEAR FROM age(CURRENT_DATE, make_date(s.year, 1, 1)))::INTEGER AS years_diff
    FROM disease_stats AS s
)
SELECT COUNT(*) AS total_rows,
       COUNT(years_diff) AS rows_with_diff,
       MIN(year) AS min_year,
       MAX(year) AS max_year,
       MIN(years_diff) AS min_diff,
       MAX(years_diff) AS max_diff,
       COUNT(*) FILTER (
           WHERE years_diff <> EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER - year
       ) AS mismatches
FROM diff;


-- ------------------------------------------------------------------------
-- Завдання 5. Власні функції
-- ------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION years_since(p_year INTEGER)
RETURNS INTEGER
LANGUAGE sql
STABLE
AS $$
    SELECT EXTRACT(YEAR FROM age(CURRENT_DATE, make_date(p_year, 1, 1)))::INTEGER;
$$;

SELECT 1996 AS year_value,
       make_date(1996, 1, 1) AS year_start,
       CURRENT_DATE AS today,
       years_since(1996) AS years_diff;

SELECT e.entity,
       s.year,
       years_since(s.year) AS years_diff
FROM disease_stats AS s
JOIN entities AS e USING (entity_id)
ORDER BY e.entity, s.year
LIMIT 10;

SELECT COUNT(*) AS total_rows,
       COUNT(*) FILTER (
           WHERE years_since(s.year) IS DISTINCT FROM
                 EXTRACT(YEAR FROM age(CURRENT_DATE, make_date(s.year, 1, 1)))::INTEGER
       ) AS mismatches_with_task_4
FROM disease_stats AS s;

CREATE OR REPLACE FUNCTION avg_cases_per_period(p_cases_per_year NUMERIC, p_divisor NUMERIC)
RETURNS NUMERIC
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT p_cases_per_year / NULLIF(p_divisor, 0);
$$;

SELECT p.proname AS function_name,
       pg_get_function_arguments(p.oid) AS arguments,
       pg_get_function_result(p.oid) AS returns,
       CASE p.provolatile WHEN 'i' THEN 'IMMUTABLE' WHEN 's' THEN 'STABLE' ELSE 'VOLATILE' END AS volatility
FROM pg_proc AS p
JOIN pg_namespace AS n ON n.oid = p.pronamespace
WHERE n.nspname = 'pandemic'
ORDER BY p.proname;

SELECT ROUND(avg_cases_per_period(1200, 12), 2) AS per_month,
       ROUND(avg_cases_per_period(1200, 4), 2) AS per_quarter,
       ROUND(avg_cases_per_period(1200, 2), 2) AS per_half_year,
       avg_cases_per_period(NULL, 12) AS null_cases,
       avg_cases_per_period(1200, 0) AS zero_divisor;

SELECT e.entity,
       s.year,
       years_since(s.year) AS years_diff,
       ROUND(s.number_rabies, 4) AS cases_per_year,
       ROUND(avg_cases_per_period(s.number_rabies, 12), 4) AS avg_per_month,
       ROUND(avg_cases_per_period(s.number_rabies, 4), 4) AS avg_per_quarter,
       ROUND(avg_cases_per_period(s.number_rabies, 2), 4) AS avg_per_half_year
FROM disease_stats AS s
JOIN entities AS e USING (entity_id)
WHERE s.number_rabies IS NOT NULL
ORDER BY e.entity, s.year
LIMIT 10;

SELECT 'disease_stats' AS source,
       COUNT(*) AS rows_used,
       SUM(s.number_rabies) AS sum_cases,
       SUM(avg_cases_per_period(s.number_rabies, 12) * 12)::NUMERIC(20, 6) AS sum_month_x12,
       SUM(avg_cases_per_period(s.number_rabies, 4) * 4)::NUMERIC(20, 6) AS sum_quarter_x4,
       SUM(avg_cases_per_period(s.number_rabies, 2) * 2)::NUMERIC(20, 6) AS sum_half_year_x2
FROM disease_stats AS s
WHERE s.number_rabies IS NOT NULL
UNION ALL
SELECT 'infectious_cases (raw)',
       COUNT(*),
       SUM(r.number_rabies::NUMERIC),
       SUM(avg_cases_per_period(r.number_rabies::NUMERIC, 12) * 12)::NUMERIC(20, 6),
       SUM(avg_cases_per_period(r.number_rabies::NUMERIC, 4) * 4)::NUMERIC(20, 6),
       SUM(avg_cases_per_period(r.number_rabies::NUMERIC, 2) * 2)::NUMERIC(20, 6)
FROM infectious_cases AS r
WHERE r.number_rabies ~ '^[0-9]+(\.[0-9]+)?$';
