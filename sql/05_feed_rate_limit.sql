-- ============================================================
-- منع إرسال أكثر من 5 مشاركات يومياً من نفس العنوان
-- تنفيذ: Supabase Dashboard -> SQL Editor -> Run
-- ============================================================

-- 1) عمود لتخزين عنوان المرسل (للإحصاء والمنع)
ALTER TABLE feeds ADD COLUMN IF NOT EXISTS client_ip TEXT;

-- 2) إعادة إنشاء insert_feed مع:
--    - حفظ الاسم ورقم الجوال (اختياريان)
--    - حفظ عنوان المرسل client_ip
--    - منع تجاوز 5 مشاركات خلال 24 ساعة من نفس العنوان
CREATE OR REPLACE FUNCTION insert_feed(
  p_content TEXT,
  p_type INTEGER,
  p_name TEXT DEFAULT NULL,
  p_phone TEXT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  new_id UUID;
  v_name TEXT;
  v_phone TEXT;
  v_ip TEXT;
  v_xff TEXT;
  v_recent_count INTEGER;
BEGIN
  v_name  := NULLIF(TRIM(p_name), '');
  v_phone := NULLIF(TRIM(p_phone), '');

  -- استخراج عنوان المرسل من ترويسات الطلب (يضعها PostgREST)
  BEGIN
    v_xff := (current_setting('request.headers', true)::jsonb ->> 'x-forwarded-for');
  EXCEPTION WHEN OTHERS THEN
    v_xff := NULL;
  END;

  IF v_xff IS NULL OR trim(v_xff) = '' THEN
    v_ip := 'unknown';
  ELSE
    -- العنوان الحقيقي هو آخر عنوان في السلسلة (يُضاف بواسطة بوابة Supabase ولا يمكن للمرسل تزويره)
    v_ip := trim(split_part(v_xff, ',', array_length(string_to_array(v_xff, ','), 1)));
  END IF;

  -- عدد المشاركات من نفس العنوان خلال آخر 24 ساعة
  SELECT count(*) INTO v_recent_count
  FROM public.feeds
  WHERE client_ip = v_ip
    AND created_at > now() - interval '24 hours';

  -- تجاوز الحد الأقصى (5)
  IF v_recent_count >= 5 THEN
    RETURN json_build_object(
      'code', 429,
      'message', 'لقد تجاوزت الحد المسموح به (5 مشاركات يومياً). يرجى المحاولة غداً.'
    );
  END IF;

  INSERT INTO public.feeds (content, type, name, phone, client_ip)
  VALUES (p_content, p_type, v_name, v_phone, v_ip)
  RETURNING id INTO new_id;

  RETURN json_build_object('code', 200, 'message', 'success', 'id', new_id);
EXCEPTION WHEN OTHERS THEN
  RETURN json_build_object('code', 500, 'message', 'حدث خطأ أثناء الحفظ');
END;
$$;
