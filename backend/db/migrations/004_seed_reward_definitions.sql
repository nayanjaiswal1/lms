-- ════════════════════════════════════════════════════════════════════════════
-- 004_seed_reward_definitions.sql — Badge catalog seed data
-- ════════════════════════════════════════════════════════════════════════════

INSERT INTO reward_definitions (slug, name, description, icon, badge_tier, xp_value, trigger_event, trigger_threshold) VALUES
  ('first_problem',  'First Blood',           'Solved your first problem.',                    '🩸', 'bronze',   100, 'problem_solved',     1),
  ('problem_10',     'Problem Solver',         'Solved 10 problems.',                           '⚡', 'bronze',   200, 'problem_solved',    10),
  ('problem_100',    'Century',                'Solved 100 problems.',                          '💯', 'silver',  1000, 'problem_solved',   100),
  ('streak_7',       'Week Warrior',           'Maintained a 7-day learning streak.',           '🔥', 'bronze',     0, 'streak_milestone',   7),
  ('streak_30',      'Month Master',           'Maintained a 30-day learning streak.',          '🌟', 'silver',     0, 'streak_milestone',  30),
  ('streak_100',     'Centurion',              'Maintained a 100-day learning streak.',         '🏆', 'gold',       0, 'streak_milestone', 100),
  ('first_course',   'Course Starter',         'Completed your first course.',                  '📚', 'bronze',     0, 'course_completed',   1),
  ('course_5',       'Curriculum Champion',    'Completed 5 courses.',                          '🎓', 'silver',     0, 'course_completed',   5),
  ('first_cert',     'Certified',              'Earned your first certificate.',                '📜', 'silver',     0, 'certificate_earned', 1),
  ('cert_5',         'Credential Collector',   'Earned 5 certificates.',                        '🏅', 'gold',       0, 'certificate_earned', 5),
  ('level_5',        'Halfway There',          'Reached level 5 (Proficient).',                 '⚔️', 'silver',     0, 'level_reached',      5),
  ('level_10',       'Legend Status',          'Reached the maximum level.',                    '👑', 'platinum',   0, 'level_reached',     10),
  ('perfect_quiz',   'Perfect Score',          'Achieved a perfect score on an assessment.',   '✨', 'bronze',   150, 'quiz_perfect',       1)
ON CONFLICT (slug) DO NOTHING;
