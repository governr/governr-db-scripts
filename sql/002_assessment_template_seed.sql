-- Assessment Template Seed Script
-- Run using: python scripts/run_seed.py --tenant "tenant_name" --username "username" --sql-file sql/002_assessment_template_seed.sql
--
-- Requires psql variables: tenant_name, username

-- Create temp table (persists for session)
CREATE TEMP TABLE IF NOT EXISTS temp_templates (
    af_name text,
    atmp_name text,
    atmp_code text,
    atmp_version numeric,
    atmp_status text,
    atmp_is_active text
);

-- Clear any existing data
TRUNCATE temp_templates;

-- Load CSV data
\copy temp_templates FROM './data/assessment_template.csv' WITH (FORMAT csv, HEADER)

-- Main logic with error handling
DO $$
DECLARE
    v_tenant_id uuid;
    v_created_by uuid;
    v_framework_id uuid;
    v_tenant_name text := current_setting('vars.tenant_name');
    v_username text := current_setting('vars.username');
    v_inserted_count int := 0;
    v_missing_frameworks text := '';
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
    FOR rec IN SELECT DISTINCT af_name FROM temp_templates LOOP
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

    -- Insert templates
    INSERT INTO public.assessment_template (
        tenant_idref,
        assessment_framework_idref,
        atmp_name,
        atmp_code,
        atmp_version,
        atmp_status,
        atmp_is_active,
        created_by_user_id,
        created_at,
        updated_by_user_id,
        updated_at
    )
    SELECT
        v_tenant_id,
        af.assessment_framework_id,
        tt.atmp_name,
        tt.atmp_code,
        tt.atmp_version,
        tt.atmp_status,
        tt.atmp_is_active,
        v_created_by,
        NOW(),
        v_created_by,
        NOW()
    FROM temp_templates tt
    JOIN public.assessment_framework af ON af.tenant_idref = v_tenant_id AND af.af_name = tt.af_name
    WHERE NOT EXISTS (
        SELECT 1 FROM public.assessment_template atpl
        WHERE atpl.tenant_idref = v_tenant_id
        AND atpl.atmp_code = tt.atmp_code
    );

    GET DIAGNOSTICS v_inserted_count = ROW_COUNT;

    RAISE NOTICE 'Inserted % template(s)', v_inserted_count;

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
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Seed failed: %', SQLERRM;
END $$;

-- Clean up
DROP TABLE IF EXISTS temp_templates;