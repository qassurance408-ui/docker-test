# ROOT Dockerfile — expects the repo root as build context.
FROM busybox:1.36
COPY . /ctx
RUN mkdir -p /www \
 && cp /ctx/root.html /www/index.html \
 && find /ctx -maxdepth 2 | sort > /www/context.txt
EXPOSE 8080
CMD httpd -f -p ${PORT:-8080} -h /www
