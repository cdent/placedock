FROM    alpine:edge
MAINTAINER Chris Dent <cdent@anticdent.org>

RUN apk add --no-cache python3 python3-dev py3-pip git gcc uwsgi-python3 py3-psycopg2
# the following are not directly used by placement but are needed by
# "accidental" imports
# Used by:
# netifaces: oslo_utils
# greenlet: oslo_versionedobjects requires oslo.messaging requires oslo.service
RUN apk add --no-cache py3-netifaces py3-greenlet

# Work around git wanting to know
RUN git config --global user.email "cdent@anticdent.org" && \
    git config --global user.name "Chris Dent"

# Do this all in one big piece otherwise things get confused.
# Thanks to ingy for figuring out a faster way to do this.
# We must get rid of any symlinks which can lead to errors, see:
# https://github.com/python/cpython/pull/4267
RUN git clone --depth=1 https://git.openstack.org/openstack/placement && \
    cd placement && \
    # If any patches need to be merged in, list them in this section
    # below and uncomment it.
    git fetch --depth=2 --append origin \
        refs/changes/57/600157/2 && \
    git cherry-pick $(cut -f1 .git/FETCH_HEAD) && \
    find . -type l -exec rm {} \; && \
    pip3 install .


# add the placement.conf template
RUN mkdir /etc/placement
ADD /shared/etc/placement/placement.conf /etc/placement/placement.conf.tmp

# add the tools for creating the placement db
ADD sync.py /

# add in the uwsgi configuration
ADD /shared/placement-uwsgi.ini /

# copy in the startup script, which syncs the database and
# starts uwsgi.
ADD startup.sh /

CMD ["sh", "-c", "/startup.sh"]
EXPOSE 80
