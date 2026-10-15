-- Cambio para una base ya creada: agrega las notificaciones (recordatorios
-- de pago y de los días de entrenamiento). Ejecutar una vez en Supabase >
-- SQL Editor. Después seguir los pasos de supabase/NOTIFICACIONES.md.

-- Qué notificaciones quiere cada usuario. Sin fila: ninguna.
create table if not exists notification_settings (
  user_id uuid primary key references profiles (id) on delete cascade,
  payment_reminders boolean not null default false,
  training_reminders boolean not null default false,
  -- Días de entrenamiento: 1 lunes ... 7 domingo.
  training_days smallint[] not null default '{}'
);

-- Dispositivos (celulares, navegadores) registrados para recibir las
-- notificaciones de un usuario. Los datos los da el navegador.
create table if not exists push_subscriptions (
  endpoint text primary key,
  user_id uuid not null references profiles (id) on delete cascade,
  subscription jsonb not null,
  created_at timestamptz not null default now()
);

-- Mensajes de los días de entrenamiento, compartidos entre todos: cada día
-- llega uno al azar.
create table if not exists training_messages (
  id uuid primary key default gen_random_uuid(),
  text text not null,
  created_at timestamptz not null default now()
);

alter table notification_settings enable row level security;
alter table push_subscriptions enable row level security;
alter table training_messages enable row level security;

create policy "cada uno maneja sus notificaciones" on notification_settings
  for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "cada uno ve sus dispositivos" on push_subscriptions
  for select to authenticated using (user_id = auth.uid());

create policy "cada uno elimina sus dispositivos" on push_subscriptions
  for delete to authenticated using (user_id = auth.uid());

create policy "usuarios manejan mensajes" on training_messages
  for all to authenticated using (true) with check (true);

-- Registra el dispositivo a nombre del usuario actual. Si el mismo celular
-- ya estaba registrado por otro usuario, pasa a ser del actual (las reglas
-- de arriba no dejarían cambiarlo desde la app).
create or replace function save_push_subscription(subscription jsonb)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then
    raise exception 'Hace falta iniciar sesión';
  end if;
  insert into push_subscriptions (endpoint, user_id, subscription)
  values (subscription ->> 'endpoint', auth.uid(), subscription)
  on conflict (endpoint) do update
    set user_id = excluded.user_id, subscription = excluded.subscription;
end;
$$;

revoke execute on function save_push_subscription(jsonb) from public, anon;
grant execute on function save_push_subscription(jsonb) to authenticated;

-- Mensajes para arrancar. Se pueden agregar y borrar desde la app.
insert into training_messages (text)
select text from unnest(array[
  'Hoy gymmm',
  'Hoy se entrena',
  'Hoy musculamos',
  'Dale que hay que llegar al verano, NO FALTES',
  'Hoy gym, no vale faltar',
  'Arriba que hoy toca gym 💪',
  'Las pesas no se levantan solas',
  'Hoy sin excusas',
  'El sillón puede esperar, el gym no',
  'Dale que hoy se entrena',
  'Hoy no se negocia',
  'Anda al gym y pensa en el verano ☀️',
  'Cero excusas, hoy hay gym',
  'Hoy toca sufrir un poquito',
  'Hoy hay gym',
  'Día de gym!!!',
  'Si hoy no vas, mañana te arrepentís',
  'Hoy no hay siesta'
]) as text
where not exists (select 1 from training_messages);
