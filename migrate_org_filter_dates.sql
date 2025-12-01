ALTER TABLE public.organizations
    ALTER COLUMN filter_start_date TYPE date USING filter_start_date::date,
    ALTER COLUMN filter_end_date TYPE date USING filter_end_date::date;
