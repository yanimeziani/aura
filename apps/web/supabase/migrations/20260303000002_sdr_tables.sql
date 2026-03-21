-- Migration: SDR Agent Tables
-- Date: 2026-03-03
-- Description: Tables for SDR outreach tracking

-- Enable UUID extension if not already enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Types for SDR
DO $$ BEGIN
    CREATE TYPE campaign_status AS ENUM ('draft', 'active', 'paused', 'completed');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE prospect_status AS ENUM ('new', 'contacted', 'replied', 'interested', 'unqualified', 'converted');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE email_status AS ENUM ('draft', 'scheduled', 'sent', 'delivered', 'opened', 'replied', 'bounced');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- SDR Campaigns
CREATE TABLE IF NOT EXISTS sdr_campaigns (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id),
  name TEXT NOT NULL,
  description TEXT,
  status campaign_status DEFAULT 'draft',
  sequence_id UUID,
  created_at TIMESTAMPTZ DEFAULT now(),
  started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  metadata JSONB DEFAULT '{}'::jsonb
);

-- SDR Prospects
CREATE TABLE IF NOT EXISTS sdr_prospects (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id),
  campaign_id UUID REFERENCES sdr_campaigns(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  first_name TEXT,
  last_name TEXT,
  company TEXT,
  title TEXT,
  status prospect_status DEFAULT 'new',
  research_notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  last_contacted TIMESTAMPTZ,
  metadata JSONB DEFAULT '{}'::jsonb
);

-- SDR Emails
CREATE TABLE IF NOT EXISTS sdr_emails (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  prospect_id UUID REFERENCES sdr_prospects(id) ON DELETE CASCADE,
  campaign_id UUID REFERENCES sdr_campaigns(id) ON DELETE CASCADE,
  sequence_step INT DEFAULT 0,
  subject TEXT NOT NULL,
  body TEXT NOT NULL,
  status email_status DEFAULT 'draft',
  scheduled_at TIMESTAMPTZ,
  sent_at TIMESTAMPTZ,
  delivered_at TIMESTAMPTZ,
  opened_at TIMESTAMPTZ,
  replied_at TIMESTAMPTZ,
  reply_content TEXT,
  metadata JSONB DEFAULT '{}'::jsonb
);

-- SDR Analytics
CREATE TABLE IF NOT EXISTS sdr_analytics (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  campaign_id UUID REFERENCES sdr_campaigns(id) ON DELETE CASCADE,
  date DATE DEFAULT CURRENT_DATE,
  emails_sent INT DEFAULT 0,
  emails_delivered INT DEFAULT 0,
  emails_opened INT DEFAULT 0,
  emails_replied INT DEFAULT 0,
  emails_bounced INT DEFAULT 0,
  conversions INT DEFAULT 0,
  metadata JSONB DEFAULT '{}'::jsonb
);

-- RLS
ALTER TABLE sdr_campaigns ENABLE ROW LEVEL SECURITY;
ALTER TABLE sdr_prospects ENABLE ROW LEVEL SECURITY;
ALTER TABLE sdr_emails ENABLE ROW LEVEL SECURITY;
ALTER TABLE sdr_analytics ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Users can manage their own campaigns" 
ON sdr_campaigns FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Users can manage their own prospects" 
ON sdr_prospects FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Users can manage their own emails" 
ON sdr_emails FOR ALL USING (
  EXISTS (SELECT 1 FROM sdr_campaigns WHERE id = sdr_emails.campaign_id AND user_id = auth.uid())
);

CREATE POLICY "Users can view their own analytics" 
ON sdr_analytics FOR ALL USING (
  EXISTS (SELECT 1 FROM sdr_campaigns WHERE id = sdr_analytics.campaign_id AND user_id = auth.uid())
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_prospects_campaign ON sdr_prospects(campaign_id);
CREATE INDEX idx_prospects_status ON sdr_prospects(status);
CREATE INDEX IF NOT EXISTS idx_emails_prospect ON sdr_emails(prospect_id);
CREATE INDEX IF NOT EXISTS idx_emails_status ON sdr_emails(status);
CREATE INDEX IF NOT EXISTS idx_analytics_campaign ON sdr_analytics(campaign_id);
