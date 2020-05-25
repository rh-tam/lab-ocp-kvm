# lab-ocp-rhv

## 0.prerequisites

### Install Dependencies
```
yum install git python3 libvirt-daemon-driver-network libguestfs-tools screen
```
### **RHEL 7.6-7.9**

it's **important** that RHOCP4.2 only support RHEL 7.6-7.9, shown on
[system requirement of RHEL](https://docs.openshift.com/container-platform/4.2/machine_management/more-rhel-compute.html#rhel-compute-requirements_more-rhel-compute)

### SSH Private Key

If you do not have an SSH key that is configured for password-less authentication on your computer,run the following command:

`ssh-keygen -t rsa -b 4096 -N '' -f ~/.ssh/id_rsa`

the ssh key would be used on the following. Also in the shell script you will download, it also comprises this step. So **skip** to next.

## 1. Installation

### Shell Script

- download shell script
```bash
cd ~/
git clone https://github.com/rh-tam/lab-ocp-rhv.git
```

- export env
```
source ~/lab-ocp-rhv/0-env
```

## 1. Download Files and Setup Environment
### Download images
`https://access.redhat.com/downloads/content/69/ver=/rhel---7/7.8/x86_64/product-software`

- systemctl disable dnsmasq
- issue where VMs cannot contact the hypervisor or to external networks
`fixed by firewalld masquerade`.


- Generate the ignition files

```bash
./openshift-install create ignition-configs --dir=./install_dir
```

- Start python's webserver, serving the `ocp4` directory 

This step is **critical**. you MUST go `ocp4` then start the web server otherwise you won't be success on VM creating.

```bash
python3 -m http.server ${WEB_PORT}
```

## 2. Create the Red Hat CoreOS and Load Balancer VMs

Before going through following procedures, you should make sure you can access your ignition, ing, and image, img, files.

```
curl http://${HOST_IP}:${WEB_PORT}/install_dir/bootstrap.ign -o -
```
### Precedure

#### Spawn masters and workers

```bash
# bash ~/lab-ocp-hrv/5-spawn.sh
```

#### Setup the RHEL guest image for the load balancer

The image resides on `/var/lib/libvirt/images/${CLUSTER_NAME}-lb.qcow2` where you just downloaded


### Check
we adopt virt-install creating 7 VMs

- bootstrap
- 3 master
- 2 worker
- load balancer

you can observe that your web server start to be pulled images from distinct VMs

![image](https://user-images.githubusercontent.com/64194459/82748258-15f10a00-9dd3-11ea-817b-1188045f61ea.png)

`Virt-install` should make all VMs `power-off` once it successfully finishes, and `Power-off` status appear very soon if your web-server configuration is correct. 

Note that you should go `ocp4` directory before starting web-server.

```bash
watch "virsh list --all | grep '${CLUSTER_NAME}-'"
```

![image](https://user-images.githubusercontent.com/10542832/82338472-8557aa00-9a1f-11ea-87c1-dd2619538a2d.png)


## 3. Setup DNS and Load Balancing
- tell dnsmasq to treat our cluster domain
```bash
echo "local=/${CLUSTER_NAME}.${BASE_DOM}/" > ${DNS_DIR}/${CLUSTER_NAME}.conf
```

```bash
systemctl reload NetworkManager
```

- light on all the VMs.
```bash
for x in lb bootstrap master-1 master-2 master-3 worker-1 worker-2
do
  virsh start ${CLUSTER_NAME}-$x
done
```

```bash
IP=$(virsh domifaddr "${CLUSTER_NAME}-bootstrap" | grep ipv4 | head -n1 | awk '{print $4}' | cut -d'/' -f1)
MAC=$(virsh domifaddr "${CLUSTER_NAME}-bootstrap" | grep ipv4 | head -n1 | awk '{print $2}')
virsh net-update ${VIR_NET} add-last ip-dhcp-host --xml "<host mac='$MAC' ip='$IP'/>" --live --config
echo "$IP bootstrap.${CLUSTER_NAME}.${BASE_DOM}" >> /etc/hosts
```
![image](https://user-images.githubusercontent.com/10542832/82339803-095e6180-9a21-11ea-9c97-f2160e1d8b7c.png)

- Find the IP and MAC address of the master VMs. Add DHCP reservation
```bash
for i in {1..3}
do
  IP=$(virsh domifaddr "${CLUSTER_NAME}-master-${i}" | grep ipv4 | head -n1 | awk '{print $4}' | cut -d'/' -f1)
  MAC=$(virsh domifaddr "${CLUSTER_NAME}-master-${i}" | grep ipv4 | head -n1 | awk '{print $2}')
  virsh net-update ${VIR_NET} add-last ip-dhcp-host --xml "<host mac='$MAC' ip='$IP'/>" --live --config
  echo "$IP master-${i}.${CLUSTER_NAME}.${BASE_DOM}" \
  "etcd-$((i-1)).${CLUSTER_NAME}.${BASE_DOM}" >> /etc/hosts
  echo "srv-host=_etcd-server-ssl._tcp.${CLUSTER_NAME}.${BASE_DOM},etcd-$((i-1)).${CLUSTER_NAME}.${BASE_DOM},2380,0,10" >> ${DNS_DIR}/${CLUSTER_NAME}.conf
done
```

![image](https://user-images.githubusercontent.com/10542832/82340205-88ec3080-9a21-11ea-85b7-fc0ec1765d92.png)

- Find the IP and MAC address of the worker VMs. Add DHCP reservation
```bash
for i in {1..2}
do
   IP=$(virsh domifaddr "${CLUSTER_NAME}-worker-${i}" | grep ipv4 | head -n1 | awk '{print $4}' | cut -d'/' -f1)
   MAC=$(virsh domifaddr "${CLUSTER_NAME}-worker-${i}" | grep ipv4 | head -n1 | awk '{print $2}')
   virsh net-update ${VIR_NET} add-last ip-dhcp-host --xml "<host mac='$MAC' ip='$IP'/>" --live --config
   echo "$IP worker-${i}.${CLUSTER_NAME}.${BASE_DOM}" >> /etc/hosts
done
```

![image](https://user-images.githubusercontent.com/10542832/82340384-bdf88300-9a21-11ea-8f69-8dcebfcc5e3c.png)

- Find the IP and MAC address of the load balancer VM. Add DHCP reservation
```bash
LBIP=$(virsh domifaddr "${CLUSTER_NAME}-lb" | grep ipv4 | head -n1 | awk '{print $4}' | cut -d'/' -f1)
MAC=$(virsh domifaddr "${CLUSTER_NAME}-lb" | grep ipv4 | head -n1 | awk '{print $2}')
virsh net-update ${VIR_NET} add-last ip-dhcp-host --xml "<host mac='$MAC' ip='$LBIP'/>" --live --config
echo "$LBIP lb.${CLUSTER_NAME}.${BASE_DOM}" \
"api.${CLUSTER_NAME}.${BASE_DOM}" \
"api-int.${CLUSTER_NAME}.${BASE_DOM}" >> /etc/hosts
```

- wild-card DNS and point it to the load balancer
``` bash
echo "address=/apps.${CLUSTER_NAME}.${BASE_DOM}/${LBIP}" >> ${DNS_DIR}/${CLUSTER_NAME}.conf
```


- reload NetworkManager and Libvirt for DNS entires
**make sure that this procedure is done before go configuring Haproxy**

```bash
systemctl reload NetworkManager
systemctl restart libvirtd
```

- configure Haproxy
```bash
ssh-keygen -R lb.${CLUSTER_NAME}.${BASE_DOM}
ssh-keygen -R $LBIP
ssh -o StrictHostKeyChecking=no lb.${CLUSTER_NAME}.${BASE_DOM} true
```

- RHEL 7
```bash
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
```

RHEL 8; notice that, OCP4.2 installation is not allowed on RHEL 8

```
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
frontend ${CLUSTER_NAME}-api 
  bind *:6443
  default_backend master-api
backend master-api
  balance source
  server bootstrap bootstrap.${CLUSTER_NAME}.${BASE_DOM}:6443 check
  server master-1 master-1.${CLUSTER_NAME}.${BASE_DOM}:6443 check
  server master-2 master-2.${CLUSTER_NAME}.${BASE_DOM}:6443 check
  server master-3 master-3.${CLUSTER_NAME}.${BASE_DOM}:6443 check

# 22623 points to control plane
frontend ${CLUSTER_NAME}-mapi 
  bind *:22623
  default_backend master-mapi
backend master-mapi
  balance source
  server bootstrap bootstrap.${CLUSTER_NAME}.${BASE_DOM}:22623 check
  server master-1 master-1.${CLUSTER_NAME}.${BASE_DOM}:22623 check
  server master-2 master-2.${CLUSTER_NAME}.${BASE_DOM}:22623 check
  server master-3 master-3.${CLUSTER_NAME}.${BASE_DOM}:22623 check

# 80 points to worker nodes
frontend ${CLUSTER_NAME}-http 
  bind *:80
  default_backend ingress-http
backend ingress-http
  balance source
  server worker-1 worker-1.${CLUSTER_NAME}.${BASE_DOM}:80 check
  server worker-2 worker-2.${CLUSTER_NAME}.${BASE_DOM}:80 check

# 443 points to worker nodes
frontend ${CLUSTER_NAME}-https 
  bind *:443
  default_backend infra-https
backend infra-https
  balance source
  server worker-1 worker-1.${CLUSTER_NAME}.${BASE_DOM}:443 check
  server worker-2 worker-2.${CLUSTER_NAME}.${BASE_DOM}:443 check
' > /etc/haproxy/haproxy.cfg

systemctl start haproxy
systemctl enable haproxy
EOF
```
- check & success
```bash
ssh lb.${CLUSTER_NAME}.${BASE_DOM} systemctl status haproxy
ssh lb.${CLUSTER_NAME}.${BASE_DOM} netstat -nltupe | grep ':6443\|:22623\|:80\|:443'
```
 
![image](https://user-images.githubusercontent.com/64194459/82631733-ccfd5200-9c28-11ea-8fcc-639a72de3ff2.png)


## BootStrap OpenShift 4

```bash
bash ~/lab-ocp-rhv/12-bootstrap.sh
```

you can check bootkube.server by
```bash
ssh core@<bootstrap-node> journalctl -b -f -u bootkube.service
```
![image](https://user-images.githubusercontent.com/64194459/82755110-253c7b80-9e04-11ea-9208-89a2d48e98a8.png)

After seeing those messages:
```
INFO Waiting up to 30m0s for the Kubernetes API at https://api.ocp42.local:6443... 
INFO API v1.14.6+2e5ed54 up                       
INFO Waiting up to 30m0s for bootstrapping to complete... 
INFO It is now safe to remove the bootstrap resources 
```

### Ready to access your openshift cluster
```bash
export KUBECONFIG=install_dir/auth/kubeconfig
```

### Remove your bootstrap
until your all nodes are ready, you can remove out the bootstrap
![image](https://user-images.githubusercontent.com/64194459/82755234-f07cf400-9e04-11ea-9062-5bf71193c796.png)


```bash
bash ~/lab-ocp-rhv/13-remove-haproxy.sh
```

you can also quit the http.server 
```
screen -S ${CLUSTER_NAME} -X quit
```

## x. Clean Up
```bash
for n in ocp42-lb ocp42-master-1 ocp42-master-2 ocp42-master-3 ocp42-worker-1 ocp42-worker-2 ocp42-bootstrap; do virsh shutdown $n; virsh destroy $n; virsh undefine $n --remove-all-storage; done
```

```bash
rm -r /var/lib/libvirt/images/*.qcow2
```

```bash
sed -i "/${CLUSTER_NAME}.${BASE_DOM}/d" /etc/hosts
```