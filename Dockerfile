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
# Thanks to ingy for figuring out a faster way to do this.
RUN git clone --depth=1 https://git.openstack.org/openstack/nova && \
    cd nova && \
    git fetch --depth=2 --append origin \
        refs/changes/49/540049/15 \
        refs/changes/28/551528/4 \
        refs/changes/29/551529/4 \
        refs/changes/66/362766/71 \
        refs/changes/35/541435/13 \
        refs/changes/62/549862/7 \
        refs/changes/62/543262/5 && \
    git cherry-pick $(cut -f1 .git/FETCH_HEAD) && \
    # get rid of a symlink which can lead to errors, see:
    # https://github.com/python/cpython/pull/4267
    find . -type l -exec rm {} \; && \
    pip3 install --no-deps .

# Mount nova config and uwsgi config
VOLUME /shared
ENTRYPOINT ["uwsgi", "--ini", "/shared/placement-uwsgi.ini"]
