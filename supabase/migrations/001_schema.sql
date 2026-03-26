-- Meditator: core schema, RLS, session stats trigger, auth profile bootstrap, Realtime

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

CREATE TABLE public.profiles (
  id uuid PRIMARY KEY REFERENCES auth.users (id) ON DELETE CASCADE,
  email text,
  display_name text,
  avatar_url text,
  goals text[] DEFAULT '{}',
  stress_level text,
  preferred_duration text,
  preferred_voice text,
  preferred_time_hour int,
  is_premium boolean NOT NULL DEFAULT false,
  total_sessions int NOT NULL DEFAULT 0,
  current_streak int NOT NULL DEFAULT 0,
  longest_streak int NOT NULL DEFAULT 0,
  total_minutes int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.meditations (
  id text PRIMARY KEY,
  title text NOT NULL,
  description text,
  category text NOT NULL,
  duration_minutes int NOT NULL,
  audio_url text,
  image_url text,
  is_generated boolean NOT NULL DEFAULT false,
  is_premium boolean NOT NULL DEFAULT false,
  voice_name text,
  rating numeric(3, 2),
  play_count int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
  meditation_id text REFERENCES public.meditations (id) ON DELETE SET NULL,
  duration_seconds int NOT NULL DEFAULT 0,
  completed boolean NOT NULL DEFAULT false,
  mood_before text,
  mood_after text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.mood_entries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
  primary_emotion text NOT NULL,
  secondary_emotions text[] DEFAULT '{}',
  intensity int NOT NULL CHECK (intensity >= 1 AND intensity <= 5),
  note text,
  ai_insight text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.garden_plants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
  type text NOT NULL,
  stage text NOT NULL,
  water_count int NOT NULL DEFAULT 0,
  health_level numeric(5, 2) NOT NULL DEFAULT 100,
  pos_x numeric(10, 4) NOT NULL DEFAULT 0,
  pos_y numeric(10, 4) NOT NULL DEFAULT 0,
  planted_at timestamptz NOT NULL DEFAULT now(),
  last_watered_at timestamptz
);

CREATE TABLE public.partnerships (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
  partner_id uuid NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
  partner_name text,
  status text NOT NULL DEFAULT 'pending',
  shared_goals text[] DEFAULT '{}',
  my_streak int NOT NULL DEFAULT 0,
  partner_streak int NOT NULL DEFAULT 0,
  shared_sessions int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT partnerships_no_self CHECK (user_id <> partner_id),
  CONSTRAINT partnerships_user_partner_unique UNIQUE (user_id, partner_id)
);

CREATE TABLE public.pair_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pair_id uuid NOT NULL REFERENCES public.partnerships (id) ON DELETE CASCADE,
  sender_id uuid NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
  type text NOT NULL DEFAULT 'text',
  content text,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Indexes (user_id, created_at hot paths)
-- ---------------------------------------------------------------------------

CREATE INDEX idx_sessions_user_id ON public.sessions (user_id);
CREATE INDEX idx_sessions_created_at ON public.sessions (created_at DESC);
CREATE INDEX idx_sessions_user_created ON public.sessions (user_id, created_at DESC);

CREATE INDEX idx_mood_entries_user_id ON public.mood_entries (user_id);
CREATE INDEX idx_mood_entries_created_at ON public.mood_entries (created_at DESC);

CREATE INDEX idx_garden_plants_user_id ON public.garden_plants (user_id);

CREATE INDEX idx_partnerships_user_id ON public.partnerships (user_id);
CREATE INDEX idx_partnerships_partner_id ON public.partnerships (partner_id);
CREATE INDEX idx_partnerships_created_at ON public.partnerships (created_at DESC);

CREATE INDEX idx_pair_messages_pair_id ON public.pair_messages (pair_id);
CREATE INDEX idx_pair_messages_created_at ON public.pair_messages (created_at DESC);

CREATE INDEX idx_meditations_category ON public.meditations (category);
CREATE INDEX idx_profiles_created_at ON public.profiles (created_at DESC);

-- ---------------------------------------------------------------------------
-- updated_at helper
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.set_profiles_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

CREATE TRIGGER profiles_set_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE PROCEDURE public.set_profiles_updated_at();

-- ---------------------------------------------------------------------------
-- New auth user -> profile row
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.on_auth_user_created()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, email, display_name, created_at, updated_at)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(
      NULLIF(trim(NEW.raw_user_meta_data ->> 'full_name'), ''),
      NULLIF(trim(NEW.raw_user_meta_data ->> 'name'), ''),
      split_part(NEW.email, '@', 1)
    ),
    now(),
    now()
  );
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE PROCEDURE public.on_auth_user_created();

-- ---------------------------------------------------------------------------
-- Session completed -> profile aggregates + streak
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.on_session_complete()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  add_minutes int;
  session_day date;
  prev_day date;
  first_completed_today boolean;
  next_streak int;
  cur_streak int;
