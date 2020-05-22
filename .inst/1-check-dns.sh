#!/bin/bash
echo "1.2.3.4 test.local" >> /etc/hosts
systemctl restart libvirtd
dig test.local @${HOST_IP}
dig -x 1.2.3.4 @${HOST_IP}
echo "srv-host=test.local,yayyy.local,2380,0,10" > ${DNS_DIR}/temp-test.conf
systemctl reload NetworkManager
dig srv test.local
dig srv test.local @${HOST_IP}
rm -rf ${DNS_DIR}/temp-test.conf
sed -i '/test\.local/d' /etc/hosts
