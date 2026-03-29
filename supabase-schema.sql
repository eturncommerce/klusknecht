-- ============================================================
-- KLUSKNECHT.NL — Supabase database schema
-- Plak dit in: Supabase → SQL Editor → New query → Run
-- ============================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Forum topics
CREATE TABLE IF NOT EXISTS forum_topics (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  title TEXT NOT NULL,
  excerpt TEXT,
  category TEXT NOT NULL DEFAULT 'Overige',
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  author_name TEXT NOT NULL DEFAULT 'Anoniem',
  avatar_url TEXT,
  solved BOOLEAN DEFAULT FALSE,
  views INT DEFAULT 0,
  rikkie_answered BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Forum replies
CREATE TABLE IF NOT EXISTS forum_replies (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  topic_id UUID REFERENCES forum_topics(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  author_name TEXT NOT NULL,
  content TEXT NOT NULL,
  is_rikkie BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Klustips
CREATE TABLE IF NOT EXISTS klustips (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  title TEXT NOT NULL,
  category TEXT NOT NULL,
  image_url TEXT,
  read_min INT DEFAULT 5,
  author TEXT DEFAULT 'Redactie',
  excerpt TEXT,
  content TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Inspiratie artikelen
CREATE TABLE IF NOT EXISTS inspiratie_artikelen (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  title TEXT NOT NULL,
  category TEXT NOT NULL,
  image_url TEXT,
  read_min INT DEFAULT 5,
  author TEXT DEFAULT 'Redactie',
  excerpt TEXT,
  content TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Row Level Security inschakelen
ALTER TABLE forum_topics ENABLE ROW LEVEL SECURITY;
ALTER TABLE forum_replies ENABLE ROW LEVEL SECURITY;
ALTER TABLE klustips ENABLE ROW LEVEL SECURITY;
ALTER TABLE inspiratie_artikelen ENABLE ROW LEVEL SECURITY;

-- Iedereen mag lezen
CREATE POLICY "Public read topics" ON forum_topics FOR SELECT USING (true);
CREATE POLICY "Public read replies" ON forum_replies FOR SELECT USING (true);
CREATE POLICY "Public read klustips" ON klustips FOR SELECT USING (true);
CREATE POLICY "Public read inspiratie" ON inspiratie_artikelen FOR SELECT USING (true);

-- Ingelogde gebruikers mogen topics en replies aanmaken
CREATE POLICY "Auth insert topics" ON forum_topics FOR INSERT WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Auth insert replies" ON forum_replies FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- Ingelogde gebruikers mogen hun eigen topics updaten (solved markeren)
CREATE POLICY "Auth update own topics" ON forum_topics FOR UPDATE USING (auth.uid() = user_id);

-- Service role (Rikkie bot) mag alles
CREATE POLICY "Service all topics" ON forum_topics USING (auth.role() = 'service_role');
CREATE POLICY "Service all replies" ON forum_replies USING (auth.role() = 'service_role');
CREATE POLICY "Service all klustips" ON klustips USING (auth.role() = 'service_role');
CREATE POLICY "Service all inspiratie" ON inspiratie_artikelen USING (auth.role() = 'service_role');
