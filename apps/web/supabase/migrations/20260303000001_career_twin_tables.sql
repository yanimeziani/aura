-- Migration: Career Twin Tables
-- Date: 2026-03-03
-- Description: Tables for Career Digital Twin agent tracking

-- Enable UUID extension if not already enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE IF NOT EXISTS career_applications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id),
  company_name TEXT NOT NULL,
  position TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'applied', -- applied, interview, offer, rejected
  applied_at TIMESTAMPTZ DEFAULT now(),
  last_contact TIMESTAMPTZ,
  notes TEXT,
  metadata JSONB DEFAULT '{}'::jsonb
);

CREATE TABLE IF NOT EXISTS career_interactions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  application_id UUID REFERENCES career_applications(id) ON DELETE CASCADE,
  type TEXT NOT NULL, -- email, call, interview
  direction TEXT NOT NULL, -- inbound, outbound
  summary TEXT,
  occurred_at TIMESTAMPTZ DEFAULT now(),
  metadata JSONB DEFAULT '{}'::jsonb
);

-- Enable RLS
ALTER TABLE career_applications ENABLE ROW LEVEL SECURITY;
ALTER TABLE career_interactions ENABLE ROW LEVEL SECURITY;

-- Simple RLS Policies (User can only see their own data)
CREATE POLICY "Users can manage their own applications" 
ON career_applications FOR ALL 
USING (auth.uid() = user_id);

CREATE POLICY "Users can manage their own interactions" 
ON career_interactions FOR ALL 
USING (
  EXISTS (
    SELECT 1 FROM career_applications 
    WHERE career_applications.id = career_interactions.application_id 
    AND career_applications.user_id = auth.uid()
  )
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_career_apps_user ON career_applications(user_id);
CREATE INDEX IF NOT EXISTS idx_career_apps_status ON career_applications(status);
CREATE INDEX IF NOT EXISTS idx_career_interactions_app ON career_interactions(application_id);
