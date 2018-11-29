#!/bin/sh -x

eval `minikube docker-env`
kubectl delete hpa placement-lba
kubectl delete service placement-deployment
kubectl delete deployment placement-deployment
docker rmi placetest -f

