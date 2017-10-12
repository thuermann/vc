#!/bin/sh
#
# $Id: cvs-rm-commitid.sh,v 1.1 2017/10/12 08:58:07 urs Exp $

for file in "$@"; do
    printf "g/^commitid\t[0-9A-F]\+;/d\nwq\n" | ed -s "$file"
done
