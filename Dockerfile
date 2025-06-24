ARG ODDO_VERSION

FROM odoo:$ODDO_VERSION

COPY --chmod=755 entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

CMD ["odoo"]