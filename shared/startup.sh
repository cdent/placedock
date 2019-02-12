#!/bin/sh

set -e
set -a

OS_PLACEMENT_DATABASE__CONNECTION=${OS_PLACEMENT_DATABASE__CONNECTION:-sqlite:////cats.db}
DB_SYNC=${DB_SYNC:-False}
OS_API__AUTH_STRATEGY=${OS_API__AUTH_STRATEGY:?OS_API__AUTH_STRATEGY required}

# establish the database, only if we've been asked to do so.
[ "$DB_SYNC" = "True" ] && /app/bin/placement-manage db sync

# run the web server
/app/bin/uwsgi --ini /placement-uwsgi.ini
