-- DEV ONLY. Every dev account uses the password:  DevPass#123
CREATE EXTENSION IF NOT EXISTS pgcrypto;

INSERT INTO platform_admins (email, password_hash)
VALUES ('platform@skillsync.local', crypt('DevPass#123', gen_salt('bf', 10)))
ON CONFLICT (email) DO NOTHING;

-- Tenant 1: Dev College (root) + CSE Department (child)
INSERT INTO organizations (name, slug, type_id, kind_id)
VALUES ('Dev College of Engineering', 'dev-college', 1, 1);

INSERT INTO organizations (parent_id, name, type_id)
SELECT id, 'CSE Department', 1 FROM organizations WHERE slug = 'dev-college';

-- Tenant 2: Test Corp (root, internal)
INSERT INTO organizations (name, slug, type_id, kind_id)
VALUES ('Test Corp', 'test-corp', 0, 0);

-- Staff
INSERT INTO users (tenant_id, org_id, email, password_hash, role_id)
SELECT id, id, 'admin@dev-college.local', crypt('DevPass#123', gen_salt('bf', 10)), 0
FROM organizations WHERE slug = 'dev-college';

INSERT INTO users (tenant_id, org_id, email, password_hash, role_id)
SELECT tenant_id, id, 'teacher@dev-college.local', crypt('DevPass#123', gen_salt('bf', 10)), 1
FROM organizations WHERE name = 'CSE Department';

INSERT INTO users (tenant_id, org_id, email, password_hash, role_id)
SELECT id, id, 'admin@test-corp.local', crypt('DevPass#123', gen_salt('bf', 10)), 0
FROM organizations WHERE slug = 'test-corp';

INSERT INTO user_profiles (user_id, tenant_id, full_name, designation)
SELECT id, tenant_id, 'Dev College Admin', 'Administrator' FROM users WHERE email = 'admin@dev-college.local';
INSERT INTO user_profiles (user_id, tenant_id, full_name, designation)
SELECT id, tenant_id, 'Dev Teacher', 'Assistant Professor' FROM users WHERE email = 'teacher@dev-college.local';
INSERT INTO user_profiles (user_id, tenant_id, full_name, designation)
SELECT id, tenant_id, 'Test Corp Admin', 'HR Manager' FROM users WHERE email = 'admin@test-corp.local';

-- Candidates
INSERT INTO candidates (tenant_id, org_id, email, full_name, roll_no)
SELECT tenant_id, id, 'student1@dev-college.local', 'Student One', 'CSE001'
FROM organizations WHERE name = 'CSE Department';
INSERT INTO candidates (tenant_id, org_id, email, full_name, roll_no, password_hash)
SELECT tenant_id, id, 'student2@dev-college.local', 'Student Two', 'CSE002', crypt('DevPass#123', gen_salt('bf', 10))
FROM organizations WHERE name = 'CSE Department';
INSERT INTO candidates (tenant_id, org_id, email, full_name)
SELECT tenant_id, id, 'alice@test-corp.local', 'Alice Candidate'
FROM organizations WHERE slug = 'test-corp';