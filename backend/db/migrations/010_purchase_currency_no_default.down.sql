-- Restores 001_baseline.sql's original column default.
ALTER TABLE public.course_purchases ALTER COLUMN currency SET DEFAULT 'USD'::text;
