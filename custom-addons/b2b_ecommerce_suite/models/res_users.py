from odoo import fields, models


class ResUsers(models.Model):
    _inherit = "res.users"

    x_is_b2b_user = fields.Boolean(string="B2B User", copy=False)
    x_b2b_signup_request_id = fields.Many2one("b2b.signup.request", string="Signup Request")
