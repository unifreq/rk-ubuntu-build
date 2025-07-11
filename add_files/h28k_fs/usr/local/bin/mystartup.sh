#!/usr/bin/bash

################################################################################
# mystartup.sh
#
# This shell program is for testing a startup like rc.local using systemd.
# By David Both
# Licensed under GPL V2
#
################################################################################

# This program should be placed in /usr/local/bin

################################################################################
# This is a test entry

echo performance >/sys/devices/system/cpu/cpufreq/policy0/scaling_governor 

echo `date +%F" "%T` "Startup worked" >> /var/log/mystartup.log
