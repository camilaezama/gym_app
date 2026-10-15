// Manda las notificaciones de la app (Web Push). La llama todos los días a
// las 10 un cron de la base (ver supabase/NOTIFICACIONES.md):
//   - Recordatorio de pago: a los que les faltan 3 días para que se cumpla
//     el mes desde el último pago, y a los que se les cumple hoy.
//   - Día de entrenamiento: un mensaje al azar a los que entrenan hoy.
// Llamada desde la app con la sesión de un usuario ({"test": true}), solo le
// manda a él una notificación de prueba.
//
// Secretos que necesita (Edge Functions > Secrets): VAPID_PUBLIC_KEY,
// VAPID_PRIVATE_KEY, VAPID_SUBJECT y CRON_SECRET. SUPABASE_URL y
// SUPABASE_SERVICE_ROLE_KEY los pone Supabase solo.

import { createClient } from 'npm:@supabase/supabase-js@2.45.4';
import webpush from 'npm:web-push@3.6.7';

/// Las fechas y los días de la semana se calculan en hora de Argentina.
const timeZone = 'America/Argentina/Buenos_Aires';

const paymentWarningDays = 3;

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

const db = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
);

webpush.setVapidDetails(
  Deno.env.get('VAPID_SUBJECT')!,
  Deno.env.get('VAPID_PUBLIC_KEY')!,
  Deno.env.get('VAPID_PRIVATE_KEY')!,
);

type Notification = { title: string; body: string; tag: string };

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  try {
    const token = (req.headers.get('Authorization') ?? '').replace('Bearer ', '');
    if (token && token === Deno.env.get('CRON_SECRET')) {
      const sent = await sendDailyNotifications();
      return json({ sent });
    }
    // Si no es el cron, tiene que ser un usuario con sesión iniciada.
    const { data, error } = await db.auth.getUser(token);
    if (error || !data.user) return json({ error: 'No autorizado' }, 401);
    const sent = await sendToUser(data.user.id, {
      title: 'Gym App',
      body: 'Las notificaciones funcionan 💪',
      tag: 'prueba',
    });
    if (sent === 0) {
      return json({ error: 'No hay dispositivos registrados' }, 404);
    }
    return json({ sent });
  } catch (e) {
    console.error(e);
    return json({ error: String(e) }, 500);
  }
});

async function sendDailyNotifications(): Promise<number> {
  const today = todayInArgentina();
  const { data: settings, error } = await db
    .from('notification_settings')
    .select()
    .or('payment_reminders.eq.true,training_reminders.eq.true');
  if (error) throw error;

  const { data: messages } = await db.from('training_messages').select('text');
  let sent = 0;
  for (const row of settings ?? []) {
    if (row.training_reminders && row.training_days.includes(today.weekday)) {
      const texts = (messages ?? []).map((m) => m.text as string);
      if (texts.length > 0) {
        const body = texts[Math.floor(Math.random() * texts.length)];
        sent += await sendToUser(row.user_id, {
          title: 'Gym App',
          body,
          tag: 'entreno',
        });
      }
    }
    if (row.payment_reminders) {
      const days = await daysUntilPaymentDue(row.user_id, today.date);
      const body = days === paymentWarningDays
        ? `Quedan ${paymentWarningDays} días para que tengas que pagar el gym`
        : days === 0
        ? 'Ya deberías pagar el gym'
        : null;
      if (body) {
        sent += await sendToUser(row.user_id, {
          title: 'Pago del gym',
          body,
          tag: 'pago',
        });
      }
    }
  }
  return sent;
}

/// Días que faltan para que se cumpla un mes del último pago, o null si el
/// usuario nunca cargó uno. Igual que Payment.dueDate en lib/models.dart.
async function daysUntilPaymentDue(
  userId: string,
  today: Date,
): Promise<number | null> {
  const { data } = await db
    .from('payments')
    .select('date')
    .eq('person_id', userId)
    .order('date', { ascending: false })
    .limit(1);
  if (!data || data.length === 0) return null;
  const [y, m, d] = (data[0].date as string).split('-').map(Number);
  // El mismo día del mes siguiente, o el último día de ese mes.
  const lastDay = new Date(Date.UTC(y, m + 1, 0)).getUTCDate();
  const due = Date.UTC(y, m, Math.min(d, lastDay));
  return Math.round((due - today.getTime()) / 86_400_000);
}

/// Le manda la notificación a todos los dispositivos del usuario. Devuelve
/// a cuántos llegó. Borra los dispositivos que ya no existen.
async function sendToUser(userId: string, notification: Notification) {
  const { data: subscriptions } = await db
    .from('push_subscriptions')
    .select()
    .eq('user_id', userId);
  let sent = 0;
  for (const row of subscriptions ?? []) {
    try {
      await webpush.sendNotification(row.subscription, JSON.stringify(notification));
      sent++;
    } catch (e) {
      const status = (e as { statusCode?: number }).statusCode;
      if (status === 404 || status === 410) {
        await db.from('push_subscriptions').delete().eq('endpoint', row.endpoint);
      } else {
        console.error('No se pudo mandar a', row.endpoint, e);
      }
    }
  }
  return sent;
}

/// La fecha de hoy en Argentina (a las 0 h UTC) y su día de la semana
/// (1 lunes ... 7 domingo, como en Dart).
function todayInArgentina() {
  const parts = Object.fromEntries(
    new Intl.DateTimeFormat('en-US', {
      timeZone,
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      weekday: 'short',
    })
      .formatToParts(new Date())
      .map((p) => [p.type, p.value]),
  );
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return {
    date: new Date(Date.UTC(+parts.year, +parts.month - 1, +parts.day)),
    weekday: weekdays.indexOf(parts.weekday) + 1,
  };
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}
