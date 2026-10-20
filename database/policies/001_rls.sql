DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['organizations','users','user_profiles','candidates','audit_log']
  LOOP
    EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('ALTER TABLE %I FORCE ROW LEVEL SECURITY', t);
    EXECUTE format('DROP POLICY IF EXISTS tenant_isolation ON %I', t);
    EXECUTE format($p$CREATE POLICY tenant_isolation ON %I
      USING (tenant_id = NULLIF(current_setting('app.current_tenant_id', true), '')::bigint)
      WITH CHECK (tenant_id = NULLIF(current_setting('app.current_tenant_id', true), '')::bigint)$p$, t);
  END LOOP;
END $$;

DROP POLICY IF EXISTS root_lookup ON organizations;
CREATE POLICY root_lookup ON organizations
  FOR SELECT TO skillsync_admin
  USING (parent_id IS NULL);

CREATE OR REPLACE FUNCTION resolve_tenant(p_slug text)
RETURNS TABLE (out_tenant_id bigint, out_status_id smallint)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT id, status_id FROM organizations
  WHERE parent_id IS NULL AND slug = lower(p_slug);
$$;

REVOKE ALL ON FUNCTION resolve_tenant(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION resolve_tenant(text) TO skillsync_app;