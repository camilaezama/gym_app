-- Opcional: carga los ejercicios iniciales con los pesos de Cami y Agos.
-- Ejecutar una sola vez, DESPUÉS de schema.sql y de crear los usuarios
-- cami@gym.app y agos@gym.app en Authentication.

do $$
declare
  cami_id text := (select id::text from profiles where name = 'Cami');
  agos_id text := (select id::text from profiles where name = 'Agos');
begin
  if cami_id is null or agos_id is null then
    raise exception 'Primero creá los usuarios Cami y Agos en Authentication';
  end if;

  insert into exercises (name, body_part, weight_type, initial_weights)
  select e.name, e.body_part, e.weight_type,
         jsonb_build_object(cami_id, e.cami, agos_id, e.agos)
  from (values
    ('Triceps con soga',               'superior', 'ladrillos',  '[2]'::jsonb,          '[3]'::jsonb),
    ('Triceps catana',                 'superior', 'mancuernas', '[5]',                 '[5]'),
    ('Press plano con barra',          'superior', 'barra',      '[3.75]',              '[2.5]'),
    ('Press plano con mancuernas',     'superior', 'mancuernas', '[8]',                 '[8]'),
    ('Press inclinado con mancuernas', 'superior', 'mancuernas', '[6]',                 '[6]'),
    ('Bicep martillo con mancuernas',  'superior', 'mancuernas', '[5]',                 '[7.5]'),
    ('Pecho Hammer',                   'superior', 'barra',      '[10]',                '[10]'),
    ('Hip Trust Con Barra',            'inferior', 'barra',      '[20, 25, 25]',        '[30, 35, 40]'),
    ('Peso muerto con mancuernas',     'inferior', 'mancuernas', '[8]',                 '[12.5]'),
    ('Prensa',                         'inferior', 'total',      '[60]',                '[100]'),
    ('Bulgaras',                       'inferior', 'mancuernas', '[5]',                 '[5]'),
    ('Sillon cuadriceps',              'inferior', 'ladrillos',  '[7]',                 '[8]'),
    ('Sillon isquio',                  'inferior', 'ladrillos',  '[3]',                 '[4]'),
    ('Sentadilla Smith',               'inferior', 'barra',      '[15]',                '[15]'),
    ('Sentadilla Isometrica',          'inferior', 'tiempo',     '[30]',                '[30]')
  ) as e (name, body_part, weight_type, cami, agos);
end $$;
