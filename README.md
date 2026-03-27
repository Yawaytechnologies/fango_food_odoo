# fango_food_odoo

## Production PostgreSQL (Render)

This project is set to connect Odoo to Render PostgreSQL with SSL using environment variables.

### 1. Set database env values

A `.env` file is already created in this project with your Render database values:

- `DB_HOST`
- `DB_PORT`
- `DB_USER`
- `DB_PASSWORD`
- `DB_NAME`
- `DB_SSLMODE=require`

### 2. Start Odoo locally

```bash
docker compose up -d
```

Local URL:

- http://localhost:8069/web/login

## Deploy On Render

This repo now includes:

- `render.yaml`
- `Dockerfile`

Create a new Render Blueprint service from this repo and set these environment variables in Render:

- `HOST` = your Render PostgreSQL host
- `PORT` = `5432`
- `USER` = your PostgreSQL user
- `PASSWORD` = your PostgreSQL password
- `PGHOST` = same as `HOST`
- `PGPORT` = `5432`
- `PGUSER` = same as `USER`
- `PGPASSWORD` = same as `PASSWORD`
- `PGDATABASE` = your database name (`fango_food`)
- `PGSSLMODE` = `require`

## B2B Food Ecommerce Setup

After first login, install these apps:

- Website
- eCommerce
- Sales
- Invoicing
- Inventory

Then enable these for B2B workflow:

- Pricelists (customer-specific pricing)
- Customer portal accounts
- Quotation flow for bulk orders
- Payment terms by company customer