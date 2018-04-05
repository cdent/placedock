#!/bin/sh -ex

eval `minikube docker-env`
docker build -t placedock:1.0 .
# create the metrics service. create seems to be required
# here, not yet sure why, so we || true to avoid errors
# when we start again.
kubectl create -f metrics-apiservice.yaml || true
kubectl create -f metrics-server-deployment.yaml || true
kubectl create -f metrics-server-service.yaml || true
kubectl apply -f deployment.yaml
kubectl apply -f autoscaler.yaml
kubectl expose deployment placement-deployment --type=LoadBalancer
PLACEMENT=`minikube service placement-deployment --url`

curl -H 'x-auth-token: admin' $PLACEMENT 
echo

type gabbi-run && gabbi-run -v all $PLACEMENT -- gabbi.yaml
