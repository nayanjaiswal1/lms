DELETE FROM public.role_permissions
WHERE role_id = '11111111-1111-1111-1111-000000000003'
  AND permission_id = (SELECT id FROM public.permissions WHERE code = 'mentoring.verify_mentors');

DELETE FROM public.role_permissions
WHERE role_id = '11111111-1111-1111-1111-000000000005'
  AND permission_id = (SELECT id FROM public.permissions WHERE code = 'mentoring.verify_mentors');

DELETE FROM public.role_permissions
WHERE role_id = '11111111-1111-1111-1111-000000000005'
  AND permission_id = (SELECT id FROM public.permissions WHERE code = 'content.interview_exp');
