-- Migration: Schema Drift Diagnostic
-- Description: Comprehensive diagnostic script to detect schema inconsistencies and missing columns.
--              Reports current state of tables, columns, constraints, and RLS policies.
--              Safe to run multiple times - read-only, no schema changes.
-- Sprint: Schema Repair
--
-- This migration is RE-RUNNABLE and makes NO changes to the database.
-- It only reports findings via RAISE NOTICE statements.

DO $$
DECLARE
  v_table_exists BOOLEAN;
  v_column_exists BOOLEAN;
  v_constraint_exists BOOLEAN;
  v_index_exists BOOLEAN;
  v_policy_count INTEGER;
  v_function_exists BOOLEAN;
  v_view_exists BOOLEAN;
BEGIN
  RAISE NOTICE '============================================================';
  RAISE NOTICE 'SCHEMA DRIFT DIAGNOSTIC REPORT';
  RAISE NOTICE 'Timestamp: %', NOW();
  RAISE NOTICE '============================================================';
  RAISE NOTICE '';

  -- ==========================================================================
  -- SECTION 1: TABLE EXISTENCE CHECK
  -- ==========================================================================
  RAISE NOTICE '--- SECTION 1: TABLE EXISTENCE ---';
  RAISE NOTICE '';

  -- Check for organizations vs customers naming
  SELECT EXISTS (
    SELECT FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'organizations'
  ) INTO v_table_exists;
  RAISE NOTICE 'Table [organizations]: %', CASE WHEN v_table_exists THEN '✓ EXISTS' ELSE '✗ MISSING' END;

  SELECT EXISTS (
    SELECT FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'customers'
  ) INTO v_table_exists;
  RAISE NOTICE 'Table [customers]: %', CASE WHEN v_table_exists THEN '✓ EXISTS' ELSE '✗ MISSING' END;

  -- Check for users vs profiles naming
  SELECT EXISTS (
    SELECT FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'users'
  ) INTO v_table_exists;
  RAISE NOTICE 'Table [users]: %', CASE WHEN v_table_exists THEN '✓ EXISTS' ELSE '✗ MISSING' END;

  SELECT EXISTS (
    SELECT FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'profiles'
  ) INTO v_table_exists;
  RAISE NOTICE 'Table [profiles]: %', CASE WHEN v_table_exists THEN '✓ EXISTS' ELSE '✗ MISSING' END;

  -- Check core business tables
  SELECT EXISTS (
    SELECT FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'projects'
  ) INTO v_table_exists;
  RAISE NOTICE 'Table [projects]: %', CASE WHEN v_table_exists THEN '✓ EXISTS' ELSE '✗ MISSING' END;

  SELECT EXISTS (
    SELECT FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'invoices'
  ) INTO v_table_exists;
  RAISE NOTICE 'Table [invoices]: %', CASE WHEN v_table_exists THEN '✓ EXISTS' ELSE '✗ MISSING' END;

  SELECT EXISTS (
    SELECT FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'invoice_events'
  ) INTO v_table_exists;
  RAISE NOTICE 'Table [invoice_events]: %', CASE WHEN v_table_exists THEN '✓ EXISTS' ELSE '✗ MISSING' END;

  SELECT EXISTS (
    SELECT FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'file_assets'
  ) INTO v_table_exists;
  RAISE NOTICE 'Table [file_assets]: %', CASE WHEN v_table_exists THEN '✓ EXISTS (used for proofs)' ELSE '✗ MISSING' END;

  SELECT EXISTS (
    SELECT FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'shipments'
  ) INTO v_table_exists;
  RAISE NOTICE 'Table [shipments]: %', CASE WHEN v_table_exists THEN '✓ EXISTS' ELSE '✗ MISSING' END;

  RAISE NOTICE '';

  -- ==========================================================================
  -- SECTION 2: CRITICAL COLUMN EXISTENCE (organization_id vs customer_id)
  -- ==========================================================================
  RAISE NOTICE '--- SECTION 2: CRITICAL COLUMNS ---';
  RAISE NOTICE '';

  -- Check projects table columns
  IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'projects') THEN
    SELECT EXISTS (
      SELECT FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'projects' AND column_name = 'organization_id'
    ) INTO v_column_exists;
    RAISE NOTICE 'Column [projects.organization_id]: %', CASE WHEN v_column_exists THEN '✓ EXISTS' ELSE '✗ MISSING' END;

    SELECT EXISTS (
      SELECT FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'projects' AND column_name = 'customer_id'
    ) INTO v_column_exists;
    RAISE NOTICE 'Column [projects.customer_id]: %', CASE WHEN v_column_exists THEN '✓ EXISTS' ELSE '✗ MISSING' END;
  ELSE
    RAISE NOTICE 'Column [projects.*]: ✗ TABLE DOES NOT EXIST';
  END IF;

  -- Check invoices table columns
  IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'invoices') THEN
    SELECT EXISTS (
      SELECT FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'invoices' AND column_name = 'organization_id'
    ) INTO v_column_exists;
    RAISE NOTICE 'Column [invoices.organization_id]: %', CASE WHEN v_column_exists THEN '✓ EXISTS' ELSE '✗ MISSING' END;

    SELECT EXISTS (
      SELECT FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'invoices' AND column_name = 'customer_id'
    ) INTO v_column_exists;
    RAISE NOTICE 'Column [invoices.customer_id]: %', CASE WHEN v_column_exists THEN '✓ EXISTS' ELSE '✗ MISSING' END;
  ELSE
    RAISE NOTICE 'Column [invoices.*]: ✗ TABLE DOES NOT EXIST';
  END IF;

  -- Check users/profiles table columns
  IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'users') THEN
    SELECT EXISTS (
      SELECT FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'users' AND column_name = 'organization_id'
    ) INTO v_column_exists;
    RAISE NOTICE 'Column [users.organization_id]: %', CASE WHEN v_column_exists THEN '✓ EXISTS' ELSE '✗ MISSING' END;

    SELECT EXISTS (
      SELECT FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'users' AND column_name = 'customer_id'
    ) INTO v_column_exists;
    RAISE NOTICE 'Column [users.customer_id]: %', CASE WHEN v_column_exists THEN '✓ EXISTS' ELSE '✗ MISSING' END;
  ELSIF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'profiles') THEN
    SELECT EXISTS (
      SELECT FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'organization_id'
    ) INTO v_column_exists;
    RAISE NOTICE 'Column [profiles.organization_id]: %', CASE WHEN v_column_exists THEN '✓ EXISTS' ELSE '✗ MISSING' END;

    SELECT EXISTS (
      SELECT FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'customer_id'
    ) INTO v_column_exists;
    RAISE NOTICE 'Column [profiles.customer_id]: %', CASE WHEN v_column_exists THEN '✓ EXISTS' ELSE '✗ MISSING' END;
  ELSE
    RAISE NOTICE 'Column [users/profiles.*]: ✗ TABLE DOES NOT EXIST';
  END IF;

  -- Check file_assets (proofs) - should have project_id but NOT customer_id
  IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'file_assets') THEN
    SELECT EXISTS (
      SELECT FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'file_assets' AND column_name = 'project_id'
    ) INTO v_column_exists;
    RAISE NOTICE 'Column [file_assets.project_id]: %', CASE WHEN v_column_exists THEN '✓ EXISTS (correct)' ELSE '✗ MISSING' END;

    SELECT EXISTS (
      SELECT FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'file_assets' AND column_name = 'organization_id'
    ) INTO v_column_exists;
    RAISE NOTICE 'Column [file_assets.organization_id]: %', CASE WHEN v_column_exists THEN '✓ EXISTS (for RLS)' ELSE '✗ MISSING' END;
  END IF;

  -- Check shipments - should have project_id but NOT customer_id directly
  IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'shipments') THEN
    SELECT EXISTS (
      SELECT FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'shipments' AND column_name = 'project_id'
    ) INTO v_column_exists;
    RAISE NOTICE 'Column [shipments.project_id]: %', CASE WHEN v_column_exists THEN '✓ EXISTS (correct)' ELSE '✗ MISSING' END;

    SELECT EXISTS (
      SELECT FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'shipments' AND column_name = 'organization_id'
    ) INTO v_column_exists;
    RAISE NOTICE 'Column [shipments.organization_id]: %', CASE WHEN v_column_exists THEN '✓ EXISTS (for RLS)' ELSE '✗ MISSING' END;
  END IF;

  RAISE NOTICE '';

  -- ==========================================================================
  -- SECTION 3: FOREIGN KEY CONSTRAINTS
  -- ==========================================================================
  RAISE NOTICE '--- SECTION 3: FOREIGN KEY CONSTRAINTS ---';
  RAISE NOTICE '';

  -- Projects foreign keys
  IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'projects') THEN
    SELECT EXISTS (
      SELECT FROM information_schema.table_constraints tc
      JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name
      WHERE tc.table_schema = 'public'
        AND tc.table_name = 'projects'
        AND kcu.column_name = 'organization_id'
        AND tc.constraint_type = 'FOREIGN KEY'
    ) INTO v_constraint_exists;
    RAISE NOTICE 'FK [projects.organization_id -> organizations.id]: %', CASE WHEN v_constraint_exists THEN '✓ EXISTS' ELSE '✗ MISSING' END;
  END IF;

  -- Invoices foreign keys
  IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'invoices') THEN
    SELECT EXISTS (
      SELECT FROM information_schema.table_constraints tc
      JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name
      WHERE tc.table_schema = 'public'
        AND tc.table_name = 'invoices'
        AND kcu.column_name = 'organization_id'
        AND tc.constraint_type = 'FOREIGN KEY'
    ) INTO v_constraint_exists;
    RAISE NOTICE 'FK [invoices.organization_id -> organizations.id]: %', CASE WHEN v_constraint_exists THEN '✓ EXISTS' ELSE '✗ MISSING' END;

    SELECT EXISTS (
      SELECT FROM information_schema.table_constraints tc
      JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name
      WHERE tc.table_schema = 'public'
        AND tc.table_name = 'invoices'
        AND kcu.column_name = 'project_id'
        AND tc.constraint_type = 'FOREIGN KEY'
    ) INTO v_constraint_exists;
    RAISE NOTICE 'FK [invoices.project_id -> projects.id]: %', CASE WHEN v_constraint_exists THEN '✓ EXISTS' ELSE '✗ MISSING' END;
  END IF;

  RAISE NOTICE '';

  -- ==========================================================================
  -- SECTION 4: RLS HELPER FUNCTIONS
  -- ==========================================================================
  RAISE NOTICE '--- SECTION 4: RLS HELPER FUNCTIONS ---';
  RAISE NOTICE '';

  -- Check for helper functions
  SELECT EXISTS (
    SELECT FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'auth' AND p.proname = 'is_internal_user'
  ) INTO v_function_exists;
  RAISE NOTICE 'Function [auth.is_internal_user()]: %', CASE WHEN v_function_exists THEN '✓ EXISTS' ELSE '✗ MISSING' END;

  SELECT EXISTS (
    SELECT FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'auth' AND p.proname = 'user_organization_id'
  ) INTO v_function_exists;
  RAISE NOTICE 'Function [auth.user_organization_id()]: %', CASE WHEN v_function_exists THEN '✓ EXISTS' ELSE '✗ MISSING' END;

  SELECT EXISTS (
    SELECT FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'auth' AND p.proname = 'user_customer_id'
  ) INTO v_function_exists;
  RAISE NOTICE 'Function [auth.user_customer_id()]: %', CASE WHEN v_function_exists THEN '✓ EXISTS' ELSE '✗ MISSING' END;

  SELECT EXISTS (
    SELECT FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'auth' AND p.proname = 'user_role'
  ) INTO v_function_exists;
  RAISE NOTICE 'Function [auth.user_role()]: %', CASE WHEN v_function_exists THEN '✓ EXISTS' ELSE '✗ MISSING' END;

  SELECT EXISTS (
    SELECT FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'auth' AND p.proname = 'is_admin'
  ) INTO v_function_exists;
  RAISE NOTICE 'Function [auth.is_admin()]: %', CASE WHEN v_function_exists THEN '✓ EXISTS' ELSE '✗ MISSING' END;

  SELECT EXISTS (
    SELECT FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'auth' AND p.proname = 'is_staff'
  ) INTO v_function_exists;
  RAISE NOTICE 'Function [auth.is_staff()]: %', CASE WHEN v_function_exists THEN '✓ EXISTS' ELSE '✗ MISSING' END;

  RAISE NOTICE '';

  -- ==========================================================================
  -- SECTION 5: RLS POLICIES
  -- ==========================================================================
  RAISE NOTICE '--- SECTION 5: RLS POLICIES ---';
  RAISE NOTICE '';

  -- Check RLS enabled on tables
  IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'projects') THEN
    SELECT relrowsecurity FROM pg_class WHERE relname = 'projects' INTO v_table_exists;
    RAISE NOTICE 'RLS Enabled [projects]: %', CASE WHEN v_table_exists THEN '✓ YES' ELSE '✗ NO' END;

    SELECT COUNT(*) FROM pg_policies WHERE schemaname = 'public' AND tablename = 'projects' INTO v_policy_count;
    RAISE NOTICE 'RLS Policies [projects]: % policies found', v_policy_count;
  END IF;

  IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'invoices') THEN
    SELECT relrowsecurity FROM pg_class WHERE relname = 'invoices' INTO v_table_exists;
    RAISE NOTICE 'RLS Enabled [invoices]: %', CASE WHEN v_table_exists THEN '✓ YES' ELSE '✗ NO' END;

    SELECT COUNT(*) FROM pg_policies WHERE schemaname = 'public' AND tablename = 'invoices' INTO v_policy_count;
    RAISE NOTICE 'RLS Policies [invoices]: % policies found', v_policy_count;
  END IF;

  IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'file_assets') THEN
    SELECT relrowsecurity FROM pg_class WHERE relname = 'file_assets' INTO v_table_exists;
    RAISE NOTICE 'RLS Enabled [file_assets]: %', CASE WHEN v_table_exists THEN '✓ YES' ELSE '✗ NO' END;

    SELECT COUNT(*) FROM pg_policies WHERE schemaname = 'public' AND tablename = 'file_assets' INTO v_policy_count;
    RAISE NOTICE 'RLS Policies [file_assets]: % policies found', v_policy_count;
  END IF;

  IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'shipments') THEN
    SELECT relrowsecurity FROM pg_class WHERE relname = 'shipments' INTO v_table_exists;
    RAISE NOTICE 'RLS Enabled [shipments]: %', CASE WHEN v_table_exists THEN '✓ YES' ELSE '✗ NO' END;

    SELECT COUNT(*) FROM pg_policies WHERE schemaname = 'public' AND tablename = 'shipments' INTO v_policy_count;
    RAISE NOTICE 'RLS Policies [shipments]: % policies found', v_policy_count;
  END IF;

  RAISE NOTICE '';

  -- ==========================================================================
  -- SECTION 6: VIEWS
  -- ==========================================================================
  RAISE NOTICE '--- SECTION 6: VIEWS ---';
  RAISE NOTICE '';

  SELECT EXISTS (
    SELECT FROM information_schema.views
    WHERE table_schema = 'public' AND table_name = 'internal_action_queue'
  ) INTO v_view_exists;
  RAISE NOTICE 'View [internal_action_queue]: %', CASE WHEN v_view_exists THEN '✓ EXISTS' ELSE '✗ MISSING' END;

  RAISE NOTICE '';

  -- ==========================================================================
  -- SECTION 7: SCHEMA DRIFT SUMMARY
  -- ==========================================================================
  RAISE NOTICE '--- SECTION 7: DRIFT SUMMARY & RECOMMENDATIONS ---';
  RAISE NOTICE '';

  -- Determine schema variant
  IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'organizations') THEN
    RAISE NOTICE '✓ Schema uses ORGANIZATIONS model (organizations + users)';
  ELSIF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'customers') THEN
    RAISE NOTICE '✓ Schema uses CUSTOMERS model (customers + profiles)';
  ELSE
    RAISE NOTICE '✗ CRITICAL: No base organization/customer table found!';
  END IF;

  -- Check for missing critical columns
  IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'projects') THEN
    IF NOT EXISTS (
      SELECT FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'projects'
      AND column_name IN ('organization_id', 'customer_id')
    ) THEN
      RAISE NOTICE '✗ WARNING: projects table missing organization/customer reference!';
    END IF;
  END IF;

  IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'invoices') THEN
    IF NOT EXISTS (
      SELECT FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'invoices'
      AND column_name IN ('organization_id', 'customer_id')
    ) THEN
      RAISE NOTICE '✗ WARNING: invoices table missing organization/customer reference!';
    END IF;
  END IF;

  RAISE NOTICE '';
  RAISE NOTICE '============================================================';
  RAISE NOTICE 'DIAGNOSTIC COMPLETE';
  RAISE NOTICE '============================================================';
  RAISE NOTICE '';
  RAISE NOTICE 'Next Steps:';
  RAISE NOTICE '  1. Review warnings above';
  RAISE NOTICE '  2. Run repair migration: 99999999999902_repair_customer_id_drift.sql';
  RAISE NOTICE '  3. Verify RLS policies are functioning correctly';
  RAISE NOTICE '';

END $$;

-- Add comment on this migration
COMMENT ON EXTENSION IF EXISTS plpgsql IS
  'Diagnostic migration 99999999999901 completed - check server logs for NOTICE output';
