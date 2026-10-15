/// Datos del proyecto de Supabase (Project Settings > API Keys). Mientras
/// estén vacíos la app usa la base de mentira, que no guarda nada.
///
/// La clave es la "publishable key" (o la "anon key" de los proyectos
/// viejos), NUNCA la "secret" ni la "service_role". Es pública por diseño:
/// lo que protege los datos son las reglas (RLS) de supabase/schema.sql, que
/// exigen haber iniciado sesión.
const supabaseUrl = 'https://bqddqrtjqyzvrwnfjczb.supabase.co';
const supabasePublishableKey = 'sb_publishable_IkcL0ZYSZaVc5j5WbnABZA_aTo-clr7';

bool get supabaseConfigured =>
    supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;

/// Supabase identifica a los usuarios por email. Para poder entrar
/// escribiendo solo "cami", al usuario se le agrega este dominio:
/// cami -> cami@gym.app. Si se escribe un email completo se usa tal cual.
const loginEmailDomain = 'gym.app';

/// Único usuario que ve y maneja los mensajes de los días de entrenamiento.
/// Si se cambia, cambiar también la regla de training_messages en la base
/// (supabase/007_mensajes_admin.sql).
const trainingMessagesAdmin = 'cami';

/// Clave pública para las notificaciones (Web Push, "VAPID"). La privada
/// que va con esta está guardada como secreto en Supabase (ver
/// supabase/NOTIFICACIONES.md). Si se cambia una, hay que cambiar las dos.
const vapidPublicKey =
    'BJGwy9AZKbJ7G3OP2n-xHD8WZOeLFbcbF3SQdrurRKTSL6Nr2ifxb5VBC2vIOx8XHPo46i_0X2jfZJv8gA_1joQ';

/// Commit de git con el que se compiló la versión publicada (lo pasa Vercel,
/// ver vercel.json). Vacío al correr la app en la compu.
const appCommit = String.fromEnvironment('COMMIT');

/// Versión corta del commit, como la muestra Vercel ("5ae3a67").
String get appVersion => appCommit.isEmpty
    ? 'local'
    : appCommit.substring(0, appCommit.length < 7 ? appCommit.length : 7);
