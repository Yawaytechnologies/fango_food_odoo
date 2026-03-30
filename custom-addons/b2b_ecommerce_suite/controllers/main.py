from odoo import http
from odoo.http import request


class B2BWebsiteController(http.Controller):

    def _normalize_email(self, email):
        return (email or "").strip().lower()

    def _safe_int(self, value):
        try:
            return int(value) if value else False
        except (TypeError, ValueError):
            return False

    def _safe_float(self, value):
        try:
            return float(value) if value else 0.0
        except (TypeError, ValueError):
            return 0.0

    @http.route(["/b2b"], type="http", auth="public", website=True, sitemap=True)
    def b2b_home_page(self, **kwargs):
        return request.render("b2b_ecommerce_suite.b2b_home_page", {})

    @http.route(["/about-us"], type="http", auth="public", website=True, sitemap=True)
    def about_us_page(self, **kwargs):
        return request.render("b2b_ecommerce_suite.about_us_page", {})

    @http.route(["/services"], type="http", auth="public", website=True, sitemap=True)
    def services_page(self, **kwargs):
        return request.render("b2b_ecommerce_suite.services_page", {})

    @http.route(["/legal"], type="http", auth="public", website=True, sitemap=True)
    def legal_page(self, **kwargs):
        return request.render("b2b_ecommerce_suite.legal_page", {})

    @http.route(["/b2b/register"], type="http", auth="public", website=True, sitemap=False)
    def b2b_register_page(self, **kwargs):
        countries = request.env["res.country"].sudo().search([])
        states = request.env["res.country.state"].sudo().search([])
        pricelists = request.env["product.pricelist"].sudo().search([("selectable", "=", True)])
        return request.render(
            "b2b_ecommerce_suite.b2b_register_page",
            {
                "countries": countries,
                "states": states,
                "pricelists": pricelists,
                "values": kwargs,
                "error": kwargs.get("error"),
            },
        )

    @http.route(["/b2b/register/submit"], type="http", auth="public", website=True, csrf=True, methods=["POST"])
    def b2b_register_submit(self, **post):
        post["email"] = self._normalize_email(post.get("email"))
        required_fields = ["company_name", "contact_name", "email"]
        missing = [field for field in required_fields if not post.get(field)]

        if missing:
            post["error"] = "Please fill all required fields."
            return self.b2b_register_page(**post)

        existing = request.env["b2b.signup.request"].sudo().search(
            [
                ("email", "=ilike", post.get("email")),
                ("state", "in", ["submitted", "approved"]),
            ],
            limit=1,
        )
        if existing:
            post["error"] = "A request for this email already exists. Please contact support."
            return self.b2b_register_page(**post)

        request.env["b2b.signup.request"].sudo().create(
            {
                "company_name": post.get("company_name"),
                "contact_name": post.get("contact_name"),
                "email": post.get("email"),
                "phone": post.get("phone"),
                "website": post.get("website"),
                "gst_vat": post.get("gst_vat"),
                "street": post.get("street"),
                "street2": post.get("street2"),
                "city": post.get("city"),
                "zip": post.get("zip"),
                "state_id": self._safe_int(post.get("state_id")),
                "country_id": self._safe_int(post.get("country_id")),
                "business_type": post.get("business_type") or "retailer",
                "monthly_order_value": self._safe_float(post.get("monthly_order_value")),
                "pricelist_id": self._safe_int(post.get("pricelist_id")),
                "notes": post.get("notes"),
                "state": "submitted",
            }
        )

        return request.redirect("/b2b/register/thank-you")

    @http.route(["/b2b/register/thank-you"], type="http", auth="public", website=True, sitemap=False)
    def b2b_register_thank_you(self, **kwargs):
        return request.render("b2b_ecommerce_suite.b2b_register_thank_you", {})

    @http.route(["/b2b/login"], type="http", auth="public", website=True, sitemap=False)
    def b2b_login_page(self, **kwargs):
        values = dict(kwargs)
        values.setdefault("login", kwargs.get("login", ""))
        values.setdefault("redirect", kwargs.get("redirect", "/my"))
        values["error"] = kwargs.get("error") or (kwargs.get("login_success") == "false" and "Invalid email or password.")
        return request.render("b2b_ecommerce_suite.b2b_login_page", {"values": values})
