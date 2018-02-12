FROM    alpine:edge
MAINTAINER Chris Dent <cdent@anticdent.org>

RUN apk add --no-cache python3 python3-dev py3-pip git gcc uwsgi-python3
# the following are not directly used by placement but are needed by
# "accidental" imports
RUN apk add --no-cache py3-netifaces py3-greenlet py-cryptography py3-libxml2 py3-lxml

# Work around git wanting to know
RUN git config --global user.email "cdent@anticdent.org" && \
    git config --global user.name "Chris Dent"

# Use a custom requirements file with minimal requirements.
ADD placement-requirements.txt /
RUN pip3 install -r placement-requirements.txt

# Do this all in one big piece otherwise the nova bits are out of date
RUN git clone --depth=2 https://git.openstack.org/openstack/nova && \
    cd nova && \
    git fetch https://git.openstack.org/openstack/nova refs/changes/49/540049/5 && git cherry-pick FETCH_HEAD &&\
    git fetch https://git.openstack.org/openstack/nova refs/changes/66/362766/61 && git cherry-pick FETCH_HEAD && \
    git fetch https://git.openstack.org/openstack/nova refs/changes/35/541435/3 && git cherry-pick FETCH_HEAD && \
    git fetch https://git.openstack.org/openstack/nova refs/changes/95/543495/1 && git cherry-pick FETCH_HEAD && \
    git fetch https://git.openstack.org/openstack/nova refs/changes/52/533752/6 && git cherry-pick FETCH_HEAD && \
    git fetch https://git.openstack.org/openstack/nova refs/changes/97/533797/9 && git cherry-pick FETCH_HEAD && \
    git fetch https://git.openstack.org/openstack/nova refs/changes/62/543262/2 && git cherry-pick FETCH_HEAD && \
    git fetch https://git.openstack.org/openstack/nova refs/changes/69/543469/1 && git cherry-pick FETCH_HEAD && \
    # get rid of a symlink which can lead to errors, see:
    # https://github.com/python/cpython/pull/4267
    find . -type l -exec rm {} \; && \
    pip3 install --no-deps .

# Mount nova config and uwsgi config
VOLUME /shared
ENTRYPOINT ["uwsgi", "--ini", "/shared/placement-uwsgi.ini"]
