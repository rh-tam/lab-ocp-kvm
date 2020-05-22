#!/bin/bash
firewall-cmd --add-source=${HOST_NET}
firewall-cmd --add-port=${WEB_PORT}/tcp

firewall-cmd --add-masquerade --zone=public --permanent
firewall-cmd --reload
firewall-cmd --list-all

iptables -I INPUT -p tcp -m tcp --dport ${WEB_PORT} -s ${HOST_NET} -j ACCEPT
