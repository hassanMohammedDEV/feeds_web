-- =================================================================================
-- تفعيل الإشعارات البريدية التلقائية
-- يستخدم pg_net لإرسال طلبات HTTP إلى Resend API
-- الإعدادات (البريد والحالة) مقروءة من جدول settings
-- =================================================================================

-- 1. تفعيل pg_net إن لم يكن مفعلاً
create extension if not exists pg_net;

-- 2. حفظ مفتاح Resend في إعدادات قاعدة البيانات
-- ⚠️ استبدل المفتاح بمفتاحك الحقيقي من Resend Dashboard
alter database postgres set app.resend_key to 're_ضع_هنا_مفتاح_Resend';

-- 3. دالة إرسال الإشعار
create or replace function notify_feed_insert()
returns trigger
language plpgsql
security definer
as $$
declare
    v_api_key text := current_setting('app.resend_key', true);
    v_email text;
    v_enabled text;
    v_subject text;
    v_type_label text;
    v_type_color text;
begin
    select value into v_email from public.settings where key = 'notification_email';
    select value into v_enabled from public.settings where key = 'notifications_enabled';

    if v_enabled = 'false' or v_email is null or trim(v_email) = '' then
        return new;
    end if;

    if new.type = 1 then
        v_subject := '⚠️ شكوى جديدة';
        v_type_label := 'شكوى';
        v_type_color := '#ef4444';
    else
        v_subject := '💡 اقتراح جديد';
        v_type_label := 'اقتراح';
        v_type_color := '#10b981';
    end if;

    perform net.http_post(
        url := 'https://api.resend.com/emails',
        headers := jsonb_build_object(
            'Authorization', 'Bearer ' || v_api_key,
            'Content-Type', 'application/json'
        ),
        body := jsonb_build_object(
            'from',    'نظام الاقتراحات <onboarding@resend.dev>',
            'to',      v_email,
            'subject', v_subject,
            'html',    format(
                '<div style="font-family:Arial,sans-serif;direction:rtl;padding:24px;background:#f9fafb;max-width:600px;margin:0 auto">
                   <div style="background:%s;padding:12px 20px;border-radius:10px 10px 0 0">
                     <h2 style="color:#fff;margin:0;font-size:18px">%s</h2>
                   </div>
                   <div style="background:#fff;padding:24px;border:1px solid #e5e7eb;border-top:none;border-radius:0 0 10px 10px">
                     <div style="margin-bottom:16px">
                       <span style="display:inline-block;padding:4px 14px;border-radius:100px;font-size:13px;font-weight:bold;background:%s15;color:%s">%s</span>
                     </div>
                     <p style="font-size:16px;line-height:1.8;color:#333;margin:0">%s</p>
                     <hr style="border:none;border-top:1px solid #e5e7eb;margin:16px 0" />
                     <small style="color:#999">🆔 %s</small><br />
                     <small style="color:#999">📅 %s</small>
                   </div>
                   <p style="text-align:center;color:#aaa;font-size:12px;margin-top:12px">هذا الإيميل تلقائي - لا ترد عليه</p>
                 </div>',
                v_type_color,
                v_subject,
                v_type_color, v_type_color, v_type_label,
                new.content,
                new.id,
                to_char(new.created_at, 'YYYY-MM-DD HH24:MI')
            )
        )::text
    );

    return new;
end;
$$;

-- 4. إنشاء trigger
drop trigger if exists on_feed_insert on public.feeds;
create trigger on_feed_insert
    after insert on public.feeds
    for each row
    execute function notify_feed_insert();
