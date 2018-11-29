
This repo provides a collection of tools for creating and running
the [OpenStack](https://openstack.org/)
[Placement](https://developer.openstack.org/api-ref/placement/)
service in one or more containers for experimental purposes. The
tools are set up to allow a variety of different usage scenarios
including:

* Running the container with docker to sit beside a running
  OpenStack installation, such as devstack, talking to an
  established remote database.
* Using a single sqlite3 database within the container to do
  _placement-only_ testing (to do things like model nested resource
  providers and complex queries thereof).
* Running in whatever fashion, but doing the work at startup to make
  sure that the target database has the proper tables.
* Running in kubernetes with a horizontal pod autoscaler.

**For Experimental Use Only.** At this time the `Dockerfile` builds
from master. This configuration is not regularly tested for
production use, but is pretty standard. If you want to give it a go
and it works for you, great, please let me know.

The work that created this is documented in a series of blog
posts called "Placement Container Playground", parts
[1](https://anticdent.org/placement-container-playground-1.html),
[2](https://anticdent.org/placement-container-playground-2.html),
[3](https://anticdent.org/placement-container-playground-3.html),
[4](https://anticdent.org/placement-container-playground-4.html),
[5](https://anticdent.org/placement-container-playground-5.html),
and a forthcoming
[6](https://anticdent.org/placement-container-playground-6.html).

If you take issue with anything here or have some suggestions or
have anything to say, please create an [issue](/cdent/placement/issues).

# The Basics

The core pieces of this puzzle are:

* `Dockerfile`: descrbing how the container is built.
* `placement-requirements.txt`: A pip requirements file that
  describes which Python modules to install when building the
  container.
* `shared/placement-uwsgi.ini`: a generic configuration for running
  the placement service under
  [uwsgi](https://uwsgi-docs.readthedocs.io/) using the `http`
  protocol, exposed over port 80. Copied into the container.
* `startup.sh`: A script that runs when the container starts to
  satisfy the templated vars in placement.conf, optionally sync the
  database, and start the uwsgi server. Copied into the container.

This perhaps sounds like a lot, but with a checkout out of the repo
it is possible to do just this to get a container running it's own
database (depending on your environment you may need sudo):

```
docker build -t placedock .
docker run -t -p 127.0.0.1:8081:80 \
    -e "DB_SYNC=True" \
    -e "OS_API__AUTH_STRATEGY=noauth2" \
    placedock
curl http://localhost:8081/ | json_pp
```

Results in:

```json
{
   "versions" : [
      {
         "max_version" : "1.30",
         "id" : "v1.0",
         "min_version" : "1.0"
      }
   ]
}
```

This is a container running placement using its own sqlite
database. When the container is terminated, the data goes.

# The Environment

There are several environment variables that can be used when
running the container (either via `-e` or `--env-file` on a `docker
run` or however you happen to be establishing a pod in kubernetes
(this repo uses a `deployment.yaml`).

* `OS_PLACEMENT_DATABASE__CONNECTION`: Database connection string.
  Defaults to `sqlite:////cats.db`, a database local to the container.
* `DB_SYNC`: If `True` then do database migrations. Defaults to
  `False.
* `OS_API__AUTH_STRATEGY`: Either `keystone` or `noauth2`. No default, if
  this is not set, the container will fail to start.

If the `OS_API__AUTH_STRATEGY` is `noauth2`, HTTP requests to placement must
include a header named `x-auth-token` with a value of `admin` in order to be
authentic.

If the `OS_API__AUTH_STRATEGY` is `keystone`, additional configuration
is needed so middleware knows how to talk to a keystone service. This
description uses the `password` auth type. If you are using something
different the options will be different.

* `OS_KEYSTONE_AUTHTOKEN__USERNAME`: The username
* `OS_KEYSTONE_AUTHTOKEN__PASSWORD`: and password for talking to keystone.
* `OS_KEYSTONE_AUTHTOKEN__WWW_AUTHENTICATE_URI`: The URL where keystone is,
  used in the `www-authenticate` header.
* `OS_KEYSTONE_AUTHTOKEN__MEMCACHED_SERVERS`: A `host:port` combo, or a
  comma-separated list thereof, of memcached servers. This is required or
  otherwise the keystone middleware really drags.
* `OS_KEYSTONE_AUTHTOKEN__AUTH_TYPE`: Set to `password` to use usernames and
  password with keystone.
* `OS_KEYSTONE_AUTHTOKEN__AUTH_URL`: The URL placement verifies tokens with,
  often the same as `www_authenticate_uri`.
* `OS_KEYSTONE_AUTHTOKEN__PROJECT_DOMAIN_NAME`
* `OS_KEYSTONE_AUTHTOKEN__PROJECT_NAME`
* `OS_KEYSTONE_AUTHTOKEN__USER_DOMAIN_NAME`
* `OS_KEYSTONE_AUTHTOKEN__USERNAME`
* `OS_KEYSTONE_AUTHTOKEN__PASSWORD`

When using keystone, HTTP requests to placement must include a header named
`x-auth-token` with a value of a valid keystone token that has the `admin`
role.

# Devstack

If you want to use this setup with devstack, build a devstack (with
nova and placement enabled, they are by default) and gather some
information from the built stack:

* Use the value of `[placement_database]/connection` in
  `/etc/placement/placement.conf` as `OS_PLACEMENT_DATABASE__CONNECTION`.
  You will probably need to change the IP address.
* Use the value of `ADMIN_PASSWORD` in `local.conf` as
  `OS_KEYSTONE_AUTHTOKEN__PASSWORD`.
* Use `placement` for `OS_KEYSTONE_AUTHTOKEN__USER`.
* The value for `OS_KEYSTONE_AUTHTOKEN__WWW_AUTHENTICATE_URI` is printed
  when `stack.sh` completes:
  "Keystone is serving at http://192.168.1.76/identity/"
* The value for `OS_KEYSTONE_AUTHTOKEN__MEMCACHED_SERVERS` and the several
  other settings can be extracted from the `[keystone_authtoken]` section of
  `/etc/placement/placement.conf`.

You can put these in a `--env-file` that might look like this:

```
OS_DEFAULT__DEBUG=True
OS_PLACEMENT_DATABASE__CONNECTION=mysql+pymysql://root:secret@192.168.1.76/placement?charset=utf8
OS_API__AUTH_STRATEGY=keystone
OS_KEYSTONE_AUTHTOKEN__WWW_AUTHENTICATE_URI=http://192.168.1.76/identity
OS_KEYSTONE_AUTHTOKEN__MEMCACHED_SERVERS=localhost:11211
OS_KEYSTONE_AUTHTOKEN__PROJECT_DOMAIN_NAME=Default
OS_KEYSTONE_AUTHTOKEN__PROJECT_NAME=service
OS_KEYSTONE_AUTHTOKEN__USER_DOMAIN_NAME=Default
OS_KEYSTONE_AUTHTOKEN__PASSWORD=secret
OS_KEYSTONE_AUTHTOKEN__USERNAME=placement
OS_KEYSTONE_AUTHTOKEN__AUTH_URL=http://192.168.1.76/identity
OS_KEYSTONE_AUTHTOKEN__AUTH_TYPE=password
```

Clearly a lot of this could be automated, but I haven't got there
yet.

Then change `/etc/apache2/sites-enabled/placement-api.conf` to
something like this:

```
<Proxy balancer://placement>
    # This placement is important
    BalancerMember http://127.0.0.1:8080/placement
</Proxy>
  
ProxyPass "/placement" balancer://placement
```

Build and run your container:

```
docker build -t placedock .
docker run -t -p 127.0.0.1:8080:80 \
    --env-file dockerenv placedock
```

And reload apache2 so it can get the new config.

Clues above should indicate how to have more containers to load
balance against. (Left as an exercise for the reader.)

# Kubernetes

You can also the placement container with Kubernetes. There's a
`bootstrap.sh` that will do everything for you if you follow some
prerequisites:

* Adjust `deployment.yaml` to set the `OS_PLACEMENT_DATBASE__CONNECTION`
  and set any of the environment variables described above. What's in there
  now is for doing placement explorations with no auth and with an external
  postgresql database that is automatically synced at container run
  time. If you want to run placement-in-kubernetes alongside the
  rest of OpenStack read the Devstack section (above) for details on
  what you need to set.
* Either be running
  [minikube](https://github.com/kubernetes/minikube) or comment out
  the minikube lines in `bootstrap.sh` and `cleanup.sh`.
* If you are using someone's already established cluster, read all
  the `*.yaml` files and the `boostrap.sh` closely to make sure you
  don't try to do something you can't. For example `boostrap.sh`
  will try to turn on a metrics service. This makes sense in
  minikube but not elsewhere.

Here's what `bootstrap.sh` does:

* builds the container (as above)
* creates a metrics apiservice (for use by the autoscaler)
* creates a placement-deployment via `deployment.yaml`
* watches over that deployment with an horizontal pod autoscaler
  defined in `autoscaler.yaml`
* exposes the deployment via a LoadBalancer
* figures out the exposed URL of the deployment
* does some curl and [gabbi](https://gabbi.readthedocs.org/) to make
  sure things are working

To exercise the auto scaler, it is important to understand the
`resources` section of `deployment.yaml` and the `spec` section of
`autoscaler.yaml`. As written they say:

* start with one replica that is allowed to use 1/4 of a CPU
* if utilization goes over 50% (that is 1/8th of a CPU) consider
  creating another replica, up to 10.

These numbers were chosen because they allow me to see the
autoscaling in action without requiring too much work.

[Placement Container Playground
5](https://anticdent.org/placement-container-playground-5.html)
describes using `watch kubectl get hpa` to see resources and
replicas change and `ab` to cause some load.

When you are done experimenting, `cleanup.sh` will clean things up a
bit, but be aware that depending on your environment docker and
minikube can leave around a lot of detritus.
