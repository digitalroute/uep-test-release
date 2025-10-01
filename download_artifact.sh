#!/bin/bash
set -e

function ctrl_c() {
    echo "** Trapped CTRL-C"
    exit -1
}

trap ctrl_c INT

account_id=$(echo "$SERVER_URL" | cut -d. -f1)
region=$(echo "$SERVER_URL" | cut -d. -f4)


set +e
profile_name=$(awk -v expected_account_id="$account_id" '
BEGIN {
    found=0
}
# When we enter a profile block, grab the name of it so we can use it later
/^\[profile .+]$/ {
    profile_name = $0
    gsub(/^\[profile |\]$/, "", profile_name)
}
# When we find the sso_account_id within the profile block, check it against
# the expected account id. If there is a match, we are done and can bail.
/^sso_account_id.*$/ {
    account_id = $0
    gsub(/^sso_account_id = /, "", account_id)
    if (account_id == expected_account_id) {
        found++
        exit
    }
}
# If we found a match, print it. Otherwise exit with a failure.
END {
    if (found>0) {
        print profile_name
    } else {
        exit 1
    }
}' "${AWS_CONFIG_FILE:-$HOME/.aws/config}")
success=$?
if [[ $success != 0 ]]; then
    echo >&2 "Failed to get profile name from ${AWS_CONFIG_FILE:-$HOME/.aws/config} for account $account_id"
    exit 1
fi
set -e


aws sso login --profile $profile_name
set -x

aws s3 cp "$1" ./$(basename "$1") --profile "$profile_name"