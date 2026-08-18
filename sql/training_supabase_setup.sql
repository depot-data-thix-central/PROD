-- ============================================================
-- THIX FORMATION MODULE - SUPABASE SQL SETUP
-- Complete schema for Training/Learning Management System
-- ============================================================

-- 1. MAIN TRAINING TABLE
CREATE TABLE IF NOT EXISTS thix_trainings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  tagline TEXT,
  description TEXT,
  category TEXT NOT NULL DEFAULT 'General',
  level TEXT NOT NULL DEFAULT 'Beginner', -- Beginner, Intermediate, Advanced
  language TEXT NOT NULL DEFAULT 'FR', -- FR, EN, ES, etc.
  delivery_mode TEXT NOT NULL DEFAULT 'online', -- online, physical, hybrid
  duration_minutes INT,
  
  -- Pricing
  is_free BOOLEAN NOT NULL DEFAULT false,
  price_amount DECIMAL(10, 2),
  currency TEXT NOT NULL DEFAULT 'USD',
  
  -- Metadata
  cover_image_bucket TEXT, -- Storage bucket name
  cover_image_path TEXT,   -- Storage path
  instructor_name TEXT,
  instructor_title TEXT,
  instructor_avatar_url TEXT,
  institution_name TEXT,
  institution_logo_url TEXT,
  
  -- Features
  certification_included BOOLEAN NOT NULL DEFAULT true,
  is_featured BOOLEAN NOT NULL DEFAULT false,
  is_published BOOLEAN NOT NULL DEFAULT false,
  
  -- SEO / Display
  skills TEXT[], -- Array of skill tags
  requirements TEXT,
  start_date TIMESTAMP WITH TIME ZONE,
  
  -- Metrics (denormalized for performance)
  students_count INT NOT NULL DEFAULT 0,
  rating DECIMAL(3, 1) NOT NULL DEFAULT 0.0,
  reviews_count INT NOT NULL DEFAULT 0,
  completion_rate DECIMAL(3, 2) NOT NULL DEFAULT 0.0,
  
  -- Audit
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  
  CONSTRAINT price_check CHECK (is_free OR price_amount > 0)
);

-- 2. TRAINING LESSONS TABLE
CREATE TABLE IF NOT EXISTS thix_training_lessons (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  training_id UUID NOT NULL REFERENCES thix_trainings(id) ON DELETE CASCADE,
  
  title TEXT NOT NULL,
  description TEXT,
  
  -- Organization
  module_index INT NOT NULL DEFAULT 1,
  lesson_index INT NOT NULL DEFAULT 1,
  order_index INT,
  
  -- Content
  content_type TEXT NOT NULL DEFAULT 'video', -- video, document, quiz, assignment, interactive
  video_url TEXT,
  video_storage_path TEXT,
  document_url TEXT,
  document_storage_path TEXT,
  
  -- Metadata
  duration_minutes INT,
  is_preview BOOLEAN NOT NULL DEFAULT false, -- Free preview
  
  -- Audit
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  
  CONSTRAINT unique_lesson_order UNIQUE(training_id, module_index, lesson_index)
);

-- 3. TRAINING ENROLLMENTS TABLE
CREATE TABLE IF NOT EXISTS thix_training_enrollments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  training_id UUID NOT NULL REFERENCES thix_trainings(id) ON DELETE CASCADE,
  
  -- Status
  status TEXT NOT NULL DEFAULT 'active', -- active, completed, cancelled, on-hold
  
  -- Progress
  progress_percent DECIMAL(5, 2) NOT NULL DEFAULT 0.0 CHECK (progress_percent >= 0 AND progress_percent <= 100),
  learning_minutes INT NOT NULL DEFAULT 0,
  
  -- Dates
  enrolled_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  completed_at TIMESTAMP WITH TIME ZONE,
  last_activity_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  
  -- Constraints
  CONSTRAINT unique_enrollment UNIQUE(user_id, training_id),
  CONSTRAINT valid_progress CHECK (progress_percent >= 0 AND progress_percent <= 100)
);

-- 4. TRAINING CERTIFICATES TABLE
CREATE TABLE IF NOT EXISTS thix_training_certificates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  training_id UUID NOT NULL REFERENCES thix_trainings(id) ON DELETE CASCADE,
  
  certificate_number TEXT NOT NULL UNIQUE,
  issued_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  expires_at TIMESTAMP WITH TIME ZONE, -- NULL = no expiry
  
  -- Storage
  certificate_url TEXT,
  qr_code_url TEXT,
  
  -- Audit
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  
  CONSTRAINT unique_cert UNIQUE(user_id, training_id)
);

