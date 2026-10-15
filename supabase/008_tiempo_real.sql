-- Cambio para una base ya creada: activa el tiempo real, para que la app se
-- entere al instante de lo que cambia otro usuario (por ejemplo, dos
-- celulares con la misma rutina abierta). Ejecutar una vez en Supabase >
-- SQL Editor. Se puede ejecutar de nuevo sin problema.
--
-- Cada usuario solo recibe los cambios de las filas que puede leer según
-- las reglas de cada tabla.

do $$
declare
  t text;
begin
  foreach t in array array[
    'profiles', 'friends', 'muscles', 'exercises', 'routines', 'payments',
    'notification_settings', 'training_messages'
  ] loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = t
    ) then
      execute format('alter publication supabase_realtime add table %I', t);
    end if;
  end loop;
end $$;
