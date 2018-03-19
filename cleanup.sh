#!/bin/sh -x

eval `minikube docker-env`
kubectl delete hpa placement-deployment
kubectl delete service placement-deployment
kubectl delete deployment placement-deployment
docker rmi placedock:1.0 -f

