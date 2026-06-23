const { createClient } = require("@supabase/supabase-js");

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseServiceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl) {
  // eslint-disable-next-line no-console
  console.warn(
    "[supabase] SUPABASE_URL가 설정되지 않았습니다.",
  );
}
if (!supabaseServiceRoleKey) {
  // eslint-disable-next-line no-console
  console.warn(
    "[supabase] SUPABASE_SERVICE_ROLE_KEY가 설정되지 않았습니다.",
  );
}

const supabase = supabaseUrl && supabaseServiceRoleKey
    ? createClient(supabaseUrl, supabaseServiceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
      }): null;

module.exports = supabase;
