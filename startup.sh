# This is automatically run as a shell script because of the
# way startup is done in the Dockerfile.

set -e

OS_PLACEMENT_DATABASE__CONNECTION=${OS_PLACEMENT_DATABASE__CONNECTION:-sqlite:////cats.db}
DB_SYNC=${DB_SYNC:-False}
DB_CLEAN=${DB_CLEAN:-False}
OS_API__AUTH_STRATEGY=${OS_API__AUTH_STRATEGY:?OS_API__AUTH_STRATEGY required}

# establish the database, only if we've been asked to do so.
[ "$DB_SYNC" = "True" ] && python3 /sync.py

# run the web server
/usr/sbin/uwsgi --ini /placement-uwsgi.ini
