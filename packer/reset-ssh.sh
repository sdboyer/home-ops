#!/bin/bash
set -e

for PI in 1 2 3 4 5 6 7 8; do
    for NAME in "rpi${PI}.h.sdboyer.io" "rpi${PI}" "10.10.1.20${PI}"; do
        ssh-keygen -R $NAME
        ssh -o StrictHostKeyChecking=accept-new ${NAME} 'hostname'
    done
    #ssh -o StrictHostKeyChecking=accept-new "rpi${PI}" 'hostname'
    #ssh -o StrictHostKeyChecking=accept-new "10.10.1.20${PI}" 'hostname'
done
