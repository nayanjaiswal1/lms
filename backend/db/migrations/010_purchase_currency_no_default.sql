-- ═════════════════════════════════════════════════════════════════════════
-- Migration 010 — purchase_currency_no_default
-- ═════════════════════════════════════════════════════════════════════════
-- course_purchases.currency carried DEFAULT 'USD' from 001_baseline.sql. The
-- platform currency is PAYMENTS_CURRENCY (now INR), and every insert already
-- supplies the column explicitly from it — so the default is never used, and
-- the only thing it can still do is silently stamp the wrong currency on a
-- real charge if an insert ever forgets it. Dropping it makes that a loud
-- NOT NULL failure instead of a rupee amount recorded as dollars.
--
-- Existing rows are deliberately left alone: a purchase recorded as USD was
-- charged in USD, and rewriting history to match a later config change would
-- falsify the payment record it exists to be.

ALTER TABLE public.course_purchases ALTER COLUMN currency DROP DEFAULT;
