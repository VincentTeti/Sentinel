#!/usr/bin/env bash

if systemctl is-active --quiet nginx; then
    echo "nginx service is running"
    exit 0
else
    echo "nginx service is not running"
    exit 2
fi
