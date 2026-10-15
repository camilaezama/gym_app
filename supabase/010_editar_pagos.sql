-- Cambio para una base ya creada: permite editar la fecha y el monto de los
-- pagos propios. Ejecutar una vez en Supabase > SQL Editor.

create policy "cada uno edita sus pagos" on payments
  for update to authenticated
  using (person_id = auth.uid())
  with check (person_id = auth.uid());
