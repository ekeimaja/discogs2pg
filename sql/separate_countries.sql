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
id SERIAL NOT NULL PRIMARY KEY, 
title text, 
country_id int,
released text);

-- Arranging country_id column back to it's old place
INSERT INTO release (id, title, country_id, released) SELECT id, title, country_id, released FROM oldrelease;

DROP TABLE IF EXISTS oldrelease;
