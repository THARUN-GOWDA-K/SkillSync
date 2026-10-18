# SkillSync

> A secure, white-labeled assessment platform for colleges and technology teams to create, deliver, and evaluate coding and aptitude tests at scale.

SkillSync helps hiring and placement teams replace manual screening with automated assessment campaigns. Teams can build mixed-format assessments, invite candidates with branded links, and review structured results while candidate code runs in isolated execution environments.

## Key Features

- **White-labeled assessment experiences** — Serve branded assessment portals for each college or company.
- **Visual assessment builder** — Assemble MCQs, coding challenges, and system-design diagram prompts through a drag-and-drop workflow.
- **Secure remote code execution** — Compile and run untrusted candidate programs through Judge0 in ephemeral Docker sandboxes.
- **Tenant isolation by design** — PostgreSQL Row-Level Security (RLS) ensures records from one organization cannot be queried by another.
- **Asynchronous submissions** — Queue execution work in Redis so candidates receive a fast acknowledgement while grading proceeds in the background.
- **Candidate workspace** — Provide a focused code editor, test status, and submission feedback.
- **Campaign-based billing readiness** — Track assessment campaigns and usage to support pay-per-campaign plans.

## Architecture Overview

```text
HR / Candidate Browser
        |
        v
React Frontend
        |
        v
Express API  -----> PostgreSQL
    |                    |
    |                    +-- RLS policies scoped to current tenant
    v
Redis Job Queue
        |
        v
Worker Service -----> Judge0 API -----> Ephemeral Docker sandbox
                                            | CPU / memory / time limits
                                            | Network disabled
                                            v
                                      Execution result
```

### Multi-tenant data isolation

All tenant-owned tables carry a `tenant_id`. The API resolves the tenant from the request host or authenticated organization, then opens a database transaction with a local tenant context:

```sql
SET LOCAL app.current_tenant_id = 'tenant-uuid';
```

PostgreSQL RLS policies use that context to filter every query and mutation. This creates a database-level safeguard in addition to application authorization. Composite indexes that begin with `tenant_id` keep tenant-scoped assessment and submission queries efficient as records grow.

### Secure code execution

Code never runs in the Express process or the application host environment. On submission, the API records a `PENDING` submission, enqueues a job, and returns `202 Accepted`. A worker forwards the job to Judge0, which compiles and executes it in an isolated Docker environment with strict CPU, memory, process, and execution-time limits. Sandboxes have no outbound network access. The worker persists the final status and output for the candidate and reviewer interfaces.

> For production, run Judge0 and its workers on dedicated infrastructure with hardened container runtime policies, least-privilege credentials, observability, and rate limits.

## Tech Stack

| Area | Technologies |
| --- | --- |
| Frontend | React.js, JavaScript/TypeScript, code editor integration, drag-and-drop UI |
| Backend | Node.js, Express.js, REST API, authentication middleware |
| Database | PostgreSQL, Row-Level Security, tenant-scoped indexes |
| Infrastructure | Docker Compose, Redis, BullMQ-compatible job processing, environment-based configuration |
| Execution Engine | Judge0, Docker, isolated compiler/runtime containers |

## Local Setup

### Prerequisites

- Node.js 20 or later
- npm 10 or later
- Docker Desktop with Docker Compose
- PostgreSQL 15 or later, if it is not supplied by Docker Compose

### 1. Clone the repository

```bash
git clone https://github.com/your-username/skillsync.git
cd skillsync
```

### 2. Configure environment variables

Copy the example file and supply local values:

```bash
cp .env.example .env
```

Use environment variables similar to the following. Keep secrets out of version control.

```env
# API
NODE_ENV=development
PORT=4000
CLIENT_URL=http://localhost:5173
JWT_SECRET=replace-with-a-long-random-development-secret

# PostgreSQL
DATABASE_URL=postgresql://skillsync:skillsync@localhost:5432/skillsync

# Redis and background jobs
REDIS_URL=redis://localhost:6379

# Judge0
JUDGE0_URL=http://localhost:2358
JUDGE0_AUTH_TOKEN=

# Billing provider integration, when enabled
BILLING_PROVIDER_SECRET=
```

