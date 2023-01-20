#!/bin/bash
# Authentication info: Update these
api_token="{{ cloudflare_api_token }}"
zone_name="{{ cloudflare_zone_name }}"
record_name="{{ cloudflare_record_name }}"

# Create cruft directory and setup env
mkdir -p files/pubip
public_ip=$(curl -s http://ipv4.icanhazip.com)
old_public_ip="files/pubip/publicip"
cloudflare_ids="files/pubip/cloudflare.ids"
log_file="/var/log/publicip.log"

# Setup logging
log() {
    if [ "$1" ]; then
        echo -e "[$(date)] - $1" >> $log_file
    fi
}

# Check to see if our IP has changed
if [ -f $old_public_ip ]; then
    old_ip=$(cat $old_public_ip)
    if [ $public_ip == $old_ip ]; then
        log "IP hasn't changed."
        exit 0
    fi
fi

# Make sure we've got a zone and a record ID saved, get them if not.
if [ -f $cloudflare_ids ] && [ $(wc -l $cloudflare_ids | cut -d " " -f 1) == 2 ]; then
    zone_id=$(head -1 $cloudflare_ids)
    record_id=$(tail -1 $cloudflare_ids)
else
    zone_id=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$zone_name" -H "Content-Type: application/json" -H "Authorization: Bearer $api_token" | grep -Po '(?<="id":")[^"]*' | head -1 )
    record_id=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records?name=$record_name" -H "Content-Type: application/json" -H "Authorization: Bearer $api_token" | grep -Po '(?<="id":")[^"]*' | head -1 )
    echo "$zone_id" > $cloudflare_ids
    echo "$record_id" >> $cloudflare_ids
fi

# Update the record since we've updated our IP
update=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records/$record_id" -H "Authorization: Bearer $api_token" -H "Content-Type: application/json" --data "{\"id\":\"$zone_id\",\"type\":\"A\",\"name\":\"$record_name\",\"content\":\"$ip\",\"ttl\":600}")

# Log update status
if [[ $update == *"\"success\":false"* ]]; then
    message="Update failed:\n$update"
    log "$message"
    exit 1
else
    message="Public IP updated to: $public_ip"
    echo "$public_ip" > $old_public_ip
    log "$message"
fi