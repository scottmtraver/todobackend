#!/bin/bash

. /appenv/bin/activate

pip download -d /build -r requirements_test.txt

pip install --no-index -f /build -r requirements_test.txt

exec $@
