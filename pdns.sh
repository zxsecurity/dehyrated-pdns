#!/usr/bin/env bash

# Author: @antoifon 
#
# Example how to deploy a DNS challange using powerdns
#

set -e
set -u
set -o pipefail
umask 077

done="no"

if [[ "$1" = "deploy_challenge" ]]; then
   # Wait this value in seconds at max for all nameservers to be ready 
   # with the deployed challange or fail if they are not
   dns_sync_timeout_secs=90

   domain="${2}"
   token="${4}"
   
   pdnsutil add-record "${domain}" _acme-challenge TXT "\"${token}\""
   nameservers="$(dig -t ns +short ${domain})"
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
    domain="${2}"

    pdnsutil delete-rrset "${domain}" _acme-challenge TXT
    done="yes"
fi

if [[ "${1}" =~ ^(deploy_cert|deploy_ocsp|unchanged_cert|invalid_challenge|request_failure|generate_csr|startup_hook|exit_hook)$ ]]; then
    # do nothing for now
    done="yes"
fi

if [[ "${1}" = "this_hookscript_is_broken__dehydrated_is_working_fine__please_ignore_unknown_hooks_in_your_script" ]]; then
   # do nothing
   done="yes"
fi

if [[ ! "${done}" = "yes" ]]; then
    echo Unkown hook "${1}"
    exit 1
fi

exit 0

