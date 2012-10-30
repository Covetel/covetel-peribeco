#!/bin/bash

ctags -f tags --recurse --totals \
    --exclude=blib \
    --exclude=debian \
    --exclude=.git \
    --exclude='*~' \
    --languages=Perl --langmap=Perl:+.t
