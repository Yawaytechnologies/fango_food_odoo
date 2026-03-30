# fango_food_odoo

## Production PostgreSQL (Render)

This project is set to connect Odoo to Render PostgreSQL with SSL using environment variables.
The startup path now locks Odoo to the `fango_food` database only and auto-installs the B2B module stack into that same database if it is missing.

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

The custom module is included in this repo at `custom-addons/b2b_ecommerce_suite` and is now loaded by the Render startup path through `/etc/odoo/odoo.conf`.
On startup, the service will bootstrap or install these apps directly into `fango_food` if they are missing:

- Website / eCommerce
- Sales
- Invoicing
- Inventory
- Payment
- B2B Ecommerce Suite

Then enable these for B2B workflow:

- Pricelists (customer-specific pricing)
- Customer portal accounts
- Quotation flow for bulk orders
- Payment terms by company customer
