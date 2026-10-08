# APP Dockerfile — expects app/ as build context.
# All COPY sources are relative to app/. With the repo root as context,
# `COPY index.html` and `COPY APP_CONTEXT_MARKER` fail (those files only exist in app/).
FROM busybox:1.36
COPY index.html APP_CONTEXT_MARKER /www/
COPY . /ctx
RUN find /ctx -maxdepth 2 | sort > /www/context.txt
EXPOSE 8080
CMD httpd -f -p ${PORT:-8080} -h /www
