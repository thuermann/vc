#!/bin/sh
#
# $Id: cvs-commitid-to-timestamp.sh,v 1.1 2017/10/20 08:19:52 urs Exp $
#
# Convert a CVS commit ID to the corresponding timestamp.
#
# The ID seems to consist of 3 + 8 + 8 uppercase hex digits, where the middle
# group of 8 digits represents the timestamp.  We extract it and convert to
# decimal using bc(1) and convert the decimal timestamp using GNU date.

id=$1

ts=$(echo "w = 2 ^ 32; ibase = 16; $id / w % w" | bc)
date -d@$ts
