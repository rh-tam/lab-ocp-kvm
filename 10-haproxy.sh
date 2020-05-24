#!/bin/bash

set -x
ssh-keygen -R lb.${CLUSTER_NAME}.${BASE_DOM}
ssh-keygen -R $LBIP
ssh -o StrictHostKeyChecking=no lb.${CLUSTER_NAME}.${BASE_DOM} true

ssh lb.${CLUSTER_NAME}.${BASE_DOM} <<EOF

# Allow haproxy to listen on custom ports
semanage port -a -t http_port_t -p tcp 6443
semanage port -a -t http_port_t -p tcp 22623

echo '
global
  log 127.0.0.1 local2
  chroot /var/lib/haproxy
  pidfile /var/run/haproxy.pid
  maxconn 4000
  user haproxy
  group haproxy
  daemon
  stats socket /var/lib/haproxy/stats

defaults
  mode tcp
  log global
  option tcplog
  option dontlognull
  option redispatch
  retries 3
  timeout queue 1m
  timeout connect 10s
  timeout client 1m
  timeout server 1m
  timeout check 10s
  maxconn 3000
# 6443 points to control plan
frontend ${CLUSTER_NAME}-api *:6443
  default_backend master-api
backend master-api
  balance source
  server bootstrap bootstrap.${CLUSTER_NAME}.${BASE_DOM}:6443 check
  server master-1 master-1.${CLUSTER_NAME}.${BASE_DOM}:6443 check
  server master-2 master-2.${CLUSTER_NAME}.${BASE_DOM}:6443 check
  server master-3 master-3.${CLUSTER_NAME}.${BASE_DOM}:6443 check

# 22623 points to control plane
frontend ${CLUSTER_NAME}-mapi *:22623
  default_backend master-mapi
backend master-mapi
  balance source
  server bootstrap bootstrap.${CLUSTER_NAME}.${BASE_DOM}:22623 check
  server master-1 master-1.${CLUSTER_NAME}.${BASE_DOM}:22623 check
  server master-2 master-2.${CLUSTER_NAME}.${BASE_DOM}:22623 check
  server master-3 master-3.${CLUSTER_NAME}.${BASE_DOM}:22623 check

# 80 points to worker nodes
frontend ${CLUSTER_NAME}-http *:80
  default_backend ingress-http
backend ingress-http
  balance source
  server worker-1 worker-1.${CLUSTER_NAME}.${BASE_DOM}:80 check
  server worker-2 worker-2.${CLUSTER_NAME}.${BASE_DOM}:80 check

# 443 points to worker nodes
frontend ${CLUSTER_NAME}-https *:443
  default_backend infra-https
backend infra-https
  balance source
  server worker-1 worker-1.${CLUSTER_NAME}.${BASE_DOM}:443 check
  server worker-2 worker-2.${CLUSTER_NAME}.${BASE_DOM}:443 check
' > /etc/haproxy/haproxy.cfg

systemctl start haproxy
systemctl enable haproxy
EOF

set +x