#!/bin/bash


# The image resides on /var/lib/libvirt/images/${CLUSTER_NAME}-lb.qcow2 
# where you just downloaded
virt-customize -a /var/lib/libvirt/images/${CLUSTER_NAME}-lb.qcow2 \
  --uninstall cloud-init \
  --ssh-inject root:file:$SSH_KEY --selinux-relabel \
  --sm-credentials "${RHNUSER}:password:${RHNPASS}" \
  --sm-register --sm-attach auto --install haproxy

set -x
# spawn load balancer
virt-install --import --name ${CLUSTER_NAME}-lb \
  --disk /var/lib/libvirt/images/${CLUSTER_NAME}-lb.qcow2 --memory 1024 --cpu host --vcpus 1 \
  --network network=${VIR_NET} --noreboot --noautoconsole

set +x
  