FROM python:3-alpine
MAINTAINER Chris Dent <cdent@anticdent.org>

RUN apk add --no-cache git gcc musl-dev linux-headers postgresql-dev

# Do this all in one big piece otherwise things get confused.
# Thanks to ingy for figuring out a faster way to do this.
# We must get rid of any symlinks which can lead to errors, see:
# https://github.com/python/cpython/pull/4267
RUN git clone --depth=1 https://git.openstack.org/openstack/placement && \
    cd placement && \
    # If any patches need to be merged in, list them in this section
    # below and uncomment it.
    # git fetch --depth=2 --append origin \
    #     refs/changes/57/600157/8 && \
    # git cherry-pick $(cut -f1 .git/FETCH_HEAD) && \
    find . -type l -exec rm {} \; && \
    pip --no-cache-dir install .
RUN pip --no-cache-dir install uwsgi
# Mysql (or psycopg2) and memcached needed in "production" settings.
RUN pip --no-cache-dir install pymysql psycopg2 python-memcached

# add in the uwsgi configuration
ADD /shared/placement-uwsgi.ini /

# Remove stuff we no longer need. We'd like to remove terminfo here, but
# it's required by the base image.
RUN apk del --purge git gcc linux-headers
# Remove the source, to save a (tiny) bit of space.
RUN rm -r /placement

# copy in the startup script, which syncs the database and
# starts uwsgi.
ADD startup.sh /

ENTRYPOINT ["/startup.sh"]
EXPOSE 80
