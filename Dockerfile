FROM    alpine:edge
MAINTAINER Chris Dent <cdent@anticdent.org>

RUN apk add --no-cache python3 python3-dev py3-pip git gcc uwsgi-python3
# the following are not directly used by placement but are needed by
# "accidental" imports
# Used by:
# netifaces: oslo_utils
# greenlet: oslo_service (which is really only used for managing debug options)
# cryptopgraphy: castellan, coming in via nova.conf
RUN apk add --no-cache py3-netifaces py3-greenlet py-cryptography

# Work around git wanting to know
RUN git config --global user.email "cdent@anticdent.org" && \
    git config --global user.name "Chris Dent"

# Use a custom requirements file with minimal requirements.
ADD placement-requirements.txt /
RUN pip3 install -r placement-requirements.txt

# Do this all in one big piece otherwise the nova bits are out of date
RUN git clone --depth=1 https://git.openstack.org/openstack/nova && \
    cd nova && \
    # This seems redundant and weird. Probably a better way?
    git fetch origin refs/changes/49/540049/6 && git cherry-pick FETCH_HEAD &&\
    git fetch origin refs/changes/66/362766/62 && git cherry-pick FETCH_HEAD && \
    git fetch origin refs/changes/35/541435/4 && git cherry-pick FETCH_HEAD && \
    git fetch origin refs/changes/95/543495/2 && git cherry-pick FETCH_HEAD && \
    git fetch origin refs/changes/52/533752/6 && git cherry-pick FETCH_HEAD && \
    git fetch origin refs/changes/97/533797/9 && git cherry-pick FETCH_HEAD && \
    git fetch origin refs/changes/62/543262/2 && git cherry-pick FETCH_HEAD && \
    git fetch origin refs/changes/69/543469/1 && git cherry-pick FETCH_HEAD && \
    # get rid of a symlink which can lead to errors, see:
    # https://github.com/python/cpython/pull/4267
    find . -type l -exec rm {} \; && \
    pip3 install --no-deps .

# Mount nova config and uwsgi config
VOLUME /shared
ENTRYPOINT ["uwsgi", "--ini", "/shared/placement-uwsgi.ini"]
