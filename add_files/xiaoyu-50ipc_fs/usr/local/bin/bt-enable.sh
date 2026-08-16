#!/bin/bash
HCICONFIG="/usr/bin/hciconfig"
HCI="hci0"
BTMGMT="/usr/bin/btmgmt"
HOSTNAME=$(/usr/bin/hostname)
BTNAME=${HOSTNAME:0:10}

for i in $(seq 1 60); do
    if ${BTMGMT} info 2>/dev/null | grep -q 'Primary controller'; then
        break
    fi
    sleep 1
done

if ${HCICONFIG} ${HCI} 2>/dev/null | grep -q 'UP RUNNING' > /dev/null 2>&1; then
    echo "--> hci0: power off"
    timeout 5 ${BTMGMT} power off || true
    sleep 1
fi

echo "--> hci0: setting name to ${BTNAME}"
timeout 5 ${BTMGMT} name ${BTNAME} || true
echo "--> hci0: connectable on"
timeout 5 ${BTMGMT} connectable on || true
echo "--> hci0: bondable on"
timeout 5 ${BTMGMT} bondable on || true
echo "--> hci0: advertising on"
timeout 5 ${BTMGMT} advertising on || true

sleep 1
echo "--> hci0: power on"
timeout 15 ${BTMGMT} power on || true
sleep 1
echo "--> hci0: discovery on"
timeout 5 ${BTMGMT} discov on || true

sleep 1
echo "--> hci0: show btmgmt info"
${BTMGMT} info
echo "--> hci0: show hciconfig info"
${HCICONFIG} ${HCI}
