# Ibimina Hub

> **Your savings group's notebook, in your pocket.** Transparent, tamper-resistant record-keeping for community savings groups in Rwanda.

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
· [Project board](https://github.com/users/masasu-salomon/projects/1)
· [Issues](https://github.com/masasu-salomon/ibimina-hub/issues)

---

## Problem statement

Across Rwanda, millions of people save through **ibimina**: community savings groups
(also called *tontines*, *chamas* or ROSCAs elsewhere in Africa). Members pay a fixed amount
every week or month, and each cycle one member receives the whole pot, in turn.

Most groups still keep their records in a paper notebook held by the treasurer. This causes
real problems:

- **Disputes**: members can't easily check who has paid, how much is in the pot or whose turn is next.
- **Lost or altered records**: one notebook, one person, no backup.
- **No financial history**: members have no record they can show a SACCO or MFI to qualify for a loan.
- **Slow meetings**: the treasurer spends a lot of each meeting counting and reconciling.

Mobile money (MTN MoMo, Airtel Money) is already used for contributions, but nothing ties those
payments to the group's rules. **Ibimina Hub** gives every group one shared, always-correct
record of members, contributions and payouts.

## Target users

| User | Need |
|---|---|
| **Group treasurer / leader** | Register the group and members, record contributions, run payouts without manual arithmetic |
| **Group member** | See what they've paid, the pot balance and when it's their turn |
| **SACCOs / microfinance institutions** *(later)* | Look at a group's savings history when assessing a loan |

## Core features

| # | Feature | Status | Owner |
|---|---|---|---|
| 1 | **Savings groups**: create a group with a fixed contribution amount and frequency (weekly / monthly) | ✅ Done | @masasu-salomon |
| 2 | **Member registration**: add members with a validated Rwandan mobile-money number (MTN / Airtel); join order sets the payout rotation | 🚧 In progress | @Phillip-mulindwa |
| 3 | **Contributions & balances**: record contributions and see the pot balance and each member's total | 🚧 In progress | @Phillip-mulindwa |
| 4 | **Payout rotation**: see whose turn is next and pay out the pot when enough money has been collected | 🚧 In progress | @grevy-k |
| 5 | **Group summary**: one view of members, totals and payout progress for meetings | 🚧 In progress | @grevy-k |

## Technology stack

| Layer | Choice | Why |
|---|---|---|
| Runtime | **Node.js 18+** | Lightweight, starts fast in containers |
| Framework | **Express 4** | Minimal REST framework the whole team knows |
| Storage | In-memory store (`src/common/store.js`) | Keeps the first version simple. It's behind a small interface so PostgreSQL can replace it later |
| Testing | **Jest** + **Supertest** | Unit and HTTP-level tests |
| Planned (F2+) | Docker, GitHub Actions CI, Terraform, cloud deployment | Written by the team, per the course policy |

## Architecture

The codebase is a **modular monolith**. Each business area is its own module with its own
routes, service (business logic) and data collection. Modules only talk to each other through
service functions, never through each other's data. This means any module can later be split
into a separate microservice (for example, a `payouts-service`) without a rewrite.

```
src/
├── app.js                 # Builds the Express app and mounts each module
├── server.js              # Starts the HTTP server
├── config/                # Environment-based configuration
├── common/                # Shared: errors, validation, data store
└── modules/
    ├── health/            # GET /health, for load balancers and orchestrators
    ├── groups/            # Savings groups
    ├── members/           # Members and payout order
    ├── contributions/     # Contributions and balances
    ├── payouts/           # Payout rotation
    └── summary/           # Group overview
tests/                     # Jest + Supertest tests, one file per module
```

```
          ┌──────────── API (Express) ────────────┐
client ──▶│ groups │ members │ contributions │ payouts │──▶ data store
          └─────────────────────────────────────────┘
               each box → a future microservice
```

## Getting started

### Prerequisites

- [Node.js](https://nodejs.org/) **18 or newer** (`node -v`)
- npm (comes with Node.js)

### Run locally

```bash
git clone https://github.com/masasu-salomon/ibimina-hub.git
cd ibimina-hub
cp .env.example .env      # optional: the defaults work without it
npm install
npm start                 # http://localhost:3000
```

For development with auto-reload, use `npm run dev`.

Check it's running:

```bash
curl http://localhost:3000/health
```

### Run the tests

```bash
npm test                  # all tests
npm run test:coverage     # with a coverage report
```

### Configuration

| Variable | Default | Description |
|---|---|---|
| `PORT` | `3000` | HTTP port |
| `NODE_ENV` | `development` | Environment name |
| `CURRENCY` | `RWF` | Currency label shown in responses |

## API reference

All request and response bodies are JSON. Amounts are whole numbers in RWF.
Errors look like `{ "error": "message", "details": ["..."] }`.

| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/health` | Service health check |
| `POST` | `/api/groups` | Create a group: `{ name, contributionAmount, frequency, location? }` |
| `GET` | `/api/groups` | List groups |
| `GET` | `/api/groups/:groupId` | Get one group |
| `POST` | `/api/groups/:groupId/members` | Add a member: `{ fullName, phone }` |
| `GET` | `/api/groups/:groupId/members` | List members in payout order |
| `POST` | `/api/groups/:groupId/contributions` | Record a contribution: `{ memberId, amount? }` |
| `GET` | `/api/groups/:groupId/contributions` | List contributions |
| `GET` | `/api/groups/:groupId/balance` | Pot balance and each member's total |
| `GET` | `/api/groups/:groupId/payouts/next` | Whose turn is next |
| `POST` | `/api/groups/:groupId/payouts` | Pay the next member |
| `GET` | `/api/groups/:groupId/payouts` | Payout history |
| `GET` | `/api/groups/:groupId/summary` | Group overview |

### Example

```bash
curl -X POST http://localhost:3000/api/groups \
  -H "Content-Type: application/json" \
  -d '{"name":"Twiyubake Nyamirambo","contributionAmount":5000,"frequency":"weekly","location":"Kigali"}'
```

## How we work (DevOps practices)

### Workflow

1. Pick an issue from the [project board](https://github.com/users/masasu-salomon/projects/1) and move it to **In Progress**.
2. Create a branch: `feature/<short-name>`, `fix/<short-name>` or `chore/<short-name>`.
3. Commit, push and open a **pull request** to `main`, linking the issue (`Closes #12`).
4. Another team member reviews and approves. Merge when all checks and conversations are resolved.
5. The issue moves to **Done**.

### Branch protection on `main`

Nobody, admins included, can push directly to `main`. Each rule is there for a reason:

| Rule | Why it matters |
|---|---|
| Require a pull request before merging | Every change is visible and discussed before it reaches the shared branch |
| Require 1 approval | A second person checks every change. This catches bugs and spreads knowledge across the team |
| Dismiss stale approvals on new commits | An approval only counts for the code that was actually reviewed |
| Require status checks to pass | Broken builds and failing tests can't be merged. CI checks will be added in Formative 2 |
| Require branches to be up to date | Code is tested against the latest `main`, which avoids "it worked on my branch" |
| Require conversation resolution | Review comments must be addressed, not ignored |
| Include administrators | The rules apply to everyone, so there are no shortcuts |

### Security from the start ("shift left")

- `.gitignore` excludes secrets (`.env`, keys, Terraform state), dependencies, build output, logs and IDE files.
- Configuration comes from environment variables. `.env.example` documents them without real values.
- Input is validated at the API boundary (amounts, phone numbers, enums).
- `CODEOWNERS` routes each module's changes to the person responsible for it.

## Team

| Member | GitHub | Role |
|---|---|---|
| Salomon Uwimana Masasu | [@masasu-salomon](https://github.com/masasu-salomon) | Team lead: repo setup, groups module, docs |
| Phillip Mulindwa | [@Phillip-mulindwa](https://github.com/Phillip-mulindwa) | Members and contributions modules |
| Grevy Karuretwa | [@grevy-k](https://github.com/grevy-k) | Payouts and group summary modules |

## License

[MIT](LICENSE)
