# This is automatically run as a shell script because of the
# way startup is done in the Dockerfile.

set -e

DB_STRING=${DB_STRING:-sqlite:////cats.db}
DB_SYNC=${DB_SYNC:-False}
AUTH_STRATEGY=${AUTH_STRATEGY:?AUTH_STRATEGY required}
AUTH_PASSWORD=${AUTH_PASSWORD:-""}
AUTH_USERNAME=${AUTH_USERNAME:-""}
AUTH_URL=${AUTH_URL:-""}
MEMCACHED_SERVERS=${MEMCACHED_SERVERS:-""}

# Do substitutions in the template. There are much better ways
# to do this.
sed -e "s,{DB_STRING},$DB_STRING," \
    -e "s,{AUTH_STRATEGY},$AUTH_STRATEGY," \
    -e "s,{MEMCACHED_SERVERS},$MEMCACHED_SERVERS," \
    -e "s,{AUTH_PASSWORD},$AUTH_PASSWORD," \
    -e "s,{AUTH_USERNAME},$AUTH_USERNAME," \
    -e "s,{AUTH_URL},$AUTH_URL," \
    < /etc/nova/nova.conf.tmp > /etc/nova/nova.conf

# establish the database, only if we've been asked to do so.
[ "$DB_SYNC" = "True" ] && python3 /sync.py --config-file /etc/nova/nova.conf

# run the web server
/usr/sbin/uwsgi --ini /placement-uwsgi.ini
