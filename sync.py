import sys

from nova.api.openstack.placement import wsgi
from nova.api.openstack.placement import db_api
from nova.db import migration
from nova import conf


DATABASE = 'placement'


def _migration():
    return migration.db_sync(None, database=DATABASE)


if __name__ == '__main__':
    wsgi._parse_args(sys.argv, default_config_files=[])
    db_api.configure(conf.CONF)
    _migration()
