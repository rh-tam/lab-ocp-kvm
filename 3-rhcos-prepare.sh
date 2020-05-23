#!/bin/bash

set -x
# Download the RHCOS Install kernel and initramfs and generate the treeinfo.
cd ~/ocp4
mkdir rhcos-install
wget https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/4.2/4.2.0/rhcos-4.2.0-x86_64-installer-kernel -O rhcos-install/vmlinuz
wget https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/4.2/4.2.0/rhcos-4.2.0-x86_64-installer-initramfs.img -O rhcos-install/initramfs.img

cat <<EOF > rhcos-install/.treeinfo
[general]
arch = x86_64
family = Red Hat CoreOS
platforms = x86_64
version = 4.2.0
[images-x86_64]
initrd = initramfs.img
kernel = vmlinuz
EOF


# Download the RHCOS bios image
wget https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/4.2/4.2.0/rhcos-4.2.0-x86_64-metal-bios.raw.gz

# Download the RHEL guest image for KVM. We will use this to setup an external load balancer using haproxy. Visit RHEL download page
echo "go to https://access.redhat.com/downloads/content/69/ver=/rhel---7/7.8/x86_64/product-software"
read -p ':' rhel_kvm_image_url
wget \"${rhel_kvm_image_url}\" -O /var/lib/libvirt/images/${CLUSTER_NAME}-lb.qcow2

# Download OpenShift client  & installer
wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/4.2.0/openshift-install-linux-4.2.0.tar.gz
wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/4.2.0/openshift-client-linux-4.2.0.tar.gz

tar xf openshift-client-linux-4.2.0.tar.gz
tar xf openshift-install-linux-4.2.0.tar.gz
rm -f README.md


set +x