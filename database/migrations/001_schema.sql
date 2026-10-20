-- =========================================================
-- REFERENCE TABLES (global lookups, no tenant_id, no RLS)
-- =========================================================
CREATE TABLE ref_org_types (
  id          smallint PRIMARY KEY,
  code        text NOT NULL UNIQUE,
  description text
);
INSERT INTO ref_org_types (id, code, description) VALUES
  (0, 'COMPANY', 'Company or corporate organization'),
  (1, 'COLLEGE', 'College or educational institution');

CREATE TABLE ref_org_kinds (
  id          smallint PRIMARY KEY,
  code        text NOT NULL UNIQUE,
  description text
);
INSERT INTO ref_org_kinds (id, code, description) VALUES
  (0, 'INTERNAL', 'Internal testing / tech team org (is_client = false)'),
  (1, 'CLIENT',   'Real paying client org (is_client = true)'),
  (2, 'DEMO',     'Sales demo or trial org');

CREATE TABLE ref_org_statuses (
  id          smallint PRIMARY KEY,
  code        text NOT NULL UNIQUE,
  description text
);
INSERT INTO ref_org_statuses (id, code, description) VALUES
  (0, 'SUSPENDED', 'Org switched off, data kept'),
  (1, 'ACTIVE',    'Org in normal use');

CREATE TABLE ref_user_roles (
  id          smallint PRIMARY KEY,
  code        text NOT NULL UNIQUE,
  description text
);
INSERT INTO ref_user_roles (id, code, description) VALUES
  (0, 'ORG_ADMIN', 'Manages the organization and its staff'),
  (1, 'TEACHER',   'Creates assessments and manages candidates'),
  (2, 'PROCTOR',   'Monitors candidates during a test'),
  (3, 'EVALUATOR', 'Reviews and scores submissions');

CREATE TABLE ref_user_statuses (
  id          smallint PRIMARY KEY,
  code        text NOT NULL UNIQUE,
  description text
);
INSERT INTO ref_user_statuses (id, code, description) VALUES
  (0, 'INACTIVE', 'User disabled, cannot log in'),
  (1, 'ACTIVE',   'User can log in');

CREATE TABLE ref_candidate_statuses (
  id          smallint PRIMARY KEY,
  code        text NOT NULL UNIQUE,
  description text
);
INSERT INTO ref_candidate_statuses (id, code, description) VALUES
  (0, 'INACTIVE', 'Candidate disabled'),
  (1, 'ACTIVE',   'Candidate can take assessments');

CREATE TABLE ref_actor_types (
  id          smallint PRIMARY KEY,
  code        text NOT NULL UNIQUE,
  description text
);
INSERT INTO ref_actor_types (id, code, description) VALUES
  (0, 'SYSTEM',         'Automated action by the platform'),
  (1, 'PLATFORM_ADMIN', 'Internal platform team member'),
  (2, 'USER',           'Organization staff user'),
  (3, 'CANDIDATE',      'Candidate or student');
-- =========================================================
-- ORGANIZATIONS: one global counter for roots AND children
-- =========================================================
CREATE TABLE organizations (
  id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id  bigint NOT NULL REFERENCES organizations(id),   -- set by trigger
  parent_id  bigint,
  name       text NOT NULL,                                   -- not unique, by design
  slug       text UNIQUE,                                     -- roots only
  type_id    smallint NOT NULL REFERENCES ref_org_types(id),
  kind_id    smallint REFERENCES ref_org_kinds(id),           -- roots only
  status_id  smallint NOT NULL DEFAULT 1 REFERENCES ref_org_statuses(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, id),
  FOREIGN KEY (tenant_id, parent_id) REFERENCES organizations (tenant_id, id),
  CHECK (
    (parent_id IS NULL AND tenant_id = id AND kind_id IS NOT NULL AND slug IS NOT NULL)
 OR (parent_id IS NOT NULL AND tenant_id <> id AND kind_id IS NULL AND slug IS NULL)
  )
);

CREATE FUNCTION set_org_tenant() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.parent_id IS NULL THEN
    NEW.tenant_id := NEW.id;                       -- root: tenant is itself
  ELSE
    SELECT tenant_id INTO NEW.tenant_id            -- child: same tenant as parent
    FROM organizations WHERE id = NEW.parent_id;
  END IF;
  RETURN NEW;
END $$;

CREATE TRIGGER organizations_set_tenant
BEFORE INSERT ON organizations
FOR EACH ROW EXECUTE FUNCTION set_org_tenant();

-- =========================================================
-- STAFF USERS (one org each)
-- =========================================================
CREATE TABLE users (
  id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id     bigint NOT NULL,
  org_id        bigint NOT NULL,
  email         text NOT NULL,
  password_hash text NOT NULL,
  role_id       smallint NOT NULL REFERENCES ref_user_roles(id),
  status_id     smallint NOT NULL DEFAULT 1 REFERENCES ref_user_statuses(id),
  created_at    timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, id),
  FOREIGN KEY (tenant_id, org_id) REFERENCES organizations (tenant_id, id)
);
CREATE UNIQUE INDEX users_tenant_email_uq ON users (tenant_id, lower(email));

CREATE TABLE user_profiles (
  user_id     bigint PRIMARY KEY,                -- same number as the user it belongs to
  tenant_id   bigint NOT NULL,
  full_name   text NOT NULL,
  phone       text,
  designation text,
  FOREIGN KEY (tenant_id, user_id) REFERENCES users (tenant_id, id) ON DELETE CASCADE
);

-- =========================================================
-- CANDIDATES
-- =========================================================
CREATE TABLE candidates (
  id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id     bigint NOT NULL,
  org_id        bigint NOT NULL,
  email         text NOT NULL,
  full_name     text NOT NULL,
  roll_no       text,
  password_hash text,                            -- nullable: invitation-only
  status_id     smallint NOT NULL DEFAULT 1 REFERENCES ref_candidate_statuses(id),
  created_at    timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (tenant_id, org_id) REFERENCES organizations (tenant_id, id)
);
CREATE UNIQUE INDEX candidates_org_email_uq ON candidates (org_id, lower(email));
CREATE UNIQUE INDEX candidates_org_roll_uq  ON candidates (org_id, roll_no) WHERE roll_no IS NOT NULL;

-- =========================================================
-- OUTSIDE TENANTS
-- =========================================================
CREATE TABLE platform_admins (
  id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  email         text NOT NULL UNIQUE,
  password_hash text NOT NULL,
  status_id     smallint NOT NULL DEFAULT 1 REFERENCES ref_user_statuses(id),
  created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE audit_log (
  id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id     bigint,
  actor_type_id smallint NOT NULL REFERENCES ref_actor_types(id),
  actor_id      bigint,
  action        text NOT NULL,
  created_at    timestamptz NOT NULL DEFAULT now()
);

-- =========================================================
-- PRIVILEGES
-- =========================================================
REVOKE ALL ON platform_admins FROM skillsync_app;
REVOKE UPDATE, DELETE ON audit_log FROM skillsync_app;
REVOKE INSERT, UPDATE, DELETE ON
  ref_org_types, ref_org_kinds, ref_org_statuses,
  ref_user_roles, ref_user_statuses, ref_candidate_statuses, ref_actor_types
FROM skillsync_app;