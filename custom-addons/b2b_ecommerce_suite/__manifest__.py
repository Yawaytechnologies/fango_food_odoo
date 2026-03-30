{
    "name": "B2B Ecommerce Suite",
    "version": "17.0.1.0.0",
    "summary": "B2B ecommerce flow with admin-controlled signup and account approval",
    "category": "Website/eCommerce",
    "author": "Fango Food",
    "license": "LGPL-3",
    "depends": [
        "base",
        "contacts",
        "portal",
        "mail",
        "account",
        "website",
        "website_sale",
        "sale_management"
    ],
    "data": [
        "security/b2b_security.xml",
        "security/ir.model.access.csv",
        "data/sequence_data.xml",
        "views/b2b_signup_request_views.xml",
        "views/res_partner_views.xml",
        "views/website_b2b_templates.xml",
        "views/website_menu.xml",
        "views/menus.xml"
    ],
    "assets": {
        "web.assets_frontend": [
            "b2b_ecommerce_suite/static/src/scss/b2b_theme.scss"
        ]
    },
    "application": True,
    "installable": True
}
