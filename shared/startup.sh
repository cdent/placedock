#!/bin/sh

set -e
set -a

OS_PLACEMENT_DATABASE__CONNECTION=${OS_PLACEMENT_DATABASE__CONNECTION:-sqlite:////cats.db}
OS_PLACEMENT_DATABASE__SYNC_ON_STARTUP=${OS_PLACEMENT_DATABASE__SYNC_ON_STARTUP:-False}
OS_API__AUTH_STRATEGY=${OS_API__AUTH_STRATEGY:?OS_API__AUTH_STRATEGY required}

# run the web server
/app/bin/uwsgi --ini /placement-uwsgi.ini
