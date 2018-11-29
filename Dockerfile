FROM    alpine
MAINTAINER Chris Dent <cdent@anticdent.org>

RUN apk add --no-cache python3 python3-dev py3-pip git gcc uwsgi-python3 py3-psycopg2 py3-cffi
# The following are required by pymsql, installed below, because alpine is
# currently testing their py3 version of the package.
RUN apk add --no-cache musl-dev libffi-dev openssl-dev
# the following are not directly used by placement but are needed by
# "accidental" imports
# Used by:
# netifaces: oslo_utils
# greenlet: oslo_versionedobjects requires oslo.messaging requires oslo.service
RUN apk add --no-cache py3-netifaces py3-greenlet

# We need recent pip for requirements files to be read well.
RUN pip3 install -U pip
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
    pip3 install .
# oslo.config 6.7.0 provides the "from the environment" support
RUN pip3 install 'oslo.config>=6.7.0' pymysql python-memcached

# add in the uwsgi configuration
ADD /shared/placement-uwsgi.ini /

# copy in the startup script, which syncs the database and
# starts uwsgi.
ADD startup.sh /

ENTRYPOINT ["/startup.sh"]
EXPOSE 80
