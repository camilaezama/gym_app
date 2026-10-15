-- Cambio para una base ya creada: agrega los músculos (categorías) para
-- dividir los ejercicios de cada tren. Los ejercicios existentes quedan sin
-- músculo (van a General) hasta que se les elija uno.
-- Ejecutar una vez en Supabase > SQL Editor.

-- Músculos. Cada usuario crea los suyos en Perfil y los ve él y quienes lo
-- tengan conectado como amigo.
create table if not exists muscles (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  body_part text not null check (body_part in ('superior', 'inferior')),
  owner_id uuid not null references profiles (id) on delete cascade,
  created_at timestamptz not null default now()
);

-- Al eliminar un músculo, sus ejercicios quedan sin músculo (General).
alter table exercises
  add column if not exists muscle_id uuid references muscles (id) on delete set null;

alter table muscles enable row level security;

create policy "usuarios leen musculos" on muscles
  for select to authenticated using (true);

create policy "cada uno crea sus musculos" on muscles
  for insert to authenticated with check (owner_id = auth.uid());

create policy "cada uno edita sus musculos" on muscles
  for update to authenticated
  using (owner_id = auth.uid()) with check (owner_id = auth.uid());

create policy "cada uno elimina sus musculos" on muscles
  for delete to authenticated using (owner_id = auth.uid());
