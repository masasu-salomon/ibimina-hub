# Ibimina Hub

> **Your savings group's notebook, in your pocket.** Transparent record-keeping for community savings groups in Rwanda.

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## African Context

Across Rwanda, millions of people save through **ibimina**: community savings groups
(also called *tontines*, *chamas* or ROSCAs elsewhere in Africa). Members pay a fixed
amount every week or month, and each cycle one member receives the whole pot in turn.

Many groups still keep records in a paper notebook held by the treasurer. This can
cause disputes, lost records, slow meetings and difficulty proving savings history to
a SACCO or microfinance institution. Ibimina Hub provides a shared record of members,
contributions, balances and payouts while supporting Rwandan MTN and Airtel numbers.

## Team Members

- **Masasu Salomon** - Team lead, project setup, groups feature, documentation, CI and board - `s.masasuuwi@alustudent.com`
- **Grevy Karuretwa** - Payout rotation and group summary features - `g.karuretwa@alustudent.com`
- **Phillip Mulindwa** - Member registration, phone validation, contributions and balances - `p.mulindwa@alustudent.com`

## Project Overview

Ibimina Hub is a modular Express API for savings groups. A group leader can create a
group, register members, record fixed contributions and see the current balance.

The API also calculates payout readiness, pays members in join-order rotation and
provides a summary for group meetings. The initial version uses an in-memory store
behind a small collection interface so that persistent storage can be introduced later.

### Target Users

- **Group treasurers and leaders** - register groups and members, record contributions
  and run payouts without manual arithmetic.
- **Group members** - check their contributions, the pot balance and their payout turn.
- **SACCOs and microfinance institutions** *(later)* - review a group's savings history
  when assessing a loan.

### Core Features

- **Savings groups**: Create groups with a fixed contribution amount and weekly or
  monthly frequency.
- **Member registration**: Register members with validated Rwandan MTN or Airtel
  mobile-money numbers; join order determines payout rotation.
- **Contributions and balances**: Record contributions and view total and per-member
  balances.
- **Payout rotation**: Check the next member, verify that the pot is ready and record
  payouts.
- **Group summary**: View members, contribution totals, payouts and pot balance in one
  meeting-friendly response.

## Technology Stack

- **Backend**: Node.js 18+ and Express 4
- **Frontend**: None; this version provides a REST API
- **Database**: In-memory store (`src/common/store.js`), designed for later PostgreSQL support
- **Testing**: Jest and Supertest
- **Linting**: ESLint 9
- **Other**: Docker, Docker Compose and GitHub Actions CI

## Getting Started

### Prerequisites

