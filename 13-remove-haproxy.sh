#!/bin/bash
set -x

# remove boostrap entries from LB
ssh lb.${CLUSTER_NAME}.${BASE_DOM} <<EOF
sed -i '/bootstrap\.${CLUSTER_NAME}\.${BASE_DOM}/d' /etc/haproxy/haproxy.cfg
systemctl restart haproxy
EOF

# delete the bootstrap VM
virsh destroy ${CLUSTER_NAME}-bootstrap
virsh undefine ${CLUSTER_NAME}-bootstrap --remove-all-storage


set +x