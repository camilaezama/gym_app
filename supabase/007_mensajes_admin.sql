-- Cambio para una base ya creada: los mensajes de los días de entrenamiento
-- solo los puede ver y cambiar cami. Ejecutar una vez en Supabase > SQL
-- Editor. La función send-notifications los sigue leyendo (no pasa por
-- estas reglas).
--
-- Si se cambia el usuario, cambiar también trainingMessagesAdmin en
-- lib/config.dart.

drop policy if exists "usuarios manejan mensajes" on training_messages;
drop policy if exists "solo cami maneja mensajes" on training_messages;

create policy "solo cami maneja mensajes" on training_messages
  for all to authenticated
  using (auth.jwt() ->> 'email' = 'cami@gym.app')
  with check (auth.jwt() ->> 'email' = 'cami@gym.app');
