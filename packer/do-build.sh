#!/bin/bash

# RUN FROM WITHIN VAGRANT - `vagrant up`

set -x
set -e

BASE_IMG=pibase.img.zip
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
CONF_DIR=${SCRIPT_DIR}/sdb/conf
OUTPUT_DIR=${SCRIPT_DIR}/sdb/output
TMPDIR=/var/tmp

cd ${SCRIPT_DIR}

if test ! -f ${OUTPUT_DIR}/${BASE_IMG}; then
    sudo -E packer build -on-error=ask ${CONF_DIR}/pibase.pkr.hcl
fi

if [ "$1" = "" ]; then
    for FILE in $(ls ${CONF_DIR}/pivars/*.hcl); do
        sudo -E packer build -on-error=ask -var-file=$FILE ${CONF_DIR}/hopepi.pkr.hcl
    done
elif [[ -f ${CONF_DIR}/pivars/$1.pkrvars.hcl ]]; then
    sudo -E packer build -on-error=ask -var-file=${CONF_DIR}/pivars/$1.pkrvars.hcl ${CONF_DIR}/hopepi.pkr.hcl
else
    echo "pivars/$1.pkrvars.hcl does not exist"
    exit 1
fi
