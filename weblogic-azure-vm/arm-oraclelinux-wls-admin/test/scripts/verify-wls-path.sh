#!/bin/bash
# Copyright (c) 2024, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

sudo -S [ -d "/u01/app/wls/install/oracle/middleware/oracle_home/wlserver/modules" ] && exit 0
exit 1
