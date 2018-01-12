FROM    alpine:edge
MAINTAINER Chris Dent <cdent@anticdent.org>

RUN apk add --no-cache python3 python3-dev py3-pip git gcc uwsgi-python3 libffi-dev
# paramiko (and others here) are part of nova/requirements.txt but placement
# so could tune away
# Wack! websockify requires numpy!
RUN apk add --no-cache py3-paramiko py3-greenlet py3-netifaces py3-libxml2 py3-lxml py3-numpy py3-psutil

# Work around git being a dick
RUN git config --global user.email "cdent@anticdent.org" && \
    git config --global user.name "Chris Dent"

# Do this all in one big piece otherwise the nova bits are out of date
RUN git clone --depth=2 https://git.openstack.org/openstack/nova && \
    cd nova && \
    git fetch https://git.openstack.org/openstack/nova refs/changes/66/362766/55 && \
    git cherry-pick FETCH_HEAD && \
    # get rid of a symlink which can lead to errors, see:
    # https://github.com/python/cpython/pull/4267
    find . -type l -exec rm {} \; && \
    pip3 install . && \
    pip3 install PyMySQL python-memcached

VOLUME /shared

ENTRYPOINT ["uwsgi", "--ini", "/shared/placement-uwsgi.ini"]
