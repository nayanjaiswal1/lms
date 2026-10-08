REVOKE ALL ON lab_sessions, lab_definitions, lab_build_variants FROM labproxy;
REVOKE USAGE ON SCHEMA public FROM labproxy;
DROP ROLE IF EXISTS labproxy;