-- 5. TRAINING PROGRESS TRACKING (for lesson-level progress)
CREATE TABLE IF NOT EXISTS thix_training_lesson_progress (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  enrollment_id UUID NOT NULL REFERENCES thix_training_enrollments(id) ON DELETE CASCADE,
  lesson_id UUID NOT NULL REFERENCES thix_training_lessons(id) ON DELETE CASCADE,
  
  is_completed BOOLEAN NOT NULL DEFAULT false,
  watched_duration_seconds INT NOT NULL DEFAULT 0,
  quiz_score DECIMAL(3, 1),
  
  completed_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  
  CONSTRAINT unique_lesson_progress UNIQUE(enrollment_id, lesson_id)
);

-- ============================================================
-- VIEWS
-- ============================================================

-- View for published trainings with status
CREATE OR REPLACE VIEW thix_trainings_status AS
SELECT 
  t.*,
  COALESCE(COUNT(DISTINCT te.id), 0) as current_students
FROM thix_trainings t
LEFT JOIN thix_training_enrollments te ON t.id = te.training_id AND te.status = 'active'
GROUP BY t.id;

-- ============================================================
-- INDEXES (for performance)
-- ============================================================

CREATE INDEX idx_trainings_published ON thix_trainings(is_published, is_featured, updated_at DESC);
CREATE INDEX idx_trainings_category ON thix_trainings(category);
CREATE INDEX idx_trainings_level ON thix_trainings(level);
CREATE INDEX idx_lessons_training ON thix_training_lessons(training_id, module_index, lesson_index);
CREATE INDEX idx_enrollments_user ON thix_training_enrollments(user_id, status);
CREATE INDEX idx_enrollments_training ON thix_training_enrollments(training_id);
CREATE INDEX idx_enrollments_status ON thix_training_enrollments(status, completed_at);
CREATE INDEX idx_certificates_user ON thix_training_certificates(user_id);
CREATE INDEX idx_lesson_progress_enrollment ON thix_training_lesson_progress(enrollment_id);
CREATE INDEX idx_lesson_progress_lesson ON thix_training_lesson_progress(lesson_id);

-- ============================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================

-- Enable RLS
ALTER TABLE thix_trainings ENABLE ROW LEVEL SECURITY;
ALTER TABLE thix_training_lessons ENABLE ROW LEVEL SECURITY;
ALTER TABLE thix_training_enrollments ENABLE ROW LEVEL SECURITY;
ALTER TABLE thix_training_certificates ENABLE ROW LEVEL SECURITY;
ALTER TABLE thix_training_lesson_progress ENABLE ROW LEVEL SECURITY;

-- Trainings: Public read (published only), Admin full access
CREATE POLICY "trainings_public_read" ON thix_trainings
  FOR SELECT USING (is_published = true);

CREATE POLICY "trainings_admin_all" ON thix_trainings
  FOR ALL USING (auth.uid() IN (SELECT user_id FROM thix_admin_memberships WHERE role IN ('super_admin', 'training_admin')));

-- Lessons: Public read if training is published
CREATE POLICY "lessons_public_read" ON thix_training_lessons
  FOR SELECT USING (
    training_id IN (SELECT id FROM thix_trainings WHERE is_published = true)
  );

CREATE POLICY "lessons_admin_all" ON thix_training_lessons
  FOR ALL USING (auth.uid() IN (SELECT user_id FROM thix_admin_memberships WHERE role IN ('super_admin', 'training_admin')));

-- Enrollments: Users see their own, Admins see all
CREATE POLICY "enrollments_user_read" ON thix_training_enrollments
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "enrollments_user_insert" ON thix_training_enrollments
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "enrollments_user_update" ON thix_training_enrollments
  FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE POLICY "enrollments_admin_all" ON thix_training_enrollments
  FOR ALL USING (auth.uid() IN (SELECT user_id FROM thix_admin_memberships WHERE role IN ('super_admin', 'training_admin')));

-- Certificates: Users see their own
CREATE POLICY "certificates_user_read" ON thix_training_certificates
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "certificates_admin_all" ON thix_training_certificates
  FOR ALL USING (auth.uid() IN (SELECT user_id FROM thix_admin_memberships WHERE role IN ('super_admin', 'training_admin')));

-- Lesson Progress: Users see their own
CREATE POLICY "lesson_progress_user_read" ON thix_training_lesson_progress
  FOR SELECT USING (
    enrollment_id IN (SELECT id FROM thix_training_enrollments WHERE user_id = auth.uid())
  );