- [Node.js](https://nodejs.org/) 18 or newer and npm, to run without Docker
- [Docker](https://docs.docker.com/get-docker/) with Docker Compose v2.24 or newer, to run in a
  container (Docker Desktop includes both; check with `docker compose version`)

### Installation

1. Clone the repository:

   ```bash
   git clone https://github.com/masasu-salomon/ibimina-hub.git
   cd ibimina-hub
   ```

2. Install dependencies:

   ```bash
   npm install
   ```

3. Optionally copy the example configuration:

   ```bash
   cp .env.example .env
   ```

4. Run the application:

   ```bash
   npm start
   ```

   The API runs at `http://localhost:3000`.

### Usage

Check the health endpoint:

```bash
curl http://localhost:3000/health
```

Create a group:

```bash
curl -X POST http://localhost:3000/api/groups \
  -H "Content-Type: application/json" \
  -d '{"name":"Twiyubake Nyamirambo","contributionAmount":5000,"frequency":"weekly","location":"Kigali"}'
```

Run the linter and the test suite:

```bash
npm run lint
npm test
npm run test:coverage
```

## Running with Docker Compose

Docker Compose builds the image from the `Dockerfile` and starts the API. No local Node.js
install is needed.

1. Optionally create a `.env` file. Compose loads it when it exists and uses safe defaults
   when it does not:

   ```bash
   cp .env.example .env
   ```

2. Build and start the stack:

   ```bash
   docker compose up --build        # add -d to run in the background
   ```

3. Check that the container is healthy and the API responds:

   ```bash
   docker compose ps                # STATUS shows (healthy)
   curl http://localhost:3000/health
   ```

4. Follow the logs, or stop and remove the stack:

   ```bash
   docker compose logs -f api
   docker compose down
   ```

The stack has one `api` service on the `ibimina-network` network. It restarts unless
stopped, and a health check calls `/health` every 10 seconds. There is no database
container or volume yet, because data lives in memory and resets when the container
restarts. A PostgreSQL service and its volume can join the same network later.

To build and run the image without Compose:

```bash
docker build -t ibimina-hub .
docker run -p 3000:3000 ibimina-hub
```

### Environment Variables

| Variable | Default | Used by | Purpose |
|---|---|---|---|
| `PORT` | `3000` | App | Port the API listens on inside the container |
| `HOST_PORT` | `3000` | Compose | Port on your computer that forwards to the container |
| `NODE_ENV` | `production` in the image | App | Runtime mode |
| `CURRENCY` | `RWF` | App | Currency shown with amounts |

Set `HOST_PORT` in `.env` if port 3000 is already in use on your computer. Never commit
the real `.env` file.

## Continuous Integration

GitHub Actions runs [`.github/workflows/ci.yml`](.github/workflows/ci.yml) on every push
to a branch other than `main` and on every pull request targeting `main`. It:

1. checks out the code and sets up Node.js 20
2. installs dependencies with `npm ci`
3. runs ESLint (`npm run lint`)
4. runs the Jest tests with coverage
5. audits production dependencies for high-severity vulnerabilities
6. builds the Docker image and smoke-tests `/health` in a running container

Any failing step fails the run. Branch protection on `main` requires the `Test` and
`Docker build` checks to pass, plus one approving review, before a pull request can merge.

## Project Structure

```text
src/
├── app.js                 # Builds the Express app and mounts modules
├── server.js              # Starts the HTTP server
├── config/                # Environment-based configuration
├── common/                # Shared errors, validation and data store
└── modules/
    ├── health/            # Health endpoint
    ├── groups/            # Savings groups
    ├── members/           # Members and payout order
    ├── contributions/     # Contributions and balances
    ├── payouts/           # Payout rotation
    └── summary/           # Group overview
tests/                     # Jest and Supertest tests
```

The application is a modular monolith. Each business area has its own routes and
service layer, allowing a module to become a separate microservice later.

## API Reference

All request and response bodies are JSON. Amounts are whole numbers in RWF.

| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/health` | Service health check |
| `POST` | `/api/groups` | Create a group |
| `GET` | `/api/groups` | List groups |
| `GET` | `/api/groups/:groupId` | Get one group |
| `POST` | `/api/groups/:groupId/members` | Add a member |
| `GET` | `/api/groups/:groupId/members` | List members in payout order |
| `POST` | `/api/groups/:groupId/contributions` | Record a contribution |
| `GET` | `/api/groups/:groupId/contributions` | List contributions |
| `GET` | `/api/groups/:groupId/balance` | Total contributed and each member's total |
| `GET` | `/api/groups/:groupId/payouts/next` | See whose turn is next |
| `POST` | `/api/groups/:groupId/payouts` | Pay the next member |
| `GET` | `/api/groups/:groupId/payouts` | View payout history |
| `GET` | `/api/groups/:groupId/summary` | View the group overview |

## Links

- [Project Board](https://github.com/users/masasu-salomon/projects/1)
- [Team Participation Sheet](https://docs.google.com/spreadsheets/d/1hHUFW2yBKPwx3Qw9GdPJRy3R-AMYLjvlHlPbG7LdXVs/edit?gid=0#gid=0)
- [Repository Issues](https://github.com/masasu-salomon/ibimina-hub/issues)
- [CI workflow](.github/workflows/ci.yml)

## DevOps Practices

- Pull requests and at least one review are required before merging to `main`.
- Required CI checks include the Jest test suite and Docker build.
- Branches must be up to date and review conversations must be resolved.
- `.gitignore` excludes secrets, dependencies, build output, logs and IDE files.
- `.env.example` documents configuration without committing real secrets.
- `CODEOWNERS` routes module changes to responsible team members.

## License

[MIT License](LICENSE)
