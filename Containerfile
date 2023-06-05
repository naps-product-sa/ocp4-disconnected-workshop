FROM quay.io/redhatgov/workshop-dashboard:latest

USER root

COPY ./workshop /tmp/src/workshop

RUN rm -rf /tmp/src/.git* && \
    chown -R 1001 /tmp/src && \
    chgrp -R 0 /tmp/src && \
    chmod -R g+w /tmp/src && \
    sed -i 's/10082/8080/g' /opt/workshop/gateway/routes/workshop.js /opt/workshop/renderer/static/js/workshop.js /opt/workshop/bin/start-renderer.sh

USER 1001

RUN /usr/libexec/s2i/assemble
EXPOSE 10080