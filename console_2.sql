CREATE OR REPLACE TABLE games_clean AS
WITH raw AS (
    SELECT *
    FROM read_json_auto(
        'C:/Users/tanya/Downloads/steam_games/games.json',
        maximum_object_size = 200000000
    )
),
games_flat AS (
    SELECT UNNEST(games) AS g
    FROM raw
)

SELECT
    g.appid AS app_id,
    g.name_from_applist AS name,
    g.app_details.data.type AS type,
    g.app_details.data.is_free AS is_free,
    g.app_details.data.release_date.date AS release_date,
    CASE
        WHEN g.app_details.data.is_free = true THEN 0
        WHEN g.app_details.data.price_overview.final IS NOT NULL
            THEN g.app_details.data.price_overview.final / 100.0
        ELSE 0
    END AS price_usd,
    genre.unnest.description AS genre

FROM games_flat AS g,
UNNEST(g.app_details.data.genres) AS genre;

SELECT * FROM games_clean LIMIT 20;

-- Очищаю від null і перекладаю жанри на одну мову
CREATE OR REPLACE TABLE games_clean_norm AS
SELECT
    app_id,
    name,
    type,
    is_free,
    release_date,
    price_usd,
    genre AS genre_raw,
    CASE
        WHEN genre IN ('Симуляторы','Simulação','Simülasyon') THEN 'Simulation'
        WHEN genre IN ('Инди','Indépendant') THEN 'Indie'
        WHEN genre IN ('Экшены','Acción','Ação','Aksiyon') THEN 'Action'
        WHEN genre = 'Aventura' THEN 'Adventure'
        WHEN genre = 'Strateji' THEN 'Strategy'
        WHEN genre = 'Deportes' THEN 'Sports'
        WHEN genre = 'Carreras' THEN 'Racing'
        WHEN genre = 'Multijogador Massivo' THEN 'Massively Multiplayer'
        ELSE genre
    END AS genre_norm

FROM games_clean

WHERE app_id IS NOT NULL
  AND name IS NOT NULL
  AND type IS NOT NULL
  AND is_free IS NOT NULL
  AND release_date IS NOT NULL
  AND price_usd IS NOT NULL
  AND genre IS NOT NULL;

SELECT * FROM games_clean_norm LIMIT 50;

-- 1
SELECT is_free, COUNT(*) AS amount
FROM games_clean_norm
GROUP BY is_free;

-- 2
SELECT genre_norm,
    ROUND(AVG(price_usd), 2) AS avg_price
FROM games_clean_norm
GROUP BY genre_norm
ORDER BY avg_price DESC;

-- 3
SELECT type,
    COUNT(*) AS games_count,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM games_clean_norm),2) AS percent
FROM games_clean_norm
GROUP BY type
ORDER BY games_count DESC;


CREATE OR REPLACE TABLE reviews_clean AS
WITH raw AS (
    SELECT *
    FROM read_json_auto(
        'C:/Users/tanya/Downloads/steam_reviews/reviews.json',
        maximum_object_size = 200000000
    )
),
reviews_flat AS (
    SELECT UNNEST(reviews) AS r
    FROM raw
)
SELECT
    r.appid AS app_id,
    u.review.recommendationid AS review_id,
    u.review.language AS language,
    u.review.voted_up AS voted_up,
    u.review.votes_up AS votes_up,
    u.review.votes_funny AS votes_funny,
    u.review.author.playtime_forever / 60.0   AS playtime_hours
FROM reviews_flat rf,
UNNEST(rf.r.review_data.reviews) AS u(review);

SELECT * FROM reviews_clean LIMIT 20;

-- 4 Хто пише відгуки+Відсоток позитивних відгуків
SELECT
    language,
    COUNT(*) AS n_reviews,
    ROUND(100 * AVG(CAST(voted_up AS INTEGER)), 2) AS share_positive_pct,
FROM reviews_clean
GROUP BY language
ORDER BY n_reviews DESC;

-- 5. Чи люди

SELECT
    voted_up,
    ROUND(AVG(playtime_hours), 1) AS avg_playtime,
    COUNT(*) AS n_reviews
FROM reviews_clean
GROUP BY voted_up;


