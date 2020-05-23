#!/bin/bash

set -x
# bootstrap node
virt-install --name ${CLUSTER_NAME}-bootstrap \
  --disk size=50 --ram 16000 --cpu host --vcpus 4 \
  --os-type linux --os-variant rhel7.0 \
  --network network=${VIR_NET} --noreboot --noautoconsole \
  --location rhcos-install/ \
  --extra-args "nomodeset rd.neednet=1 coreos.inst=yes coreos.inst.install_dev=vda coreos.inst.image_url=http://${HOST_IP}:${WEB_PORT}/rhcos-4.2.0-x86_64-metal-bios.raw.gz coreos.inst.ignition_url=http://${HOST_IP}:${WEB_PORT}/install_dir/bootstrap.ign"

# 3 master nodes
for i in {1..3}
do
virt-install --name ${CLUSTER_NAME}-master-${i} \
--disk size=50 --ram 16000 --cpu host --vcpus 4 \
--os-type linux --os-variant rhel7.0 \
--network network=${VIR_NET} --noreboot --noautoconsole \
--location rhcos-install/ \
--extra-args "nomodeset rd.neednet=1 coreos.inst=yes coreos.inst.install_dev=vda coreos.inst.image_url=http://${HOST_IP}:${WEB_PORT}/rhcos-4.2.0-x86_64-metal-bios.raw.gz coreos.inst.ignition_url=http://${HOST_IP}:${WEB_PORT}/install_dir/master.ign"
done

# 2 worker nodes
for i in {1..2}
do
  virt-install --name ${CLUSTER_NAME}-worker-${i} \
  --disk size=50 --ram 8192 --cpu host --vcpus 4 \
  --os-type linux --os-variant rhel7.0 \
  --network network=${VIR_NET} --noreboot --noautoconsole \
  --location rhcos-install/ \
  --extra-args "nomodeset rd.neednet=1 coreos.inst=yes coreos.inst.install_dev=vda coreos.inst.image_url=http://${HOST_IP}:${WEB_PORT}/rhcos-4.2.0-x86_64-metal-bios.raw.gz coreos.inst.ignition_url=http://${HOST_IP}:${WEB_PORT}/install_dir/worker.ign"
done

set +x

