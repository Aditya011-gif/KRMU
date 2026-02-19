-- ============================================================
-- Agri-Score: Supabase Database Migration
-- Run this in Supabase Dashboard → SQL Editor
-- ============================================================

-- ── Users Table ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    phone TEXT,
    state TEXT,
    district TEXT,
    farm_size DOUBLE PRECISION,
    role TEXT NOT NULL DEFAULT 'farmer' CHECK (role IN ('farmer', 'admin')),
    created_at TIMESTAMPTZ DEFAULT now()
);

-- ── Land Analysis Table ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.land_analysis (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    ndvi_value DOUBLE PRECISION,
    soil_type TEXT,
    land_class TEXT,
    weather_index DOUBLE PRECISION,
    market_index DOUBLE PRECISION,
    agri_score DOUBLE PRECISION NOT NULL,
    risk_category TEXT NOT NULL CHECK (risk_category IN ('Low', 'Medium', 'High', 'Flagged')),
    score_breakdown JSONB,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- ── Audit Logs Table ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    action TEXT NOT NULL,
    metadata JSONB,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- ── Land Details Table ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.land_details (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    land_area DOUBLE PRECISION,
    area_unit TEXT DEFAULT 'Acres' CHECK (area_unit IN ('Acres', 'Hectares')),
    crop_type TEXT,
    crop_quality_grade TEXT,
    current_season TEXT CHECK (current_season IN ('Kharif', 'Rabi', 'Zaid')),
    past_loan_amount DOUBLE PRECISION,
    loan_provider TEXT,
    loan_status TEXT CHECK (loan_status IN ('Active', 'Closed', 'Defaulted')),
    created_at TIMESTAMPTZ DEFAULT now()
);

-- ── Indexes ──────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_land_analysis_user_id ON public.land_analysis(user_id);
CREATE INDEX IF NOT EXISTS idx_land_analysis_created_at ON public.land_analysis(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_land_analysis_risk ON public.land_analysis(risk_category);
CREATE INDEX IF NOT EXISTS idx_land_analysis_score ON public.land_analysis(agri_score);
CREATE INDEX IF NOT EXISTS idx_users_role ON public.users(role);
CREATE INDEX IF NOT EXISTS idx_users_state ON public.users(state);
CREATE INDEX IF NOT EXISTS idx_users_district ON public.users(district);
CREATE INDEX IF NOT EXISTS idx_audit_logs_user ON public.audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created ON public.audit_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_land_details_user ON public.land_details(user_id);
CREATE INDEX IF NOT EXISTS idx_land_details_created ON public.land_details(created_at DESC);

-- ── Enable Row Level Security ────────────────────────────────
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.land_analysis ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.land_details ENABLE ROW LEVEL SECURITY;

-- ── Helper Functions ─────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public.users
    WHERE id = auth.uid() AND role = 'admin'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ── RLS Policies: Users ──────────────────────────────────────
-- Users can read their own profile
DROP POLICY IF EXISTS "Users can view own profile" ON public.users;
CREATE POLICY "Users can view own profile"
    ON public.users FOR SELECT
    USING (auth.uid() = id);

-- Users can update their own profile
DROP POLICY IF EXISTS "Users can update own profile" ON public.users;
CREATE POLICY "Users can update own profile"
    ON public.users FOR UPDATE
    USING (auth.uid() = id);

-- Service role (backend) can insert users
DROP POLICY IF EXISTS "Service role can insert users" ON public.users;
CREATE POLICY "Service role can insert users"
    ON public.users FOR INSERT
    WITH CHECK (true);

-- Admins can view all users (Fixed recursion using Security Definer)
DROP POLICY IF EXISTS "Admins can view all users" ON public.users;
CREATE POLICY "Admins can view all users"
    ON public.users FOR SELECT
    USING (is_admin());

-- ── RLS Policies: Land Analysis ──────────────────────────────
-- Farmers can only see their own analyses
DROP POLICY IF EXISTS "Farmers can view own analyses" ON public.land_analysis;
CREATE POLICY "Farmers can view own analyses"
    ON public.land_analysis FOR SELECT
    USING (auth.uid() = user_id);

-- Service role (backend) can insert analyses
DROP POLICY IF EXISTS "Service role can insert analyses" ON public.land_analysis;
CREATE POLICY "Service role can insert analyses"
    ON public.land_analysis FOR INSERT
    WITH CHECK (true);

-- Service role can update analyses (for flagging)
DROP POLICY IF EXISTS "Service role can update analyses" ON public.land_analysis;
CREATE POLICY "Service role can update analyses"
    ON public.land_analysis FOR UPDATE
    USING (true);

-- Admins can view all analyses
DROP POLICY IF EXISTS "Admins can view all analyses" ON public.land_analysis;
CREATE POLICY "Admins can view all analyses"
    ON public.land_analysis FOR SELECT
    USING (is_admin());

-- ── RLS Policies: Audit Logs ─────────────────────────────────
-- Only admins can view audit logs
DROP POLICY IF EXISTS "Admins can view audit logs" ON public.audit_logs;
CREATE POLICY "Admins can view audit logs"
    ON public.audit_logs FOR SELECT
    USING (is_admin());

-- Service role can insert audit logs
DROP POLICY IF EXISTS "Service role can insert audit logs" ON public.audit_logs;
CREATE POLICY "Service role can insert audit logs"
    ON public.audit_logs FOR INSERT
    WITH CHECK (true);

-- ── RLS Policies: Land Details ──────────────────────────────
-- Farmers can view own land details
DROP POLICY IF EXISTS "Farmers can view own land details" ON public.land_details;
CREATE POLICY "Farmers can view own land details"
    ON public.land_details FOR SELECT
    USING (auth.uid() = user_id);

-- Farmers can insert own land details
DROP POLICY IF EXISTS "Farmers can insert own land details" ON public.land_details;
CREATE POLICY "Farmers can insert own land details"
    ON public.land_details FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Admins can view all land details
DROP POLICY IF EXISTS "Admins can view all land details" ON public.land_details;
CREATE POLICY "Admins can view all land details"
    ON public.land_details FOR SELECT
    USING (is_admin());
