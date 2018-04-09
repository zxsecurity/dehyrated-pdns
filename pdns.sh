#!/usr/bin/env bash

# Author: @antoifon 
#
# Example how to deploy a DNS challange using powerdns
#

set -e
set -u
set -o pipefail
umask 077

# Wait this value in seconds at max for all nameservers to be ready 
# with the deployed challange or fail if they are not
dns_sync_timeout_secs=90

   domain="${2}"
    token="${4}"

IFS='.' read -a myarray_domain <<< "$domain"
# Extract TLD from domain
lastcmp=$(echo $domain | rev | cut -d "." -f2);
if [ ${#lastcmp} == 2 ]; then
    root_domain=$(echo $domain | rev | cut -d "." -f1-3 | rev) # ccTLDs
    root_length=2
else
    root_domain=$(echo $domain | rev | cut -d "." -f1-2 | rev) # TLD
    root_length=1
fi
done="no"

if [[ "$1" = "deploy_challenge" ]]; then
   pdnsutil add-record "${root_domain}" _acme-challenge TXT "${token}"
   domain_without_trailing_dot=${domain%.}
   dots=${domain_without_trailing_dot//[^.]}
   if [ "${#dots}" -gt $root_length ]; then
       # certificate is for subdomain
       nameservers="$(dig -t ns +short ${domain#*.})"
   else
       # certificate is for domain itself, dont strip of a domain part
       nameservers="$(dig -t ns +short ${domain})"
   fi
   challenge_deployed=0
   for((timeout_counter=0,failed_servers=0;$timeout_counter<$dns_sync_timeout_secs;failed_servers=0,timeout_counter++)); do
     for nameserver in $nameservers;do
       if ! dig @$nameserver +short -t TXT _acme-challenge.$domain | grep -- "$token" > /dev/null; then
         failed_servers=1
       fi
     done
     [ "$failed_servers" == 0 ] && { challenge_deployed=1 ; break ; }
     sleep 1
     printf "."
   done
   if [ "$challenge_deployed" == "1" ]; then
     done="yes"
   else
     echo -e "\n\nERROR:"
     echo "Challenge could not be deployed to all nameservers. Timeout of $dns_sync_timeout_secs "
     echo "seconds reached. If your slave servers need more time to synchronize, increase value "
     echo "of variable dns_sync_timeout_secs in file $0."
     exit 1
   fi
fi

if [[ "$1" = "clean_challenge" ]]; then
    pdnsutil delete-rrset "${root_domain}" _acme-challenge TXT
    done="yes"
fi

if [[ "${1}" = "deploy_cert" ]]; then
    # do nothing for now
    done="yes"
fi

if [[ ! "${done}" = "yes" ]]; then
    echo Unkown hook "${1}"
    exit 1
fi

exit 0

