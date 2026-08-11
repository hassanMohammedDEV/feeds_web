-- ============================================================
-- كلمة مرور لوحة الإدارة — مخزنة في قاعدة البيانات
-- تنفيذ: Supabase Dashboard -> SQL Editor -> Run
-- ============================================================

-- 1) إدخال كلمة المرور الافتراضية (admin123)
--    لن تُستبدل إذا كان المفتاح موجوداً مسبقاً
INSERT INTO public.settings (key, value) VALUES
    ('admin_password', 'admin123')
ON CONFLICT (key) DO NOTHING;


-- ============================================================
-- 2) دالة التحقق من كلمة المرور (في الخادم)
-- ============================================================
create or replace function verify_admin_password(p_password text)
returns json
language plpgsql
security definer
as $$
declare
    v_value text;
begin
    select value into v_value
    from public.settings
    where key = 'admin_password';

    if v_value is null or p_password is null then
        return json_build_object('code', 200, 'valid', false);
    end if;

    if p_password = v_value then
        return json_build_object('code', 200, 'valid', true);
    end if;

    return json_build_object('code', 200, 'valid', false);
exception when others then
    return json_build_object('code', 500, 'message', 'حدث خطأ أثناء التحقق من كلمة المرور');
end;
$$;


-- ============================================================
-- 3) دالة تغيير كلمة المرور (تتطلب كلمة المرور الحالية)
-- ============================================================
create or replace function update_admin_password(
    p_current text,
    p_new text
)
returns json
language plpgsql
security definer
as $$
declare
    v_value text;
begin
    if p_new is null or length(trim(p_new)) < 6 then
        return json_build_object('code', 400, 'message', 'كلمة المرور الجديدة قصيرة جداً (6 أحرف على الأقل)');
    end if;

    select value into v_value
    from public.settings
    where key = 'admin_password';

    if v_value is null or p_current is null or p_current <> v_value then
        return json_build_object('code', 403, 'message', 'كلمة المرور الحالية غير صحيحة');
    end if;

    update public.settings
    set value = trim(p_new),
        updated_at = now()
    where key = 'admin_password';

    return json_build_object('code', 200, 'message', 'تم تغيير كلمة المرور بنجاح');
exception when others then
    return json_build_object('code', 500, 'message', 'حدث خطأ أثناء تغيير كلمة المرور');
end;
$$;


-- ============================================================
-- 4) استثناء كلمة المرور من جلب الإعدادات (لا تُرسل للعميل)
-- ============================================================
create or replace function get_settings()
returns json
language plpgsql
security definer
as $$
declare
    v_settings json;
begin
    select json_object_agg(key, value) into v_settings
    from public.settings
    where key <> 'admin_password';

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
