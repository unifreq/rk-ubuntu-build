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

[ -x /usr/local/bin/run_ext_scr.sh ] && /usr/local/bin/run_ext_scr.sh iot_install.sh >> /var/log/mystartup.log

echo `date +%F" "%T` "Startup worked" >> /var/log/mystartup.log
