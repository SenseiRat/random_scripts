#!/bin/bash

WP_DIR="/home/sean/.config/i3/wallpapers"
WP_CT=$(ls -1 ${WP_DIR} | wc -l)

if [[ -f ${WP_DIR}/lock ]]; then
    kill $(cat ${WP_DIR}/lock)
    rm -rf ${WP_DIR}/lock
fi
echo "$$" > ${WP_DIR}/lock

while :; do
    RAND_INT=$(echo $((1 + RANDOM % $WP_CT)))

    i=1
    for PAPER in $(ls -1 ${WP_DIR}); do
        if [[ $i -eq ${RAND_INT} ]]; then
            feh --bg-fill ${WP_DIR}/${PAPER}
            break
        fi
        ((i++))
    done
    sleep 3600
done

rm -rf ${WP_DIR}/lock
