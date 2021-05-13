#!/usr/bin/env bash
set -x
restorecon -vr /var/log/at
restorecon -vr /var/log/at-no-rotate
