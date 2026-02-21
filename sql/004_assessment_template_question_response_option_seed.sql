-- Assessment Template Question Response Option Seed Script
-- Run using: python scripts/run_seed.py --tenant "tenant_name" --username "username" --sql-file sql/004_assessment_template_question_response_option_seed.sql
--
-- Requires psql variables: tenant_name, username

-- Create temp table (persists for session)
CREATE TEMP TABLE IF NOT EXISTS temp_response_options (
    atq_code text,
    atqro_code text,
    atqro_label text,
    atqro_sequence integer,
    atqro_is_default text,
    atqro_is_active text,
    atqro_score_risk numeric
);

-- Clear any existing data
TRUNCATE temp_response_options;

-- Load CSV data (path replaced by Python before execution)
\copy temp_response_options FROM 'CSV_PATH_PLACEHOLDER' WITH (FORMAT csv, HEADER)

-- Main logic with error handling
DO $$
DECLARE
    v_tenant_id uuid;
    v_created_by uuid;
    v_question_id uuid;
    v_tenant_name text := current_setting('vars.tenant_name');
    v_username text := current_setting('vars.username');
    v_inserted_count int := 0;
    v_missing_questions text := '';
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

    -- Validate all questions exist before inserting
    FOR rec IN SELECT DISTINCT atq_code FROM temp_response_options LOOP
        SELECT atq.assessment_template_question_id INTO v_question_id
        FROM public.assessment_template_question atq
        WHERE atq.tenant_idref = v_tenant_id
        AND atq.atq_code = rec.atq_code;

        IF NOT FOUND THEN
            v_missing_questions := v_missing_questions || ', ' || rec.atq_code;
        END IF;
    END LOOP;

    IF v_missing_questions != '' THEN
        RAISE EXCEPTION 'Assessment template questions not found: %', ltrim(v_missing_questions, ', ')
            USING ERRCODE = 'P0003';
    END IF;

    -- Insert response options
    INSERT INTO public.assessment_template_question_response_option (
        tenant_idref,
        assessment_template_question_idref,
        atqro_code,
        atqro_label,
        atqro_sequence,
        atqro_is_default,
        atqro_is_active,
        atqro_score_risk,
        created_by_user_id,
        created_at,
        updated_by_user_id,
        updated_at
    )
    SELECT
        v_tenant_id,
        atq.assessment_template_question_id,
        tro.atqro_code,
        tro.atqro_label,
        tro.atqro_sequence,
        tro.atqro_is_default,
        tro.atqro_is_active,
        tro.atqro_score_risk,
        v_created_by,
        NOW(),
        v_created_by,
        NOW()
    FROM temp_response_options tro
    JOIN public.assessment_template_question atq ON atq.tenant_idref = v_tenant_id AND atq.atq_code = tro.atq_code
    WHERE NOT EXISTS (
        SELECT 1 FROM public.assessment_template_question_response_option existing
        WHERE existing.tenant_idref = v_tenant_id
        AND existing.atqro_code = tro.atqro_code
    );

    GET DIAGNOSTICS v_inserted_count = ROW_COUNT;

    RAISE NOTICE 'Inserted % response option(s)', v_inserted_count;

EXCEPTION
    WHEN SQLSTATE 'P0001' THEN
        RAISE NOTICE 'Tip: Check tenant.tn_tenant_name = "%"', v_tenant_name;
        RAISE;
    WHEN SQLSTATE 'P0002' THEN
        RAISE NOTICE 'Tip: Check tenant_user.tu_username = "%" for tenant "%"', v_username, v_tenant_name;
        RAISE;
    WHEN SQLSTATE 'P0003' THEN
        RAISE NOTICE 'Tip: Run assessment_template_question seed first to create missing questions';
        RAISE;
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Seed failed: %', SQLERRM;
END $$;

-- Clean up
DROP TABLE IF EXISTS temp_response_options;