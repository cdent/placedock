import glob
import os
import sys

from migrate import exceptions
from migrate.versioning import api as versioning_api
from migrate.versioning.repository import Repository

from nova.api.openstack.placement import wsgi
from nova.api.openstack.placement import db_api
from nova import conf


# This needs to be updated to as new placement
# migrations are added.
PLACEMENT_MIGRATIONS = [
    '016_resource_providers.py',
    '026_add_resource_classes.py',
    '029_placement_aggregates.py',
    '041_resource_provider_traits.py',
    '043_placement_consumers.py',
    '044_placement_add_projects_users.py',
    '051_nested_resource_providers.py',
    '059_add_consumer_generation.py',
]


def _migration():
    # hack to the path of nova/db/sqlalchemy/migrate_repo/
    rel_path = os.path.join('..', 'db', 'sqlalchemy', 'api_migrations',
                            'migrate_repo')
    path = os.path.join(os.path.abspath(os.path.dirname(conf.__file__)),
                        rel_path)
    # only use those migrations which actually do something for placement
    migration_dir_glob = os.path.join(path, 'versions', '*.py')
    for migration in glob.iglob(migration_dir_glob):
        if os.path.basename(migration) not in PLACEMENT_MIGRATIONS:
            with open(migration, 'w') as stopper:
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
