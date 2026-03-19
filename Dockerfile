FROM alpine:3.20

RUN apk add --no-cache bash coreutils tar gzip tzdata

WORKDIR /app

COPY entrypoint.sh backup.sh retention.sh /app/

RUN chmod +x /app/entrypoint.sh /app/backup.sh /app/retention.sh

ENTRYPOINT ["/app/entrypoint.sh"]
