-- Cambio para una base ya creada con la primera versión de schema.sql:
-- agrega la columna que permite eliminar (archivar) ejercicios.
-- Ejecutar una vez en Supabase > SQL Editor.

alter table exercises
  add column if not exists archived boolean not null default false;
