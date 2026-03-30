# B2B Ecommerce Suite

## Full Concept Design

This addon provides a complete B2B ecommerce concept in Odoo with two sides:

- Admin Side (internal users): approve/reject companies, create B2B users, manage partner profile.
- User Side (website visitors/customers): request B2B account, wait for approval, sign in after activation.

## User-Side Flow (Signup/Signin)

1. Visitor opens `/b2b/register`.
2. Visitor fills business form (company, contact, email, type, expected order value, address).
3. Form creates `b2b.signup.request` in `submitted` state.
4. Visitor sees confirmation page: `/b2b/register/thank-you`.
5. After admin approval, system creates portal user and sends reset-password email.
6. User signs in through `/b2b/login` -> `/web/login`.

## Admin-Side Flow

1. Open `B2B Ecommerce > Signup Requests`.
2. Review request details in form view.
3. Click `Approve & Create Account`.
4. System creates:
   - Company partner record.
   - Contact partner record.
   - Portal user linked to contact.
5. System sends password setup email to user.
6. Admin can reject or reset to draft when needed.

## Data Model Summary

### `b2b.signup.request`
- Commercial request lifecycle and KYC-like business details.
- Main fields: company/contact/email, business type, expected monthly value, address, notes, state.
- State machine: `draft -> submitted -> approved/rejected`.

### `res.partner` extension
- `x_is_b2b_company`
- `x_b2b_business_type`
- `x_credit_limit`
- `x_payment_term_notes`

### `res.users` extension
- `x_is_b2b_user`
- `x_b2b_signup_request_id`

## Menus and Views

- Menu root: `B2B Ecommerce`.
- Submenu: `Signup Requests`.
- Views: tree, form, search with filters by state and business type.
- Partner form has additional `B2B Profile` tab.

## Security

- Group `B2B Manager` for admin operations.
- Access rights configured in `security/ir.model.access.csv`.

## Files Created

- `__manifest__.py`
- `models/` (request + partner + user extensions)
- `controllers/main.py`
- `views/` (backend + website templates + menus)
- `security/` (groups + ACL)
- `data/sequence_data.xml`

## Install

1. Update app list.
2. Install module: `B2B Ecommerce Suite`.
3. Assign `B2B Manager` group to internal admin users.
4. Open website pages:
   - `/b2b/register`
   - `/b2b/login`

## Recommended Next Extension

- Auto-assign customer pricelist and payment terms at approval.
- Add approval checklist fields and document uploads.
- Add automated SLA reminders for pending requests.
- Add separate roles: Procurement Manager, Buyer, Approver.
