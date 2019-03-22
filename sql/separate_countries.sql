WITH ins AS (
        INSERT INTO countries(country)
        SELECT DISTINCT r.country
        FROM release r
        RETURNING *
        )
UPDATE release rel
SET country_id = ins.id
FROM ins
WHERE ins.country = rel.country;
        
ALTER TABLE release DROP COLUMN country;

SELECT (r.*, c.country)
FROM release r
JOIN countries c ON c.id = r.country_id;

ALTER TABLE release RENAME TO oldrelease;

CREATE TABLE release (
    id integer NOT NULL,
    status text,
    title text,
    country_id text,
    released text,
    notes text,
    genres text[],
    styles text[],
    master_id int,
    data_quality text
);

-- Arranging country_id column back to it's old place
INSERT INTO release (id, status, title, country_id, released, notes, genres, styles, master_id, data_quality) SELECT id, status, title, country_id, released, notes, genres, styles, master_id, data_quality FROM oldrelease;

DROP TABLE IF EXISTS oldrelease;
