FROM python:3-alpine as build-env
MAINTAINER Chris Dent <cdent@anticdent.org>

RUN apk add --no-cache git gcc musl-dev linux-headers postgresql-dev pcre-dev

RUN python -m venv /app

# Train is 2.x
RUN /app/bin/pip --no-cache-dir install 'openstack-placement==2.*'
RUN /app/bin/pip --no-cache-dir install uwsgi werkzeug
# Mysql (or psycopg2) and memcached needed in "production" settings.
RUN /app/bin/pip --no-cache-dir install pymysql psycopg2 python-memcached


FROM python:3-alpine
COPY --from=build-env /app /app

# pcre and psql shared libs required
RUN apk add --no-cache pcre libpq

# add in the uwsgi configuration
ADD /shared/placement-uwsgi.ini /

# copy in the startup script, which syncs the database and
# starts uwsgi.
ADD /shared/startup.sh /

ENTRYPOINT ["/startup.sh"]
EXPOSE 80
