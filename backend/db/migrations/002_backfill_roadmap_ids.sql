-- 002_backfill_roadmap_ids.sql
-- Older roadmaps stored phases/milestones/modules without ids (the AI tree and
-- forks arrived id-less), so module progress could never be recorded. Assign a
-- uuid to every phase/milestone/module whose id is missing or ''. Idempotent:
-- existing ids are kept and rows with nothing blank are not touched.
UPDATE roadmaps
SET structure = jsonb_set(structure, '{phases}', (
    SELECT COALESCE(jsonb_agg(
        jsonb_set(
            CASE WHEN COALESCE(p.v->>'id', '') = ''
                 THEN p.v || jsonb_build_object('id', gen_random_uuid()::text) ELSE p.v END,
            '{milestones}',
            (SELECT COALESCE(jsonb_agg(
                jsonb_set(
                    CASE WHEN COALESCE(m.v->>'id', '') = ''
                         THEN m.v || jsonb_build_object('id', gen_random_uuid()::text) ELSE m.v END,
                    '{modules}',
                    (SELECT COALESCE(jsonb_agg(
                        CASE WHEN COALESCE(d.v->>'id', '') = ''
                             THEN d.v || jsonb_build_object('id', gen_random_uuid()::text) ELSE d.v END
                        ORDER BY d.ord), '[]'::jsonb)
                     FROM jsonb_array_elements(COALESCE(m.v->'modules', '[]'::jsonb)) WITH ORDINALITY d(v, ord))
                ) ORDER BY m.ord), '[]'::jsonb)
             FROM jsonb_array_elements(COALESCE(p.v->'milestones', '[]'::jsonb)) WITH ORDINALITY m(v, ord))
        ) ORDER BY p.ord), '[]'::jsonb)
    FROM jsonb_array_elements(structure->'phases') WITH ORDINALITY p(v, ord)
))
WHERE jsonb_typeof(structure->'phases') = 'array'
  AND (
      jsonb_path_exists(structure, '$.phases[*] ? (!exists(@.id) || @.id == "")')
      OR jsonb_path_exists(structure, '$.phases[*].milestones[*] ? (!exists(@.id) || @.id == "")')
      OR jsonb_path_exists(structure, '$.phases[*].milestones[*].modules[*] ? (!exists(@.id) || @.id == "")')
  );
