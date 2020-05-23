#!/bin/bash

echo "local=/${CLUSTER_NAME}.${BASE_DOM}/" > ${DNS_DIR}/${CLUSTER_NAME}.conf

systemctl reload NetworkManager

for x in lb bootstrap master-1 master-2 master-3 worker-1 worker-2
do
  virsh start ${CLUSTER_NAME}-$x
done

