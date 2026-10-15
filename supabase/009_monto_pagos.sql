-- Cambio para una base ya creada: agrega cuánto se pagó en cada pago.
-- Ejecutar una vez en Supabase > SQL Editor.

-- Cuánto pagó esa persona; null si no se cargó (los pagos viejos quedan así).
alter table payments add column if not exists amount numeric(12, 2);
