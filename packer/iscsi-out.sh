#!/bin/bash

TGT="${ISCSI_TGT:-rpi}"

sudo iscsiadm -m node -T iqn.2018-11.io.sdboyer.h:${TGT} --portal 10.10.1.228:3260 -u
sudo iscsiadm -m node -o delete -T iqn.2018-11.io.sdboyer.h:${TGT} --portal 10.10.1.228:3260
