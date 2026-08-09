-- ============================================================
-- إضافة الاسم ورقم الجوال (اختياريان) لجدول المشاركات
-- تنفيذ: Supabase Dashboard -> SQL Editor -> Run
-- ============================================================

-- 1) إضافة العمودين الجديدين (آمنة التكرار)
ALTER TABLE feeds ADD COLUMN IF NOT EXISTS name TEXT;
ALTER TABLE feeds ADD COLUMN IF NOT EXISTS phone TEXT;

-- 2) تحديث دالة الإدراج لتقبل الحقلين الاختياريين
-- ملاحظة: تأكد من الاطلاع على النسخة الحالية من الدالة أولاً
--   SELECT prosrc FROM pg_proc WHERE proname = 'insert_feed';
-- وحافظ على أي منطق إضافي موجود فيها (إشعارات، تحقق، ... إلخ)
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
BEGIN
  v_name  := NULLIF(TRIM(p_name), '');
  v_phone := NULLIF(TRIM(p_phone), '');

  INSERT INTO feeds (content, type, name, phone)
  VALUES (p_content, p_type, v_name, v_phone)
  RETURNING id INTO new_id;

  RETURN json_build_object('code', 200, 'message', 'success', 'id', new_id);
END;
$$;

-- 3) تأكد أن دالة جلب المشاركات تعيد الأعمدة الجديدة
-- إذا كانت get_all_feeds تستخدم SELECT * فهذا تلقائي،
-- وإلا أضف name, phone إلى قائمة الأعمدة في الاستعلام.
