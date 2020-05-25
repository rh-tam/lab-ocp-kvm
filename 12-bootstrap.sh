#!/bin/bash

set -x
./openshift-install --dir=install_dir wait-for bootstrap-complete
set +x
# you can check the openshift bootstrap by
# ssh core@<bootstrap-node> journalctl -b -f -u bootkube.service