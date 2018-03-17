#!/bin/sh -ex

eval `minikube docker-env`
kubectl delete service placement-deployment
kubectl delete deployment placement-deployment
docker rmi placedock:1.0 -f

