# lab-ocp-rhv

## 0.prerequisites

-  Install Dependencies
```
yum install git python3 libvirt-daemon-driver-network libguestfs-tools screen
```
- **RHEL 7.6-7.9**

it's **important** that RHOCP4.2 only support RHEL 7.6-7.9, shown on
[system requirement of RHEL](https://docs.openshift.com/container-platform/4.2/machine_management/more-rhel-compute.html#rhel-compute-requirements_more-rhel-compute)

- SSH Private Key

If you do not have an SSH key that is configured for password-less authentication on your computer,run the following command:

`ssh-keygen -t rsa -b 4096 -N '' -f ~/.ssh/id_rsa`

The ssh key would be used on the following. Meanwhile you will download shellscript on next step, it also comprises this step. So feel free to **skip**.

- use either NetworkManager or Dnsmasq

This guide prefers to `NetworkManager`, so try to disable dnsmasq
```
systemctl disable dnsmasq
```
## 1. Installation

- download shell script
```bash
cd ~/
git clone https://github.com/rh-tam/lab-ocp-rhv.git
```

- export env
```
source ~/lab-ocp-rhv/0-env
```

## 2. Few things about download files and environment

- pull secret

This `pull secret` allows you to authenticate with the services that are provided by the included authorities, including Quay.io, which serves the container images for OpenShift Container Platform components. 

Here, we adopt UPI, `user-provisioned infrastructure` in ths guide.

https://cloud.redhat.com/openshift/install/metal/user-provisioned

- Download RHEL guest images

`https://access.redhat.com/downloads/content/69/ver=/rhel---7/7.8/x86_64/product-software`


- issue where VMs cannot contact the hypervisor or to external networks

it can be fixed by **firewalld masquerade**.

the script is in `5-firwall.sh`

- Start python's webserver, serving the `ocp4` directory 

This step is **critical**. you MUST go `ocp4` then start the web server otherwise you won't be success on VM creating.

you can use it by 
```
screen -S ${CLUSTER_NAME} -dm bash -c "python3 -m http.server ${WEB_PORT}"
```

also, you can create new terminal session, but remember that you should reclaim your env again and go `ocp4` directory

```bash
python3 -m http.server ${WEB_PORT}
```
## 3. Setup DNS

- execute setup and check DNS
```
bash ~/lab-ocp-rhv/1-setup-n-check-dns.sh
```

- **[check]**

Check DNS and Srv work properly

## 4. Download UPI
- source pull-secret-rhnuser

```
source ~/lab-ocp-rhv/2-pull-secret-rhnuser
```

- pull secret

go visiting

`https://cloud.redhat.com/openshift/install/metal/user-provisioned`

to copy your pull_secret

![image](https://user-images.githubusercontent.com/64194459/82781434-60828d00-9e8c-11ea-9331-718fc26919fe.png)

## 5. Rhcos prepare

- RHCOS bios image

the download process is in `3-rhcos-prepare.sh`

- RHEL guest image for KVM
go visiting
`https://access.redhat.com/downloads/content/69/ver=/rhel---7/7.8/x86_64/product-software`

and copy the link
![image](https://user-images.githubusercontent.com/64194459/82782161-3e8a0a00-9e8e-11ea-880c-f8689c1fc0f7.png)

the `3-rhcos-prepare.sh` will ask for the url

- kernel and initramfs and generate the treeinfo

let's go executing `3-rhcos-prepare.sh`

```
bash ~/lab-ocp-rhv/3-rhcos-prepare.sh
```

it will **take a while**, around 1 hr depending on your internet bandwidth.

## 6. Prepare Installion Directory for OpenShift Installer
- create directory and `install-config.yaml`

you can modify the parameters of `install-config.yaml` in `4-openshift-installer.sh`, then go executing

```bash
bash ~/lab-ocp-rhv/4-openshift-installer.sh
```

it will create `ignition files` as well

## 7. Served Web Server for Ignition and Images
 
- served Web Server

```
screen -S ${CLUSTER_NAME} -dm bash -c "python3 -m http.server ${WEB_PORT}"
```

or create other terminal session, then `source 0-env again`.
Also remember go `ocp4` directory

- check served web server

make sure that our current directory `ocp4` is being served by python. Also make sure that you can access the ignition (ing) and image (img) files. 

- **[check]**
make sure ing and img served properly

```
curl http://${HOST_IP}:${WEB_PORT}/install_dir/bootstrap.ign -o -
```

Also double check the URLs we are going to **pass to the RHCOS installer kernel in the next commands**. Make sure that those URLs are reachable from inside the VMs.

## 8. Firwall 
- config firewall policy

```bash
bash ~/lab-ocp-rhv/5-firewall.sh
```
## 9. Create the Red Hat CoreOS and Load Balancer VMs

Before going through following procedures, you should make sure you can access your ignition, ing, and image, img, files.

- spawn bootstrap, master (default 3), worker (default 2)

```bash
bash ~/lab-ocp-rhv/6-spawn.sh
```

- spawn lb

```bash
bash ~/lab-ocp-rhv/7-lb.sh
```

- **[check]**
```bash
watch "virsh list --all | grep '${CLUSTER_NAME}-'"
```

we adopt virt-install creating 7 VMs in default, if you don't change `install-config.yaml` and related shell script

  - 1 x bootstrap
  - 3 x master
  - 2 x worker
  - 1 x load balancer

you can observe that your web server start to be pulled images from distinct VMs

![image](https://user-images.githubusercontent.com/64194459/82748258-15f10a00-9dd3-11ea-817b-1188045f61ea.png)

Note that `Virt-install` should make all VMs `power-off` once it successfully finishes, and `Power-off` status appear very soon if your web-server configuration is correct. 

## 10. Setup DNS and Load balancing

- config dnsmasq and start all VMs
```bash
bash ~/lab-ocp-rhv/8-start-vm.sh
```

- add DHCP reservation
```bash
source ~/lab-ocp-rhv/9-dhcp
```


![image](https://user-images.githubusercontent.com/10542832/82340384-bdf88300-9a21-11ea-8f69-8dcebfcc5e3c.png)

- configure load balancing (haproxy)
```bash
bash ~/lab-ocp-rhv/10-haproxy.sh
```

- **[check]**
make sure haproxy is configured properly

```bash
bash ~/lab-ocp-rhv/11-check-haproxy.sh
```

![image](https://user-images.githubusercontent.com/64194459/82631733-ccfd5200-9c28-11ea-8fcc-639a72de3ff2.png)

## 11. BootStrap OpenShift 4

- start OpenShift installation (UPI)
```bash
bash ~/lab-ocp-rhv/12-bootstrap.sh
```
- **[check]**
```bash
ssh core@<bootstrap-node> journalctl -b -f -u bootkube.service
```
it will take a very long time to execute on this process. Please be patient.

After a while, you will see the following.
![image](https://user-images.githubusercontent.com/64194459/82792160-88302000-9ea1-11ea-91ea-b7b5d456db71.png)

## 11. Login OpenShift Cluster

- login with `kubeconfig`

```bash
export KUBECONFIG=install_dir/auth/kubeconfig
```

- check your nodes' status

```bash
./oc get nodes
```
![image](https://user-images.githubusercontent.com/64194459/82792396-eceb7a80-9ea1-11ea-836b-b422135578f3.png)

## 12. Remove Bootstrap

- **teardown** Web Server for Imgs and Igns

```bash
screen -S ${CLUSTER_NAME} -X quit
```
or `ctrl+c` with `python3 -m http.server ${WEB_PORT}`

- remove bootstrap
```bash
bash ~/lab-ocp-rhv/13-remove-bootstrap.sh
```
## 13. Registry Setup
- emptyDir
due to no RWX storage here, we will update the setting

```bash
./oc patch configs.imageregistry.operator.openshift.io cluster --type merge --patch '{"spec":{"storage":{"emptyDir":{}}}}'
```
- after registry updates, you have to make sure all operators ready.

```bash
watch "./oc get clusterversion; echo; ./oc get clusteroperators"
```
it might also take a few minutes to get the consequence you desire.

Optionally, `./oc get co` can substitute `./oc get clusteroperators`

- **[check]**
  - **BEFORE**
  ![image](https://user-images.githubusercontent.com/64194459/82793683-e6f69900-9ea3-11ea-8623-e309fe256c26.png)

  - **AFTER**; observe `AVAILABLE` and `PROGRESSING`
  ![image](https://user-images.githubusercontent.com/64194459/82794185-a77c7c80-9ea4-11ea-8b1a-c121d99be99d.png)

## 13. Finish Installation and Ready to Go

- finish the installation by running
```bash
./openshift-install --dir=install_dir wait-for install-complete
```

you will get the following info.

![image](https://user-images.githubusercontent.com/64194459/82794747-9122f080-9ea5-11ea-9843-94523dd43218.png)

It also means you are successful on installation of OCP

````
INFO Waiting up to 30m0s for the cluster at https://api.ocp42.local:6443 to initialize... 
INFO Waiting up to 10m0s for the openshift-console route to be created... 
INFO Install complete!                            
INFO To access the cluster as the system:admin user when using 'oc', run 'export KUBECONFIG=/root/ocp4/install_dir/auth/kubeconfig' 
INFO Access the OpenShift web-console here: https://console-openshift-console.apps.ocp42.local 
INFO Login to the console with user: kubeadmin, password: kusMw-jVhjz-qZc3b-IhqbZ 
````

- login passwd
you can now login with the above information

or

you can get kubeadmin password by:

```bash
KUBE_PASS=$(cat install_dir/auth/kubeadmin-password)
./oc login -u kubeadmin -p $KUBE_PASS
```
## Appendix
### I. Clean Up
```bash
for n in ocp42-lb ocp42-master-1 ocp42-master-2 ocp42-master-3 ocp42-worker-1 ocp42-worker-2 ocp42-bootstrap; do virsh shutdown $n; virsh destroy $n; virsh undefine $n --remove-all-storage; done
```

```bash
rm -r /var/lib/libvirt/images/*.qcow2
```

```bash
sed -i "/${CLUSTER_NAME}.${BASE_DOM}/d" /etc/hosts
```

### II. Debug
- FATAL waiting for Kubernetes API

try to login into master node
```bash
sudo -i
# and run crictl ps
crictl logs <container id of discover>
```

then re-run
```bash
bash ~/lab-ocp-rhv/12-bootstrap.sh
```