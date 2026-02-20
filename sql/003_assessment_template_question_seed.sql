-- Assessment Template Question Seed Script
-- Run using: python scripts/run_seed.py --tenant "tenant_name" --username "username" --sql-file sql/003_assessment_template_question_seed.sql
--
-- Requires psql variables: tenant_name, username

-- Create temp table (persists for session)
CREATE TEMP TABLE IF NOT EXISTS temp_questions (
    af_name text,
    atmp_code text,
    atq_code text,
    atq_text text,
    atq_response_type text,
    atq_question_type text,
    atq_is_mandatory text,
    atq_is_active text,
    atq_sequence integer
);

-- Clear any existing data
TRUNCATE temp_questions;

-- Load CSV data
\copy temp_questions FROM './data/assessment_template_question.csv' WITH (FORMAT csv, HEADER)

-- Main logic with error handling
DO $$
DECLARE
    v_tenant_id uuid;
    v_created_by uuid;
    v_framework_id uuid;
    v_template_id uuid;
    v_tenant_name text := current_setting('vars.tenant_name');
    v_username text := current_setting('vars.username');
    v_inserted_count int := 0;
    v_missing_frameworks text := '';
    v_missing_templates text := '';
    rec record;
BEGIN
    -- Tenant lookup
    SELECT t.tenant_id INTO v_tenant_id
    FROM public.tenant t
    WHERE t.tn_tenant_name = v_tenant_name;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Tenant not found: "%"', v_tenant_name
            USING ERRCODE = 'P0001';
    END IF;

    -- User lookup
    SELECT tu.tenant_user_id INTO v_created_by
    FROM public.tenant_user tu
    JOIN public.tenant t ON tu.tenant_idref = t.tenant_id
    WHERE tu.tu_username = v_username AND t.tenant_id = v_tenant_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'User not found: "%" in tenant "%"', v_username, v_tenant_name
            USING ERRCODE = 'P0002';
    END IF;

    RAISE NOTICE 'Using tenant: % | user: %', v_tenant_id, v_created_by;

    -- Validate all frameworks exist before inserting
    FOR rec IN SELECT DISTINCT af_name FROM temp_questions LOOP
        SELECT af.assessment_framework_id INTO v_framework_id
        FROM public.assessment_framework af
        WHERE af.tenant_idref = v_tenant_id
        AND af.af_name = rec.af_name;

        IF NOT FOUND THEN
            v_missing_frameworks := v_missing_frameworks || ', ' || rec.af_name;
        END IF;
    END LOOP;

    IF v_missing_frameworks != '' THEN
        RAISE EXCEPTION 'Assessment frameworks not found: %', ltrim(v_missing_frameworks, ', ')
            USING ERRCODE = 'P0003';
    END IF;

    -- Validate all templates exist before inserting
    FOR rec IN SELECT DISTINCT atmp_code FROM temp_questions LOOP
        SELECT atpl.assessment_template_id INTO v_template_id
        FROM public.assessment_template atpl
        WHERE atpl.tenant_idref = v_tenant_id
        AND atpl.atmp_code = rec.atmp_code;

        IF NOT FOUND THEN
            v_missing_templates := v_missing_templates || ', ' || rec.atmp_code;
        END IF;
    END LOOP;

    IF v_missing_templates != '' THEN
        RAISE EXCEPTION 'Assessment templates not found: %', ltrim(v_missing_templates, ', ')
            USING ERRCODE = 'P0004';
    END IF;

    -- Insert questions
    INSERT INTO public.assessment_template_question (
        tenant_idref,
        assessment_template_idref,
        assessment_framework_idref,
        atq_code,
        atq_text,
        atq_response_type,
        atq_question_type,
        atq_is_mandatory,
        atq_is_active,
        atq_sequence,
        created_by_user_id,
        created_at,
        updated_by_user_id,
        updated_at
    )
    SELECT
        v_tenant_id,
        atpl.assessment_template_id,
        af.assessment_framework_id,
        tq.atq_code,
        tq.atq_text,
        tq.atq_response_type,
        tq.atq_question_type,
        tq.atq_is_mandatory,
        tq.atq_is_active,
        tq.atq_sequence,
        v_created_by,
        NOW(),
        v_created_by,
        NOW()
    FROM temp_questions tq
    JOIN public.assessment_framework af ON af.tenant_idref = v_tenant_id AND af.af_name = tq.af_name
    JOIN public.assessment_template atpl ON atpl.tenant_idref = v_tenant_id AND atpl.atmp_code = tq.atmp_code
    WHERE NOT EXISTS (
        SELECT 1 FROM public.assessment_template_question atq
        WHERE atq.tenant_idref = v_tenant_id
        AND atq.atq_code = tq.atq_code
    );

    GET DIAGNOSTICS v_inserted_count = ROW_COUNT;

    RAISE NOTICE 'Inserted % question(s)', v_inserted_count;

EXCEPTION
    WHEN SQLSTATE 'P0001' THEN
        RAISE NOTICE 'Tip: Check tenant.tn_tenant_name = "%"', v_tenant_name;
        RAISE;
    WHEN SQLSTATE 'P0002' THEN
        RAISE NOTICE 'Tip: Check tenant_user.tu_username = "%" for tenant "%"', v_username, v_tenant_name;
        RAISE;
    WHEN SQLSTATE 'P0003' THEN
        RAISE NOTICE 'Tip: Run assessment_framework seed first to create missing frameworks';
        RAISE;
    WHEN SQLSTATE 'P0004' THEN
        RAISE NOTICE 'Tip: Run assessment_template seed first to create missing templates';
        RAISE;
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Seed failed: %', SQLERRM;
END $$;

-- Clean up
DROP TABLE IF EXISTS temp_questions;