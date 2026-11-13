# MiniWallet

A small end-to-end digital wallet built as a self-learning project: an iOS app, a REST API, an Oracle database, a simulated payment gateway, and production-style monitoring — all running locally with Docker.

> Lab project. Uses test card numbers and synthetic data only. Not for real payments.

## What it does

- Register and log in
- Add a card (tokenized — the wallet never stores the card number)
- Top up the wallet from a card
- Transfer balance to another user
- View balance and transaction history

## Architecture

```
iOS app ──HTTPS──▶ Nginx ──▶ Wallet API ──JDBC──▶ Oracle XE
                               │
                               └──HTTP (5 s timeout)──▶ Mock gateway

Prometheus + Grafana + Loki monitor the API and the gateway.
```

## Tech stack

| Layer | Technology |
| --- | --- |
| Mobile app | Swift, SwiftUI, Combine (MVVM) |
| API | Java 21, Spring Boot 3 |
| Database | Oracle XE 21c, Flyway migrations |
| Payment gateway (simulated) | Spring Boot service |
| Edge | Nginx with TLS and rate limits |
| Monitoring | Prometheus, Grafana, Loki |
| Packaging and CI | Docker Compose, GitHub Actions |

## Repository layout

```
miniwallet/
├── db/
│   ├── init/            # one-time database users script (V0)
│   ├── migrations/      # Flyway V1__..., V2__...
│   ├── seed/            # synthetic test data
│   └── queries/         # monitoring and reporting SQL
├── wallet-api/          # Spring Boot Wallet API
├── mock-gateway/        # Spring Boot mock card processor
├── ios-app/             # Xcode project (SwiftUI + Combine)
├── nginx/               # nginx.conf (certs are not committed)
├── monitoring/          # Prometheus config, alert rules, Grafana dashboards
├── tests/
│   ├── postman/         # API test collection
│   └── k6/              # load tests
├── docs/
│   └── runbooks/        # one runbook per production-support drill
└── .github/workflows/   # CI
```

## Getting started

> Filled in as the project grows. Planned first steps:

1. `cp .env.example .env` and fill in the values
2. Create a self-signed certificate in `nginx/certs`
3. `docker compose up -d --build`
4. Open Swagger UI at `https://localhost/swagger-ui.html`

## Roadmap

| Phase | Sprints | Focus |
| --- | --- | --- |
| Foundation | 1–2 | Schema, migrations, seed data, SQL reports |
| Core API | 3–5 | Auth, wallet, cards, history |
| Integration | 6–7 | Mock gateway, top-up and transfer flows |
| iOS app | 8–10 | All screens with SwiftUI and Combine |
| Operations | 11–12 | Docker, Nginx, monitoring, alerts, load tests, CI |
| Drills and portfolio | 13–14 | Failure drills, runbooks, demo |

## License

MIT
