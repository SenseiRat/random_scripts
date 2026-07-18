#!/bin/bash

API_URL="https://api.cloudflare.com/client/v4"
CUR_IP=$(curl 'https://api6.ipify.org' 2>/dev/null | awk -F '[' '{ print $1 }')
SUB_LIST=()
ZONE_DATA=$(curl -X \
    GET "${API_URL}/zones/$ZONE_ID/dns_records" \
    -H "Authorization: Bearer $API_KEY" \
    -H "Content-Type: application/json" 2>/dev/null)

function check_var {
    if [[ -z $1 ]]; then
        echo "No current $2 data available."
        exit 1
    fi
}

function main {
    check_var "$CUR_IP" "IP"
    check_var "$ZONE_DATA" "zone"

    # Get the current IP of the DNS record; if domain is not
    # primary domain, store in a list to check IP vs old DNS
    for (( i=0; i<$(echo "$ZONE_DATA" | jq length); i++ )); do
        RECORD=$(echo "$ZONE_DATA" | jq -r ".result[$i].name")
        if [[ $RECORD == "$PRIM_URL" ]]; then
            CUR_DNS=$(echo "$ZONE_DATA" | jq -r ".result[$i].content")
            DNS_ID=$(echo "$ZONE_DATA" | jq -r ".result[$i].id")
        fi
    done

    # Check each subdomain in array to see if it's IP also needs
    # to be updated
    for (( i=0; i<$(echo "$ZONE_DATA" | jq length); i++ )); do
        RECORD=$(echo "$ZONE_DATA" | jq -r ".result[$i].name")
        if [[ $RECORD != "$PRIM_URL" ]]; then
            CHECK_TYPE=$(echo "$ZONE_DATA" | jq -r ".result[$i].type")
            if [[ $CHECK_TYPE == "A" ]]; then
                CHECK_IP=$(echo "$ZONE_DATA" | jq -r ".result[$i].content")
                if [[ $CHECK_IP == "$CUR_DNS" ]]; then
                    SUB_LIST+=("${RECORD},$(echo "$ZONE_DATA" | \
                                jq -r ".result[$i].id")")
                fi
            fi
        fi
    done

    if [[ $CUR_IP == "$CUR_DNS" ]]; then
        echo "DNS matches IP address"
    else
        echo "DNS does not match IP address"
        echo "Updating DNS to match current IP address..."
        curl -X \
            PUT "${API_URL}/zones/$ZONE_ID/dns_records/$DNS_ID" \
            -H "Authorization: Bearer $API_KEY" \
            -H "Content-Type: application/json" \
            --data "{ \
                    \"type\":\"A\", \
                    \"name\":\"$PRIM_URL\", \
                    \"content\":\"$CUR_IP\", \
                    \"proxied\":true}" > /dev/null 2>&1
        echo "DNS should be updated now."
        echo "Updating DNS for subdomains..."
        for ID in ${SUB_LIST[*]}; do
            SUB_URL=$(echo "$ID" | awk -F ',' '{ print $1 }')
            SUB_ID=$(echo "$ID" | awk -F ',' '{ print $2 }')
            curl -X \
            PUT "${API_URL}/zones/$ZONE_ID/dns_records/$SUB_ID" \
            -H "Authorization: Bearer $API_KEY" \
            -H "Content-Type: application/json" \
            --data "{ \
                    \"type\":\"A\", \
                    \"name\":\"$SUB_URL\", \
                    \"content\":\"$CUR_IP\", \
                    \"proxied\":true}" > /dev/null 2>&1
        done
    fi
}

main
