ALTER TABLE public.habits
    DROP CONSTRAINT habits_icon_check,
    ADD CONSTRAINT habits_icon_check
        CHECK (icon = ANY (ARRAY[
            ''::text, 'dumbbell'::text, 'moon'::text, 'book-open'::text, 'brain'::text,
            'droplet'::text, 'utensils'::text, 'flower'::text, 'footprints'::text,
            'phone-off'::text, 'heart'::text, 'music'::text, 'palette'::text, 'code'::text,
            'piggy-bank'::text, 'leaf'::text, 'sun'::text, 'coffee'::text, 'pen-tool'::text,
            'target'::text, 'users'::text, 'briefcase'::text, 'graduation-cap'::text,
            'bike'::text, 'smile'::text
        ]));
