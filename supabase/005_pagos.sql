-- Cambio para una base ya creada: agrega los pagos del gimnasio.
-- Ejecutar una vez en Supabase > SQL Editor.

-- Un pago por persona: si varios pagaron juntos, cada uno tiene el suyo.
create table if not exists payments (
  id uuid primary key default gen_random_uuid(),
  person_id uuid not null references profiles (id) on delete cascade,
  date date not null,
  created_at timestamptz not null default now()
);

create index if not exists payments_person_id_idx on payments (person_id);

alter table payments enable row level security;

create policy "cada uno ve sus pagos" on payments
  for select to authenticated using (person_id = auth.uid());

-- Se puede cargar el pago propio y el de los amigos conectados que pagaron
-- junto con uno.
create policy "cada uno carga pagos suyos y de sus amigos" on payments
  for insert to authenticated with check (
    person_id = auth.uid()
    or exists (
      select 1 from friends
      where user_id = auth.uid() and friend_id = person_id
    )
  );

create policy "cada uno elimina sus pagos" on payments
  for delete to authenticated using (person_id = auth.uid());
