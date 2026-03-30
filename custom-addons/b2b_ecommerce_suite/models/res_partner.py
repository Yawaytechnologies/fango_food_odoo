from odoo import fields, models


class ResPartner(models.Model):
    _inherit = "res.partner"

    x_is_b2b_company = fields.Boolean(string="Is B2B Company", copy=False)
    x_b2b_business_type = fields.Selection(
        [
            ("distributor", "Distributor"),
            ("retailer", "Retailer"),
            ("wholesaler", "Wholesaler"),
            ("restaurant", "Restaurant"),
            ("other", "Other"),
        ],
        string="B2B Business Type",
    )
    x_credit_limit = fields.Float(string="Credit Limit")
    x_payment_term_notes = fields.Text(string="Payment Term Notes")
