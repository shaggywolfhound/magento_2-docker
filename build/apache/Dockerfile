FROM webdevops/apache-dev:alpine

ENV WEB_NO_CACHE_PATTERN="\.(css|js|gif|png|jpg|svg|json|xml)$"

RUN apk add 'apache2>=2.4.20' && \
apk add 'apache2-ctl>=2.4.20' && \
apk add 'apache2-utils>=2.4.20' && \
apk add 'apache2-proxy>=2.4.20' && \
apk add 'apache2-ssl>=2.4.20' --force --no-cache

COPY ./conf/ /opt/docker/

RUN set -x \
     \
    && docker-run-bootstrap \
    && docker-image-cleanup

EXPOSE 80 443
