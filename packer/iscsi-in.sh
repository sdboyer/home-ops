#!/bin/bash

# dumb helper script for going in and out of iscsi while debugging

TGT="${ISCSI_TGT:-rpi}"

sudo iscsiadm \
  --mode discovery \
  --type sendtargets \
  --portal 10.10.1.228
sudo iscsiadm \
  --mode node \
  --targetname iqn.2018-11.io.sdboyer.h:${TGT} \
  --portal 10.10.1.228 \
  --login
