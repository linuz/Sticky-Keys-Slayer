#!/bin/bash

Xvfb :0 -ac -screen 0 1280x720x16 -nolisten tcp &
./stickyKeysSlayer.sh $@
