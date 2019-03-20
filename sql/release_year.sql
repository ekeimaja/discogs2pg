ALTER TABLE release ADD COLUMN release_year INT NULL;

UPDATE release SET release_year = (
  CASE WHEN released ~ '^[0-9]{4}'  THEN SUBSTRING(released, 0, 4)::int
  ELSE NULL
  END
);