BEGIN
  IF NEW.completed IS NOT TRUE THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE' AND OLD.completed IS TRUE THEN
    RETURN NEW;
  END IF;

  add_minutes := GREATEST(0, NEW.duration_seconds / 60);

  UPDATE public.profiles
  SET
    total_sessions = total_sessions + 1,
    total_minutes = total_minutes + add_minutes,
    updated_at = now()
  WHERE id = NEW.user_id;

  session_day := (timezone('UTC', NEW.created_at))::date;

  SELECT NOT EXISTS (
    SELECT 1
    FROM public.sessions s
    WHERE s.user_id = NEW.user_id
      AND s.completed = true
      AND s.id IS DISTINCT FROM NEW.id
      AND (timezone('UTC', s.created_at))::date = session_day
  )
  INTO first_completed_today;

  IF first_completed_today THEN
    SELECT MAX((timezone('UTC', s.created_at))::date)
    INTO prev_day
    FROM public.sessions s
    WHERE s.user_id = NEW.user_id
      AND s.completed = true
      AND s.id IS DISTINCT FROM NEW.id
      AND (timezone('UTC', s.created_at))::date < session_day;

    SELECT p.current_streak INTO cur_streak FROM public.profiles p WHERE p.id = NEW.user_id;

    IF prev_day IS NULL THEN
      next_streak := 1;
    ELSIF prev_day = session_day - 1 THEN
      next_streak := COALESCE(cur_streak, 0) + 1;
    ELSE
      next_streak := 1;
    END IF;

    UPDATE public.profiles
    SET
      current_streak = next_streak,
      longest_streak = GREATEST(longest_streak, next_streak),
      updated_at = now()
    WHERE id = NEW.user_id;
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER on_session_complete
  AFTER INSERT OR UPDATE OF completed ON public.sessions
  FOR EACH ROW
  WHEN (NEW.completed IS TRUE)
  EXECUTE PROCEDURE public.on_session_complete();

-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.meditations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mood_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.garden_plants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.partnerships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pair_messages ENABLE ROW LEVEL SECURITY;

-- profiles: own row
CREATE POLICY "profiles_select_own"
  ON public.profiles FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "profiles_update_own"
  ON public.profiles FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- meditations: public read
CREATE POLICY "meditations_select_public"
  ON public.meditations FOR SELECT
  USING (true);

-- sessions
CREATE POLICY "sessions_select_own"
  ON public.sessions FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "sessions_insert_own"
  ON public.sessions FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "sessions_update_own"
  ON public.sessions FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "sessions_delete_own"
  ON public.sessions FOR DELETE
  USING (auth.uid() = user_id);

-- mood_entries
CREATE POLICY "mood_entries_select_own"
  ON public.mood_entries FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "mood_entries_insert_own"
  ON public.mood_entries FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "mood_entries_update_own"
  ON public.mood_entries FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "mood_entries_delete_own"
  ON public.mood_entries FOR DELETE
  USING (auth.uid() = user_id);

-- garden_plants
CREATE POLICY "garden_plants_select_own"
  ON public.garden_plants FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "garden_plants_insert_own"
  ON public.garden_plants FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "garden_plants_update_own"
  ON public.garden_plants FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "garden_plants_delete_own"
  ON public.garden_plants FOR DELETE
  USING (auth.uid() = user_id);

-- partnerships: member on either side
CREATE POLICY "partnerships_select_member"
  ON public.partnerships FOR SELECT
  USING (auth.uid() = user_id OR auth.uid() = partner_id);

CREATE POLICY "partnerships_insert_as_user"
  ON public.partnerships FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "partnerships_update_member"
  ON public.partnerships FOR UPDATE
  USING (auth.uid() = user_id OR auth.uid() = partner_id)
  WITH CHECK (auth.uid() = user_id OR auth.uid() = partner_id);

CREATE POLICY "partnerships_delete_member"
  ON public.partnerships FOR DELETE
  USING (auth.uid() = user_id OR auth.uid() = partner_id);

-- pair_messages: only within a partnership the user belongs to
CREATE POLICY "pair_messages_select_member"
  ON public.pair_messages FOR SELECT
  USING (
    EXISTS (
      SELECT 1
      FROM public.partnerships p
      WHERE p.id = pair_messages.pair_id
        AND (auth.uid() = p.user_id OR auth.uid() = p.partner_id)
    )
  );

CREATE POLICY "pair_messages_insert_sender_member"
  ON public.pair_messages FOR INSERT
  WITH CHECK (
    auth.uid() = sender_id
    AND EXISTS (
      SELECT 1
      FROM public.partnerships p
      WHERE p.id = pair_messages.pair_id
        AND (auth.uid() = p.user_id OR auth.uid() = p.partner_id)
    )
  );

CREATE POLICY "pair_messages_update_own_sender"
  ON public.pair_messages FOR UPDATE
  USING (auth.uid() = sender_id)
  WITH CHECK (auth.uid() = sender_id);

CREATE POLICY "pair_messages_delete_own_sender"
  ON public.pair_messages FOR DELETE
  USING (auth.uid() = sender_id);

-- ---------------------------------------------------------------------------
-- Realtime: pair_messages
-- ---------------------------------------------------------------------------

ALTER PUBLICATION supabase_realtime ADD TABLE public.pair_messages;
