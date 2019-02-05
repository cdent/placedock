
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
* Running in kubernetes with a horizontal pod autoscaler, via a
  helm-chart (included here).

**Warning:** At this time the `Dockerfile` builds from master. This
configuration is not regularly tested for production use, but is
pretty standard. If you want to give it a go and it works for you,
great, please let me know.

The work that created this is documented in a series of blog
posts called "Placement Container Playground", parts
[1](https://anticdent.org/placement-container-playground-1.html),
[2](https://anticdent.org/placement-container-playground-2.html),
[3](https://anticdent.org/placement-container-playground-3.html),
[4](https://anticdent.org/placement-container-playground-4.html),
[5](https://anticdent.org/placement-container-playground-5.html),
[6](https://anticdent.org/placement-container-playground-6.html),
[7](https://anticdent.org/placement-container-playground-7.html),
and
[8](https://anticdent.org/placement-container-playground-8.html),

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
* `shared/startup.sh`: A script that runs when the container starts to
  manage some configuration defaults, optionally sync the database,
  and start the uwsgi server. Copied into the container.

With a checkout out of the repo it is possible to do just this to get a
container running it's own database (depending on your environment you
may need sudo):

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
         "min_version" : "1.0",
         "id" : "v1.0",
         "status" : "CURRENT",
         "max_version" : "1.30",
         "links" : [
            {
               "href" : "",
               "rel" : "self"
            }
         ]
      }
   ]
}
```

This is a container running placement using its own sqlite
database. When the container is terminated, the data goes.

# The Environment

There are several environment variables that can be used when
running the container (either via `-e` or `--env-file` on a `docker
run` or however you happen to be establishing a pod in kubernetes.
Some of the variables are specific to this methods, the rest (those
starting with `OS_`) correspond to the placement configuration
settings, all of which may be managed from the environment (removing
the need for a config file).

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

You can also run placement in Kubernetes. A helm chart is included
in this repository that will do everything for you. You first need
a working kubernetes cluster and to [install
helm](https://docs.helm.sh/using_helm/#quickstart).

Once that is done, inspect `placement-chart/values.yaml` to
understand the options. Using the defaults given there a single
replica of the the placement service will be created, using an
internal-to-container database, and the noauth2 strategy. This is
useful to see it working.

Changing `replicaCount` to 0 will install a [Horizontal Pod
Autoscaler](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)
into the cluster. This will not work unless a [metrics
server](https://github.com/kubernetes-incubator/metrics-server/tree/master/deploy)
is installed in the cluster. On docker for mac a
[workaround](https://stackoverflow.com/a/54106726) is required.

Setting `ingress.enabled` to `true` will add placement to an ingress
service if one exists. If you need one [see the
instructions](https://kubernetes.github.io/ingress-nginx/deploy/).

To deploy the chart using the defaults do something like (feel free
to choose a name you like):

```
helm install ./placement-chart --name=placement
```

If you want to install with the auto scaler and the ingress server
turned on you can either edit values.yaml or set values from the
command line:

```
helm install --set ingress.enabled=true \
             --set replicaCount=0 \
             ./placement-chart
```

The ingress server will be set up to dispatch based on an http host
of `placement.local`. If you add an entry to `/etc/hosts` with that
name and the ingress IP, you'll be able to reach placement with
queries like:

```
curl -H 'x-auth-token: admin' http://placement.local/resource_providers
```

You can also do a quick test using
[gabbi](https://pypi.org/p/gabbi):

```
gabbi-run http://placement.local -- gabbi.yaml
```

To exercise the auto scaler, it is important to understand the
`resources` section of `values.yaml` and the `spec` section of
`autoscaler.yaml`. As written they say:

* start with one replica that is allowed to use 1/4 of a CPU
* if utilization goes over 50% (that is 1/8th of a CPU) consider
  creating another replica, up to 10.

These numbers were chosen because they allow me to see the
autoscaling in action without requiring too much work.

[Placement Container Playground
5](https://anticdent.org/placement-container-playground-5.html)
describes using `watch kubectl get hpa` to see resources and
replicas change and `ab` to cause some load. Since then a tool
called [placeload](https://pypi.org/p/placeload) has been created
which can also exercise a placement service.

When you are done experimenting, helm allows you to clear away
the placement service:

```
helm ls  # list the installed charts to get the name
helm delete --purge <the name>
```
