import logging

from odoo import _, api, fields, models
from odoo.exceptions import UserError


_logger = logging.getLogger(__name__)


class B2BSignupRequest(models.Model):
    _name = "b2b.signup.request"
    _description = "B2B Signup Request"
    _inherit = ["mail.thread", "mail.activity.mixin"]
    _order = "create_date desc"

    name = fields.Char(
        string="Request Number",
        required=True,
        copy=False,
        readonly=True,
        default=lambda self: _("New"),
        tracking=True,
    )
    company_name = fields.Char(required=True, tracking=True)
    contact_name = fields.Char(required=True, tracking=True)
    email = fields.Char(required=True, tracking=True)
    phone = fields.Char(tracking=True)
    website = fields.Char()
    gst_vat = fields.Char(string="GST/VAT")
    street = fields.Char()
    street2 = fields.Char()
    city = fields.Char()
    zip = fields.Char()
    state_id = fields.Many2one("res.country.state", string="State")
    country_id = fields.Many2one("res.country", string="Country")
    business_type = fields.Selection(
        [
            ("distributor", "Distributor"),
            ("retailer", "Retailer"),
            ("wholesaler", "Wholesaler"),
            ("restaurant", "Restaurant"),
            ("other", "Other"),
        ],
        default="retailer",
        tracking=True,
    )
    monthly_order_value = fields.Float(string="Expected Monthly Order Value")
    pricelist_id = fields.Many2one("product.pricelist", string="Requested Pricelist")
    payment_term_id = fields.Many2one("account.payment.term", string="Payment Terms")
    user_note = fields.Text(string="Admin Note")
    notes = fields.Text()

    state = fields.Selection(
        [
            ("draft", "Draft"),
            ("submitted", "Submitted"),
            ("approved", "Approved"),
            ("rejected", "Rejected"),
        ],
        default="draft",
        tracking=True,
    )

    approved_by = fields.Many2one("res.users", readonly=True)
    approved_date = fields.Datetime(readonly=True)
    rejection_reason = fields.Text()

    partner_id = fields.Many2one("res.partner", string="Created Company", readonly=True)
    user_id = fields.Many2one("res.users", string="Created User", readonly=True)

    _sql_constraints = []

    @api.model_create_multi
    def create(self, vals_list):
        for vals in vals_list:
            if vals.get("name", _("New")) == _("New"):
                vals["name"] = self.env["ir.sequence"].next_by_code("b2b.signup.request") or _("New")
            if vals.get("state") == "draft":
                vals["state"] = "submitted"
        return super().create(vals_list)

    def action_submit(self):
        for rec in self:
            rec.state = "submitted"

    def action_approve(self):
        portal_group = self.env.ref("base.group_portal")
        for rec in self:
            if rec.state not in ("submitted", "draft"):
                continue

            email = (rec.email or "").strip().lower()
            if not email:
                raise UserError(_("Signup request is missing an email address."))

            existing_user = self.env["res.users"].search([("login", "=ilike", email)], limit=1)
            if existing_user:
                raise UserError(_("A user with this email already exists: %s") % email)

            existing_partner = self.env["res.partner"].search(
                [("email", "=ilike", email), ("company_type", "=", "company")],
                limit=1,
            )

            partner_values = {
                "name": rec.company_name,
                "company_type": "company",
                "customer_rank": 1,
                "street": rec.street,
                "street2": rec.street2,
                "city": rec.city,
                "zip": rec.zip,
                "state_id": rec.state_id.id,
                "country_id": rec.country_id.id,
                "vat": rec.gst_vat,
                "phone": rec.phone,
                "website": rec.website,
                "email": email,
                "x_is_b2b_company": True,
                "x_b2b_business_type": rec.business_type,
                "property_product_pricelist": rec.pricelist_id.id or False,
                "property_payment_term_id": rec.payment_term_id.id or False,
                "x_credit_limit": rec.monthly_order_value or 0.0,
            }
            partner = existing_partner or self.env["res.partner"].create(partner_values)
            if existing_partner:
                partner.write(
                    {
                        **partner_values,
                        "customer_rank": max(partner.customer_rank, 1),
                        "property_product_pricelist": rec.pricelist_id.id or partner.property_product_pricelist.id or False,
                        "property_payment_term_id": rec.payment_term_id.id or partner.property_payment_term_id.id or False,
                        "x_credit_limit": rec.monthly_order_value or partner.x_credit_limit,
                    }
                )

            contact_values = {
                "name": rec.contact_name,
                "type": "contact",
                "parent_id": partner.id,
                "customer_rank": 1,
                "email": email,
                "phone": rec.phone,
                "street": rec.street,
                "street2": rec.street2,
                "city": rec.city,
                "zip": rec.zip,
                "state_id": rec.state_id.id,
                "country_id": rec.country_id.id,
            }
            contact = self.env["res.partner"].search(
                [("parent_id", "=", partner.id), ("email", "=ilike", email)],
                limit=1,
            )
            if contact:
                contact.write(contact_values)
            else:
                contact = self.env["res.partner"].create(contact_values)

            user = self.env["res.users"].with_context(no_reset_password=True).create(
                {
                    "name": rec.contact_name,
                    "login": email,
                    "email": email,
                    "partner_id": contact.id,
                    "groups_id": [(6, 0, [portal_group.id])],
                    "x_is_b2b_user": True,
                    "x_b2b_signup_request_id": rec.id,
                }
            )

            reset_note = _("Portal user created.")
            try:
                user.action_reset_password()
                reset_note = _("Portal user created and password reset email sent.")
            except Exception as err:
                _logger.exception("Failed to send reset password email for B2B signup request %s", rec.id)
                reset_note = _(
                    "Portal user created, but password reset email could not be sent. Check outgoing mail server and web.base.url settings. Error: %s"
                ) % err

            rec.write(
                {
                    "state": "approved",
                    "approved_by": self.env.user.id,
                    "approved_date": fields.Datetime.now(),
                    "partner_id": partner.id,
                    "user_id": user.id,
                    "user_note": reset_note,
                }
            )

    def action_reject(self):
        for rec in self:
            if rec.state in ("approved", "rejected"):
                continue
            rec.write(
                {
                    "state": "rejected",
                    "approved_by": self.env.user.id,
                    "approved_date": fields.Datetime.now(),
                }
            )

    def action_reset_to_draft(self):
        self.write({"state": "draft", "rejection_reason": False, "user_note": False})
