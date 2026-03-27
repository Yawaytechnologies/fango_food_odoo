FROM odoo:17

COPY ./odoo.conf /etc/odoo/odoo.conf
COPY ./addons /mnt/extra-addons
COPY ./custom-addons /mnt/custom-addons