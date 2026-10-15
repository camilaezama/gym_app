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

-- Músculos para dividir los ejercicios de cada tren. Cada usuario crea los
-- suyos en Perfil y los ve él y quienes lo tengan conectado como amigo.
create table muscles (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  body_part text not null check (body_part in ('superior', 'inferior')),
  owner_id uuid not null references profiles (id) on delete cascade,
  -- Nombre del ícono (biceps, gluteos...): la imagen está en
  -- assets/muscles/<icon>.png. null: sin ícono.
  icon text,
  created_at timestamptz not null default now()
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
  -- null: va a General. Al eliminar el músculo vuelve a General.
  muscle_id uuid references muscles (id) on delete set null,
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

-- Pagos del gimnasio. Uno por persona: si varios pagaron juntos, cada uno
-- tiene el suyo.
create table payments (
  id uuid primary key default gen_random_uuid(),
  person_id uuid not null references profiles (id) on delete cascade,
  date date not null,
  -- Cuánto pagó esa persona; null si no se cargó.
  amount numeric(12, 2),
  created_at timestamptz not null default now()
);

create index payments_person_id_idx on payments (person_id);

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
alter table muscles enable row level security;
alter table exercises enable row level security;
alter table routines enable row level security;
alter table payments enable row level security;

create policy "usuarios leen perfiles" on profiles
  for select to authenticated using (true);

create policy "cada uno maneja sus amigos" on friends
  for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "usuarios leen musculos" on muscles
  for select to authenticated using (true);

create policy "cada uno crea sus musculos" on muscles
  for insert to authenticated with check (owner_id = auth.uid());

create policy "cada uno edita sus musculos" on muscles
  for update to authenticated
  using (owner_id = auth.uid()) with check (owner_id = auth.uid());

create policy "cada uno elimina sus musculos" on muscles
  for delete to authenticated using (owner_id = auth.uid());

create policy "usuarios manejan ejercicios" on exercises
  for all to authenticated using (true) with check (true);

create policy "usuarios manejan rutinas" on routines
  for all to authenticated using (true) with check (true);

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

create policy "cada uno edita sus pagos" on payments
  for update to authenticated
  using (person_id = auth.uid())
  with check (person_id = auth.uid());

-- Notificaciones (ver supabase/NOTIFICACIONES.md).

-- Qué notificaciones quiere cada usuario. Sin fila: ninguna.
create table notification_settings (
  user_id uuid primary key references profiles (id) on delete cascade,
  payment_reminders boolean not null default false,
  training_reminders boolean not null default false,
  -- Días de entrenamiento: 1 lunes ... 7 domingo.
  training_days smallint[] not null default '{}'
);

-- Dispositivos (celulares, navegadores) registrados para recibir las
-- notificaciones de un usuario. Los datos los da el navegador.
create table push_subscriptions (
  endpoint text primary key,
  user_id uuid not null references profiles (id) on delete cascade,
  subscription jsonb not null,
  created_at timestamptz not null default now()
);

-- Mensajes de los días de entrenamiento, compartidos entre todos: cada día
-- llega uno al azar.
create table training_messages (
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

-- Por ahora solo cami ve y cambia los mensajes (ver trainingMessagesAdmin
-- en lib/config.dart). La función send-notifications los lee igual.
create policy "solo cami maneja mensajes" on training_messages
  for all to authenticated
  using (auth.jwt() ->> 'email' = 'cami@gym.app')
  with check (auth.jwt() ->> 'email' = 'cami@gym.app');

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
  'Hoy se suda, sin excusas',
  'El sillón puede esperar, el gym no',
  'Ponete las zapatillas que hoy se entrena',
  'Hoy no se negocia: gym',
  'El verano se construye hoy ☀️',
  'Cero excusas, hoy hay gym',
  'Hoy toca sufrir un poquito (y salir feliz)',
  'Mové ese cuerpito que hoy hay gym',
  'Hoy se entrena y después se come rico',
  'Tus músculos te están esperando',
  'Hoy es día de gym, ¡a romperla!',
  'Si hoy no vas, mañana te arrepentís',
  'Hoy no hay pereza que valga: GYM'
]) as text
where not exists (select 1 from training_messages);

-- Tiempo real: la app se entera al instante de lo que cambia otro usuario.
-- Cada usuario solo recibe los cambios de las filas que puede leer.
alter publication supabase_realtime add table
  profiles, friends, muscles, exercises, routines, payments,
  notification_settings, training_messages;
