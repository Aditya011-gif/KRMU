-- ============================================================
-- Agri-Score: Fix Missing Land Details Table
-- Run this in Supabase Dashboard → SQL Editor
-- ============================================================

-- 1. Create the table
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

-- 2. Create Indexes
CREATE INDEX IF NOT EXISTS idx_land_details_user ON public.land_details(user_id);
CREATE INDEX IF NOT EXISTS idx_land_details_created ON public.land_details(created_at DESC);

-- 3. Enable RLS
ALTER TABLE public.land_details ENABLE ROW LEVEL SECURITY;

-- 4. Create RLS Policies

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
-- Note: Requires is_admin() function to exist (from main migration)
DROP POLICY IF EXISTS "Admins can view all land details" ON public.land_details;
CREATE POLICY "Admins can view all land details"
    ON public.land_details FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE id = auth.uid() AND role = 'admin'
        )
    );
