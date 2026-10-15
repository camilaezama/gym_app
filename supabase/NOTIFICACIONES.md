# Notificaciones

Las notificaciones las manda un servidor: el celular solo las recibe. Todos
los días a las 10 (hora de Argentina) un cron de la base llama a la función
`send-notifications`, que revisa quién tiene activadas las notificaciones y
le manda lo que corresponda:

- **Recordatorio de pago**: "Quedan 3 días para que tengas que pagar el gym"
  y, el día que se cumple el mes, "Ya deberías pagar el gym".
- **Días de entrenamiento**: un mensaje al azar de la tabla
  `training_messages`, los días elegidos.

Cada usuario las activa en Perfil > Notificaciones (arrancan desactivadas).
En el iPhone solo funcionan con la app abierta desde el ícono de la pantalla
de inicio, con iOS 16.4 o más nuevo.

## Configuración (una sola vez)

### 1. Tablas

En **SQL Editor**, pegar y ejecutar `006_notificaciones.sql` y después
`007_mensajes_admin.sql` (los mensajes de entrenamiento solo los ve y
cambia cami).

### 2. Función

En **Edge Functions > Deploy a new function > Via Editor**:

1. Nombre: `send-notifications`.
2. Pegar el contenido de `functions/send-notifications/index.ts` y publicar.
3. En los **Details** de la función, desactivar **Verify JWT**: la función
   controla sola quién la llama (el cron con `CRON_SECRET`, o un usuario con
   sesión para la notificación de prueba).

### 3. Secretos

En **Edge Functions > Secrets**, agregar:

| Nombre              | Valor                                        |
| ------------------- | -------------------------------------------- |
| `VAPID_PUBLIC_KEY`  | La misma clave que `vapidPublicKey` en `lib/config.dart` |
| `VAPID_PRIVATE_KEY` | La clave privada que va con la pública       |
| `VAPID_SUBJECT`     | `mailto:` y un email de contacto             |
| `CRON_SECRET`       | Una contraseña larga cualquiera              |

La clave privada y `CRON_SECRET` no van en el repositorio. Si se pierde la
privada hay que generar un par nuevo, cambiar la pública en `config.dart` y
que cada uno vuelva a activar las notificaciones.

### 4. Cron

En **SQL Editor**, activar las extensiones (en Integrations figuran como
"Cron" y "Database Webhooks", pero así es más directo):

```sql
create extension if not exists pg_cron with schema pg_catalog;
create extension if not exists pg_net with schema extensions;
```

Después ejecutar esto reemplazando `<CRON_SECRET>` (sin los `< >`):

```sql
-- 13 h UTC son las 10 en Argentina.
select cron.schedule(
  'notificaciones-gym',
  '0 13 * * *',
  $$
  select net.http_post(
    url := 'https://bqddqrtjqyzvrwnfjczb.supabase.co/functions/v1/send-notifications',
    headers := jsonb_build_object(
      'Authorization', 'Bearer <CRON_SECRET>',
      'Content-Type', 'application/json'
    ),
    body := '{}'::jsonb
  );
  $$
);
```

Para cambiar la hora: `select cron.unschedule('notificaciones-gym');` y volver
a ejecutar lo de arriba con otra hora.

### 5. Probar

Publicar la app, abrirla desde el ícono de inicio, ir a Perfil >
Notificaciones, activar alguna, aceptar el permiso y tocar **Mandar una de
prueba**.
