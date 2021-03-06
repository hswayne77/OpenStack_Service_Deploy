#!/usr/bin/env bash

set -x

CEILOMETER_CONFIG_PATH=/etc/ceilometer
if [ -e ${CEILOMETER_CONFIG_PATH} ];then
    rm -rf ${CEILOMETER_CONFIG_PATH}
fi
mkdir -p /etc/ceilometer
cp etc/ceilometer/*.json /etc/ceilometer
cp etc/ceilometer/*.yaml /etc/ceilometer
cp etc/ceilometer/ceilometer.conf.sample /etc/ceilometer/ceilometer.conf
