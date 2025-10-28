FROM odoo:18

USER root

COPY oca/hr/requirements.txt /tmp/requirements/hr.txt
COPY oca/l10n-france/requirements.txt /tmp/requirements/l10n-france.txt

RUN pip3 install --no-cache-dir --break-system-packages \
    -r /tmp/requirements/hr.txt \
    -r /tmp/requirements/l10n-france.txt \
    && rm -rf /tmp/requirements

USER odoo
