FROM alpine:3.9

RUN apk update \
 && apk add py2-pip curl postgresql \
 && pip install --upgrade pip awscli \
 && curl -L --insecure https://github.com/odise/go-cron/releases/download/v0.0.6/go-cron-linux.gz | zcat > /usr/local/bin/go-cron \
 && chmod u+x /usr/local/bin/go-cron \
 && rm -rf /var/cache/apk/*

# see http://godoc.org/github.com/robfig/cron#hdr-Predefined_schedules
ENV SCHEDULE **None**

ENV PGHOST **None**
ENV PGUSER **None**
ENV PGPASSWORD **None**
ENV PGDATABASE **None**
ENV S3_PATH **None**
ENV AWS_ACCESS_KEY_ID ""
ENV AWS_SECRET_ACCESS_KEY ""
ENV AWS_DEFAULT_REGION "ap-northeast-1"
ENV DUMP_DIR "/dump"

ADD run.sh /app/run.sh
ADD backup.sh /app/backup.sh

WORKDIR /app

CMD ["/app/run.sh"]
