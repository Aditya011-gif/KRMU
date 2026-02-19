-- ============================================================
-- Agri-Score: Add Document Columns & Storage Policies
-- Run this in Supabase Dashboard → SQL Editor
-- ============================================================

-- 1. Add columns to land_details table
-- storing paths/urls as array of text
ALTER TABLE public.land_details 
ADD COLUMN IF NOT EXISTS loan_documents TEXT[],
ADD COLUMN IF NOT EXISTS ownership_documents TEXT[];

-- 2. Create Storage Bucket (if not exists)
-- Note: You normally do this via Dashboard, but this script attempts to insert if using sql-storage extension
-- INSERT INTO storage.buckets (id, name, public) VALUES ('land_documents', 'land_documents', true) ON CONFLICT DO NOTHING;

-- 3. Storage Policies for 'land_documents' bucket

-- Allow authenticated users to upload files
-- DROP POLICY IF EXISTS "Farmers can upload documents" ON storage.objects;
-- CREATE POLICY "Farmers can upload documents"
-- ON storage.objects FOR INSERT
-- WITH CHECK ( bucket_id = 'land_documents' AND auth.role() = 'authenticated' );

-- Allow users to view their own files (or all public files if bucket is public)
-- DROP POLICY IF EXISTS "Farmers can view documents" ON storage.objects;
-- CREATE POLICY "Farmers can view documents"
-- ON storage.objects FOR SELECT
-- USING ( bucket_id = 'land_documents' );
