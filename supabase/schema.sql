-- Tablas de Gym App. Pegar y ejecutar completo en Supabase > SQL Editor.

-- Un perfil por cada usuario de Authentication. Se crea solo (ver trigger).
create table profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  name text not null
);

-- Amigos conectados. Cada usuario elige los suyos: que Cami conecte a Agos
-- no conecta a Agos con Cami.
create table friends (
  user_id uuid not null references profiles (id) on delete cascade,
  friend_id uuid not null references profiles (id) on delete cascade,
  primary key (user_id, friend_id)
);

-- Ejercicios, compartidos entre todos los usuarios.
create table exercises (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  body_part text not null check (body_part in ('superior', 'inferior')),
  weight_type text not null check (
    weight_type in ('mancuernas', 'ladrillos', 'barra', 'total', 'tiempo')
  ),
  -- {"<id de persona>": [25, 30, 35]}: un valor, o uno por serie.
  initial_weights jsonb not null default '{}',
  -- Los ejercicios eliminados se archivan en vez de borrarse, para que las
  -- rutinas viejas los sigan mostrando.
  archived boolean not null default false,
  created_at timestamptz not null default now()
);

-- La rutina de un día.
create table routines (
  id uuid primary key default gen_random_uuid(),
  date date not null,
  person_ids uuid[] not null,
  -- [{"exercise_id": "<id>", "weights": {"<id de persona>": [25, 30, 35]}}]
  entries jsonb not null default '[]',
  created_at timestamptz not null default now()
);

create index routines_person_ids_idx on routines using gin (person_ids);

-- Al crear un usuario en Authentication se le crea el perfil. El nombre sale
-- del email (cami@gym.app -> Cami) y se puede cambiar en la tabla profiles.
create function handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into profiles (id, name)
  values (new.id, initcap(split_part(new.email, '@', 1)));
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();

-- Seguridad: sin sesión iniciada no se puede leer ni escribir nada. Con
-- sesión, todos los usuarios comparten ejercicios y rutinas.
alter table profiles enable row level security;
alter table friends enable row level security;
alter table exercises enable row level security;
alter table routines enable row level security;

create policy "usuarios leen perfiles" on profiles
  for select to authenticated using (true);

create policy "cada uno maneja sus amigos" on friends
  for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "usuarios manejan ejercicios" on exercises
  for all to authenticated using (true) with check (true);

create policy "usuarios manejan rutinas" on routines
  for all to authenticated using (true) with check (true);
