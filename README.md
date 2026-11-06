# goit-rdb-fp

Фінальний проєкт курсу Relational Databases for DS. Автор: Mykyta Oliinyk.

Статистика інфекційних захворювань завантажується в PostgreSQL 16, нормалізується до 3NF і аналізується SQL-запитами та власними функціями.

## Датасет

`infectious_cases.csv`, 10521 рядок, 245 пар `Entity`/`Code`, роки 1920-2023. Джерело: [Google Drive](https://drive.google.com/file/d/1dQf-uVXzYPYYGgXsG1y4Q1qDdhP2miZl/view?usp=drive_link) із завдання курсу. Використано всі рядки, вибірка не формувалася. Файл не зберігається в репозиторії: notebook завантажує його сам, якщо не знаходить поруч.

## Що зроблено

1. Створено схему `pandemic`, вона обрана схемою за замовчуванням, CSV імпортовано в сиру таблицю `infectious_cases` (усі колонки `TEXT`).
2. Дані нормалізовано до 3NF у дві таблиці:
   - `entities`: унікальні пари `entity`, `code`. Порожній код зберігається як `NULL`. `UNIQUE (entity)` і `UNIQUE (code)` не дають сутності мати два коди, а коду належати двом сутностям;
   - `disease_stats`: показники за `(entity_id, year)` із зовнішнім ключем на `entities`. Порожній показник зберігається як `NULL`, а не нуль.

   Кількість рядків збігається із сирою таблицею (10521 і 245), порівняння через `EXCEPT ALL` в обидва боки показало 0 розбіжностей.
3. Для `number_rabies` пораховано середнє, мінімум, максимум і суму, виведено топ-10 за середнім. 19 сутностей без жодного значення не потрапляють у рейтинг, бо інакше `NULL` стояли б першими при `ORDER BY ... DESC`.
4. Різниця в роках побудована через `make_date`, `CURRENT_DATE`, `age` і `EXTRACT`.
5. Створено функції `years_since(year)` і `avg_cases_per_period(cases, divisor)`. Друга перевірена з дільниками 12, 4, 2 лише на рядках із числовим значенням (6780 рядків).

Обґрунтування 3NF і висновки є в notebook.

## Як запустити

Google Colab: відкрити `final_project.ipynb` і виконати Runtime > Run all. У Colab потрібна версія середовища 2026.07 (Python 3.12): Runtime → Change runtime type → Runtime version, бо `pgserver` не має збірок для Python 3.13.

Локально, на Python 3.12 (на ньому перевірено запуск, для Python 3.14 збірки `pgserver` немає):

```bash
python3.12 -m venv .venv
source .venv/bin/activate
pip install jupyter pgserver sqlalchemy psycopg2-binary "psycopg[binary]" pandas
jupyter nbconvert --to notebook --execute --inplace final_project.ipynb
```

PostgreSQL піднімається через `pgserver` у `/tmp/fp_pg`, окремо встановлювати сервер не потрібно.

`final_project.sql` виконується через `psql` на запущеному сервері PostgreSQL. Команда `\copy` рахує шлях від каталогу запуску, тому запускати треба з кореня репозиторію, де лежить `infectious_cases.csv`. Файл можна завантажити за посиланням вище, або notebook збереже його сюди під час першого запуску:

```bash
psql -v ON_ERROR_STOP=1 -f final_project.sql
```

Значення різниці в роках залежать від дати запуску, бо `CURRENT_DATE` обчислюється під час виконання запиту.

## Структура репозиторію

```text
final_project.ipynb   notebook із виконаними запитами та результатами
final_project.sql     усі SQL-оператори одним файлом
screenshots/          скриншоти таблиць, запитів і результатів
README.md
.gitignore
```

Скриншоти йдуть у порядку завдань: `01`-`03` завдання 1, `04`-`08` завдання 2, `09`-`11` завдання 3, `12`-`13` завдання 4, `14`-`17` завдання 5.
