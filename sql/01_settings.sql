-- =================================================================================
-- 1. إنشاء جدول الإعدادات
-- =================================================================================
CREATE TABLE IF NOT EXISTS public.settings (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    key TEXT UNIQUE NOT NULL,
    value TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- إدراج القيم الافتراضية
INSERT INTO public.settings (key, value) VALUES
    ('notification_email', '7assanwr@gmail.com'),
    ('notifications_enabled', 'true')
ON CONFLICT (key) DO UPDATE
    SET value = EXCLUDED.value,
        updated_at = NOW();


-- =================================================================================
-- 2. دالة جلب جميع الإعدادات
-- =================================================================================
create or replace function get_settings()
returns json
language plpgsql
security definer
as $$
declare
    v_settings json;
begin
    select json_object_agg(key, value) into v_settings
    from public.settings;

    if v_settings is null then
        v_settings := '{}'::json;
    end if;

    return json_build_object(
        'code', 200,
        'data', v_settings
    );
exception when others then
    return json_build_object(
        'code', 500,
        'message', 'حدث خطأ أثناء جلب الإعدادات'
    );
end;
$$;


-- =================================================================================
-- 3. دالة تحديث إعداد
-- =================================================================================
create or replace function update_setting(
    p_key text,
    p_value text
)
returns json
language plpgsql
security definer
as $$
begin
    insert into public.settings (key, value)
    values (p_key, p_value)
    on conflict (key) do update
        set value = p_value,
            updated_at = now();

    return json_build_object(
        'code', 200,
        'message', 'تم تحديث الإعداد بنجاح'
    );
exception when others then
    return json_build_object(
        'code', 500,
        'message', 'حدث خطأ أثناء تحديث الإعداد'
    );
end;
$$;


-- =================================================================================
-- 4. تفعيل RLS على جدول الإعدادات
-- =================================================================================
ALTER TABLE public.settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Restrict direct access" 
ON public.settings 
FOR ALL 
TO authenticated 
USING (false);  -- الوصول فقط عبر الدوال المحمية
