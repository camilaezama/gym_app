-- Cambio para una base que ya tiene la tabla muscles (003_musculos.sql):
-- agrega el ícono de cada músculo. Ejecutar una vez en Supabase > SQL Editor.

-- Nombre del ícono (biceps, gluteos...): la imagen está en
-- assets/muscles/<icon>.png. null: sin ícono.
alter table muscles add column if not exists icon text;

-- Les pone ícono a los músculos ya creados cuyo nombre coincide con uno
-- (sin importar mayúsculas ni tildes: "Glúteos" -> gluteos).
update muscles
set icon = translate(lower(name), 'áéíóú', 'aeiou')
where icon is null
  and translate(lower(name), 'áéíóú', 'aeiou') in (
    'hombros', 'espalda', 'pecho', 'biceps', 'triceps', 'abdominales',
    'gluteos', 'cuadriceps', 'isquiotibiales', 'aductores', 'abductores',
    'gemelos'
  );
