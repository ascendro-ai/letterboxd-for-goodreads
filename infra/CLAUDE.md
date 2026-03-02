# Infrastructure — Scope & Instructions

## Ownership

Infrastructure config lives here. Modify as needed by any instance,
but coordinate if touching CI/CD pipelines.

## Contents

```
infra/
├── docker/
│   ├── Dockerfile.backend     # FastAPI production container
│   └── Dockerfile.pipeline    # Pipeline jobs container
├── railway/
│   ├── railway.toml           # Railway deployment config
│   └── cron.toml              # Cron job schedules
├── github/
│   └── workflows/
│       ├── backend-ci.yml     # Lint + test backend on PR
│       ├── ios-ci.yml         # Build + test iOS on PR
│       └── deploy.yml         # Deploy to Railway on merge to main
└── supabase/
    └── config.toml            # Supabase project config
```

## Railway Deployment

- Backend deploys from `backend/` directory on push to main
- Pipeline jobs run as Railway cron services
- Environment variables set in Railway dashboard (not committed)

## Cron Schedule

| Job | Schedule | Command |
|-----|----------|---------|
| Nightly sync | 3:00 AM UTC daily | `python -m sync.nightly_sync` |
| Taste match | 4:00 AM UTC daily | `python -m sync.taste_match_job` |
| Cover backfill | 5:00 AM UTC daily | `python -m cover_processing.fetch_covers --backfill` |
