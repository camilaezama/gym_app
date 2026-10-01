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

/// Commit de git con el que se compiló la versión publicada (lo pasa Vercel,
/// ver vercel.json). Vacío al correr la app en la compu.
const appCommit = String.fromEnvironment('COMMIT');

/// Versión corta del commit, como la muestra Vercel ("5ae3a67").
String get appVersion => appCommit.isEmpty
    ? 'local'
    : appCommit.substring(0, appCommit.length < 7 ? appCommit.length : 7);
