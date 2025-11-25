#!/bin/bash

if [ -x /usr/bin/neofetch ]; then
    /usr/bin/neofetch
elif [ -x /usr/bin/linux_logo ];then
    /usr/bin/linux_logo
elif [ -x /usr/bin/screenfetch ];then
    LC_ALL=C /usr/bin/screenfetch
fi