CREATE POLICY "lesson_progress_user_update" ON thix_training_lesson_progress
  FOR UPDATE USING (
    enrollment_id IN (SELECT id FROM thix_training_enrollments WHERE user_id = auth.uid())
  );

-- ============================================================
-- SAMPLE DATA (for testing)
-- ============================================================

INSERT INTO thix_trainings (
  title, tagline, description, category, level, language, delivery_mode,
  duration_minutes, is_free, price_amount, currency, certification_included,
  is_featured, is_published, instructor_name, institution_name, skills,
  students_count, rating, reviews_count, completion_rate
) VALUES (
  'Cybersecurity Foundations (THIX Verified)',
  'Zero-trust mindset • Threat modeling • African compliance',
  'Un parcours premium orienté terrain: sécurité, politiques, audits, et réponses à incident. Certificat THIX Verified inclus.',
  'Cybersecurity',
  'Beginner',
  'FR',
  'online',
  360,
  false,
  49,
  'USD',
  true,
  true,
  true,
  'THIX Security Lab',
  'THIX ID Academy',
  ARRAY['Threat Modeling', 'SOC Basics', 'Incident Response', 'IAM'],
  1280,
  4.9,
  342,
  0.72
) ON CONFLICT DO NOTHING;

INSERT INTO thix_trainings (
  title, tagline, description, category, level, language, delivery_mode,
  duration_minutes, is_free, price_amount, currency, certification_included,
  is_featured, is_published, instructor_name, institution_name, skills,
  students_count, rating, reviews_count, completion_rate
) VALUES (
  'AI & Data Sentinel',
  'Data governance • Privacy • Practical LLM safety',
  'Apprends à construire des produits IA responsables: governance, privacy, sécurité et mise en prod.',
  'AI & Data',
  'Intermediate',
  'FR',
  'online',
  480,
  true,
  0,
  'USD',
  true,
  false,
  true,
  'Prof. N. Kabila',
  'Partner University',
  ARRAY['Data Governance', 'Prompt Safety', 'PII Protection'],
  840,
  4.8,
  190,
  0.66
) ON CONFLICT DO NOTHING;

-- ============================================================
-- TRIGGERS (auto-update updated_at)
-- ============================================================

CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_trainings_updated_at
  BEFORE UPDATE ON thix_trainings
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trigger_lessons_updated_at
  BEFORE UPDATE ON thix_training_lessons
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trigger_enrollments_updated_at
  BEFORE UPDATE ON thix_training_enrollments
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trigger_certificates_updated_at
  BEFORE UPDATE ON thix_training_certificates
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trigger_lesson_progress_updated_at
  BEFORE UPDATE ON thix_training_lesson_progress
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at();

-- ============================================================
-- STORED PROCEDURES
-- ============================================================

-- Auto-issue certificate when enrollment is completed
CREATE OR REPLACE FUNCTION issue_certificate_on_completion()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'completed' AND OLD.status != 'completed' THEN
    INSERT INTO thix_training_certificates (
      user_id,
      training_id,
      certificate_number,
      issued_at
    ) VALUES (
      NEW.user_id,
      NEW.training_id,
      'CERT-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || ENCODE(gen_random_bytes(4), 'hex'),
      NOW()
    ) ON CONFLICT (user_id, training_id) DO UPDATE SET
      issued_at = NOW(),
      updated_at = NOW();
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_issue_certificate
  AFTER UPDATE ON thix_training_enrollments
  FOR EACH ROW
  EXECUTE FUNCTION issue_certificate_on_completion();

-- Update training metrics
CREATE OR REPLACE FUNCTION update_training_metrics(p_training_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE thix_trainings SET
    students_count = (SELECT COUNT(*) FROM thix_training_enrollments WHERE training_id = p_training_id),
    completion_rate = (
      SELECT COALESCE(COUNT(CASE WHEN status = 'completed' THEN 1 END), 0)::DECIMAL / 
             NULLIF(COUNT(*), 0)
      FROM thix_training_enrollments
      WHERE training_id = p_training_id
    ),
    updated_at = NOW()
  WHERE id = p_training_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- COMMENTS
-- ============================================================

COMMENT ON TABLE thix_trainings IS 'Core training/course entity for THIX Learning ecosystem';
COMMENT ON TABLE thix_training_lessons IS 'Individual lessons within trainings';
COMMENT ON TABLE thix_training_enrollments IS 'User enrollment and progress tracking';
COMMENT ON TABLE thix_training_certificates IS 'Issued certificates upon completion';
COMMENT ON TABLE thix_training_lesson_progress IS 'Fine-grained lesson-level progress';
