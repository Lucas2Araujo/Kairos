-- ==============================================================================
-- Kairós — Migração para Gestão de Turmas (Escola Sabatina Jovem / PG)
-- Arquivo: supabase/migrations/classroom_schema.sql
-- ==============================================================================

-- 1. Tabela de Turmas / Classes
CREATE TABLE IF NOT EXISTS public.classrooms (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(6) NOT NULL UNIQUE,
    name VARCHAR(120) NOT NULL,
    church_name VARCHAR(150) NOT NULL,
    teacher_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    webhook_url TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Índices para classrooms
CREATE INDEX IF NOT EXISTS idx_classrooms_code ON public.classrooms(code);
CREATE INDEX IF NOT EXISTS idx_classrooms_teacher_id ON public.classrooms(teacher_id);

-- 2. Tabela de Membros da Turma (1 Turma por Aluno)
CREATE TABLE IF NOT EXISTS public.classroom_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    classroom_id UUID NOT NULL REFERENCES public.classrooms(id) ON DELETE CASCADE,
    user_id UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
    student_name VARCHAR(120),
    avatar_config_json TEXT,
    joined_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Índices para classroom_members
CREATE INDEX IF NOT EXISTS idx_classroom_members_classroom_id ON public.classroom_members(classroom_id);
CREATE INDEX IF NOT EXISTS idx_classroom_members_user_id ON public.classroom_members(user_id);

-- 3. Tabela de Logs Diários de Atividade dos Membros
CREATE TABLE IF NOT EXISTS public.member_activity_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    activity_date DATE NOT NULL,
    minutes_with_god INTEGER NOT NULL DEFAULT 0,
    missions_completed INTEGER NOT NULL DEFAULT 0,
    did_daily_quiz BOOLEAN NOT NULL DEFAULT FALSE,
    quiz_score INTEGER NOT NULL DEFAULT 0,
    streak_type VARCHAR(10) NOT NULL DEFAULT 'none' CHECK (streak_type IN ('none', 'half', 'full')),
    total_xp INTEGER NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    UNIQUE(user_id, activity_date)
);

-- Índices para member_activity_logs
CREATE INDEX IF NOT EXISTS idx_member_activity_logs_user_date ON public.member_activity_logs(user_id, activity_date);
CREATE INDEX IF NOT EXISTS idx_member_activity_logs_date ON public.member_activity_logs(activity_date);

-- 4. Tabela de Resumos EGW da Lição da Escola Sabatina
CREATE TABLE IF NOT EXISTS public.egw_lesson_summaries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    lesson_day_id VARCHAR(50) NOT NULL UNIQUE,
    book_title VARCHAR(150) NOT NULL,
    chapter_title VARCHAR(150),
    ai_summary TEXT NOT NULL,
    direct_quotes JSONB DEFAULT '[]'::jsonb,
    source_url TEXT NOT NULL DEFAULT 'https://m.egwwritings.org/pt',
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_egw_lesson_summaries_day_id ON public.egw_lesson_summaries(lesson_day_id);

-- Habilitar Row Level Security (RLS)
ALTER TABLE public.classrooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.classroom_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.member_activity_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.egw_lesson_summaries ENABLE ROW LEVEL SECURITY;

-- Políticas RLS:
-- Resumos EGW: Leitura livre para todos autenticados e anônimos
CREATE POLICY "EGW summaries are viewable by everyone" 
    ON public.egw_lesson_summaries FOR SELECT 
    USING (true);

-- Turmas: Qualquer usuário autenticado pode ler e criar turma
CREATE POLICY "Classrooms are viewable by authenticated users" 
    ON public.classrooms FOR SELECT 
    TO authenticated 
    USING (true);

CREATE POLICY "Teachers can insert their own classrooms" 
    ON public.classrooms FOR INSERT 
    TO authenticated 
    WITH CHECK (auth.uid() = teacher_id);

CREATE POLICY "Teachers can update their own classrooms" 
    ON public.classrooms FOR UPDATE 
    TO authenticated 
    USING (auth.uid() = teacher_id);

CREATE POLICY "Teachers can delete their own classrooms" 
    ON public.classrooms FOR DELETE 
    TO authenticated 
    USING (auth.uid() = teacher_id);

-- Membros:
CREATE POLICY "Classroom members are viewable by authenticated users" 
    ON public.classroom_members FOR SELECT 
    TO authenticated 
    USING (true);

CREATE POLICY "Users can join a classroom" 
    ON public.classroom_members FOR INSERT 
    TO authenticated 
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own membership" 
    ON public.classroom_members FOR UPDATE 
    TO authenticated 
    USING (auth.uid() = user_id);

CREATE POLICY "Users can leave or teachers remove member" 
    ON public.classroom_members FOR DELETE 
    TO authenticated 
    USING (auth.uid() = user_id OR EXISTS (
        SELECT 1 FROM public.classrooms c 
        WHERE c.id = classroom_members.classroom_id AND c.teacher_id = auth.uid()
    ));

-- Logs de Atividade:
CREATE POLICY "Users can view activities of their classroom peers" 
    ON public.member_activity_logs FOR SELECT 
    TO authenticated 
    USING (true);

CREATE POLICY "Users can upsert their own activity logs" 
    ON public.member_activity_logs FOR ALL 
    TO authenticated 
    USING (auth.uid() = user_id) 
    WITH CHECK (auth.uid() = user_id);