### 3. Start infrastructure services

Start PostgreSQL, Redis, Judge0, and their required dependencies through Docker Compose:

```bash
docker compose up -d
```

Confirm the containers are healthy:

```bash
docker compose ps
```

### 4. Install application dependencies

```bash
npm install
```

If the frontend and API live in separate workspaces, install from each package directory:

```bash
cd server && npm install
cd ../client && npm install
```

### 5. Initialize the database

Run schema migrations and seed optional local data. Replace these commands with the migration scripts configured by this repository.

```bash
npm run db:migrate
npm run db:seed
```

### 6. Run the application

Start the API, worker, and frontend in separate terminals:

```bash
npm run dev:api
npm run dev:worker
npm run dev:web
```

The local dashboard is typically available at `http://localhost:5173`, and the API at `http://localhost:4000`.

## API Endpoints

All protected routes require authentication and an organization context. Routes shown below are representative core endpoints.

| Method | Endpoint | Description |
| --- | --- | --- |
| `GET` | `/api/assessments` | List assessments visible to the current tenant. |
| `POST` | `/api/assessments` | Create an assessment with questions, duration, and campaign settings. |
| `GET` | `/api/assessments/:assessmentId` | Retrieve one tenant-scoped assessment. |
| `POST` | `/api/assessments/:assessmentId/invitations` | Create or send candidate assessment invitations. |
| `POST` | `/api/submissions` | Save a candidate submission and enqueue code evaluation. Returns `202 Accepted`. |
| `GET` | `/api/submissions/:submissionId` | Retrieve execution status, score, and permitted result details. |

### Example submission request

```http
POST /api/submissions
Content-Type: application/json
Authorization: Bearer <candidate-token>

{
  "assessmentId": "a3c9f6d1-4f03-4cc4-8c8c-933010cfa750",
  "questionId": "d0a637b9-d135-4b3b-931d-dc6c76be9a9c",
  "language": "javascript",
  "sourceCode": "function twoSum(nums, target) { /* ... */ }"
}
```

## Security Principles

- Resolve the tenant from trusted authentication or mapped hostnames, never from a client-controlled tenant ID.
- Use RLS for `SELECT`, `INSERT`, `UPDATE`, and `DELETE` policies on every tenant-owned table.
- Run migrations with a privileged database role, while application connections use a restricted role.
- Treat every candidate program and compiler output as untrusted input.
- Enforce execution time, memory, process, file-size, and concurrency limits at the sandbox layer.
- Keep execution sandboxes off the application network and prevent access to internal services and credentials.
- Apply rate limits to authentication, invitation, and submission endpoints.

## Monetization Model

SkillSync is designed for usage-based billing per assessment campaign. A campaign can record the tenant, number of invited candidates, completed attempts, execution volume, and plan limits. This supports a straightforward commercial model:

- Charge for each published assessment campaign.
- Include a candidate or submission allowance in each campaign tier.
- Offer institution plans with monthly campaign and execution quotas.
- Meter overages for additional candidates or code executions.

## Future Enhancements

- SSO with SAML and OpenID Connect for institution administrators.
- Configurable scoring rubrics and AI-assisted reviewer summaries.
- Proctoring integrations, tab-switch signals, and audit trails.
- Plagiarism detection across candidate submissions.
- More languages and custom test-case management.
- Analytics dashboards for cohort performance, question difficulty, and time-to-complete.
- Webhooks and ATS integrations for recruiting workflows.
- Regional data residency and tenant-specific encryption keys.
- Subscription management, invoicing, and self-serve plan upgrades.

## License

Add the license that matches your distribution model before publishing this repository.
