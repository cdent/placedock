# This is automatically run as a shell script because of the
# way startup is done in the Dockerfile.

DB_STRING=${DB_STRING:-sqlite:////cats.db}
DB_SYNC=${DB_SYNC:-True}

# Do substitutions in the template.
sed -e "s,{DB_CONNECTION},$DB_STRING," < /etc/nova/nova.conf.tmp > /etc/nova/nova.conf

# establish the database, only if we've been asked to do so.
[ "$DB_SYNC" = "True" ] && python3 /sync.py --config-file /etc/nova/nova.conf

# run the web server
/usr/sbin/uwsgi --ini /placement-uwsgi.ini
