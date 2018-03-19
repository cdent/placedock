import os
import sys

from migrate import exceptions
from migrate.versioning import api as versioning_api
from migrate.versioning.repository import Repository

from nova.api.openstack.placement import wsgi
from nova.api.openstack.placement import db_api
from nova import conf


def _migration():
    # hack to the path of nova/db/sqlalchemy/migrate_repo/
    rel_path = os.path.join('..', 'db', 'sqlalchemy', 'api_migrations',
                            'migrate_repo')
    sys.stderr.write('rel_path %s\n' % rel_path)
    path = os.path.join(os.path.abspath(os.path.dirname(conf.__file__)),
                        rel_path)
    sys.stderr.write('path %s\n' % path)
    # adjust the keypairs migration otherwise the entire world
    # gets imported because it imports nova.objects.keypair for a single
    # string constant and that result in every object being imported.
    bad_file = os.path.join(path, 'versions', '014_keypairs.py')
    with open(bad_file, 'w') as stopper:
        stopper.write('def upgrade(x): pass\n')
    repository = Repository(path)
    placement_engine = db_api.get_placement_engine()
    try:
        versioning_api.version_control(placement_engine, repository, None)
        return versioning_api.upgrade(
            db_api.get_placement_engine(), repository, None)
    except exceptions.DatabaseAlreadyControlledError as exc:
        sys.stderr.write('database probably already synced: %s\n' % exc)


if __name__ == '__main__':
    wsgi._parse_args(sys.argv, default_config_files=[])
    db_api.configure(conf.CONF)
    _migration()
