-- Assessment Framework Seed Script
-- Run using: python scripts/run_seed.py --tenant "tenant_name" --username "username"
--
-- Requires psql variables: tenant_name, username

-- Create temp table (persists for session)
CREATE TEMP TABLE IF NOT EXISTS temp_frameworks (
    af_name text,
    af_version numeric,
    af_framework_type text,
    af_framework_status text,
    af_is_primary text
);

-- Clear any existing data
TRUNCATE temp_frameworks;

-- Load CSV data
\copy temp_frameworks FROM './data/assessment_framework.csv' WITH (FORMAT csv, HEADER)

-- Main logic with error handling
DO $$
DECLARE
    v_tenant_id uuid;
    v_created_by uuid;
    v_tenant_name text := current_setting('vars.tenant_name');
    v_username text := current_setting('vars.username');
    v_inserted_count int := 0;
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

    -- Insert frameworks
    INSERT INTO public.assessment_framework (
        tenant_idref,
        af_name,
        af_version,
        af_framework_type,
        af_framework_status,
        af_is_primary,
        created_by_user_id,
        created_at,
        updated_by_user_id,
        updated_at
    )
    SELECT
        v_tenant_id,
        tf.af_name,
        tf.af_version,
        tf.af_framework_type,
        tf.af_framework_status,
        tf.af_is_primary,
        v_created_by,
        NOW(),
        v_created_by,
        NOW()
    FROM temp_frameworks tf
    WHERE NOT EXISTS (
        SELECT 1 FROM public.assessment_framework af
        WHERE af.tenant_idref = v_tenant_id
        AND af.af_name = tf.af_name
        AND af.af_version = tf.af_version
    );

    GET DIAGNOSTICS v_inserted_count = ROW_COUNT;

    RAISE NOTICE 'Inserted % framework(s)', v_inserted_count;

EXCEPTION
    WHEN SQLSTATE 'P0001' THEN
        RAISE NOTICE 'Tip: Check tenant.tn_tenant_name = "%"', v_tenant_name;
        RAISE;
    WHEN SQLSTATE 'P0002' THEN
        RAISE NOTICE 'Tip: Check tenant_user.tu_username = "%" for tenant "%"', v_username, v_tenant_name;
        RAISE;
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Seed failed: %', SQLERRM;
END $$;

-- Clean up
DROP TABLE IF EXISTS temp_frameworks;