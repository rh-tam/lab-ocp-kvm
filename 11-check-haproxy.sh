#!/bin/bash

set -x

systemctl reload NetworkManager
systemctl restart libvirtd

ssh lb.${CLUSTER_NAME}.${BASE_DOM} systemctl status haproxy
ssh lb.${CLUSTER_NAME}.${BASE_DOM} netstat -nltupe | grep ':6443\|:22623\|:80\|:443'

set +x