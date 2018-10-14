#!/usr/bin/env bash

function help(){
        echo "Basic Usage: $0 -p"
        exit 1
}

function results(){
        if [ $? -eq 0 ]; then
                echoGreen "Test results PASSED\n"
        else
                echoRed "Test results FAILED\n"
                fail=true
        fi
}

function failResults(){
        if [ $? -ne 0 ]; then
                echoGreen "Test results PASSED\n"
        else
                echoRed "Test results FAILED\n"
                fail=true
        fi
}

green='\e[1;32m'
red='\e[1;31m'
yellow='\e[1;33m'
blue='\e[1;34m'
cyan='\033[0;36m'
end='\033[0m'

function echoGreen(){
        echo -e ${green}"$*"${end}
}
function echoRed(){
        echo -e ${red}"$*"${end}
}
function echoYellow(){
        echo -e ${yellow}"$*"${end}
}
function echoBlue(){
        echo -e ${blue}"$*"${end}
}
function echoCyan(){
        echo -e ${cyan}"$*"${end}
}

# enable some options
while getopts 'p' opt; do
        case ${opt} in
                p) prod="true" ;;
                *) help
        esac
done

export VAULT_ADDR=`cd ../terraform;terraform output url`

if [ "${prod}" != "true" ]; then
	export VAULT_SKIP_VERIFY=true
fi

random=$RANDOM
export project=`cd ../terraform;terraform output project`
cmd="env -u GOOGLE_APPLICATION_CREDENTIALS vault login -method=gcp role=vault-testing service_account=vault-testing@${project}.iam.gserviceaccount.com project=${project}"
echoCyan "Running test: ${cmd}"
${cmd} > /dev/null 2>&1
results

declare -a versions=("kv" "kv2")
for version in "${versions[@]}"
do
	cmd="vault kv put ${version}/testing/temp-${random} foo=bar"
	echoCyan "Running test: ${cmd}"
	${cmd}
	results

	cmd="vault kv get ${version}/testing/temp-${random}"
	echoCyan "Running test: ${cmd}"
	${cmd}
	results

	cmd="vault kv put ${version}/testing/temp-${random} foo=baz"
	echoCyan "Running test: ${cmd}"
	${cmd}
	results
	
	cmd="vault kv put ${version}/testing/temp-json-${random} @test.json"
	echoCyan "Running test: ${cmd}"
	${cmd}
	results
	
	cmd="vault kv delete ${version}/testing/temp-json-${random}"
	echoCyan "Running test: ${cmd}"
	${cmd}
	results

	cmd="vault kv delete ${version}/testing/temp-${random}"
	echoCyan "Running test: ${cmd}"
	${cmd}
	results

	if [ "${version}" = kv2 ]; then
		cmd="vault kv metadata delete ${version}/testing/temp-${random}"
		echoCyan "Running test: ${cmd}"
		${cmd}
		results
	fi

	cmd="vault kv get ${version}/testing/temp-${random}"
	echoYellow "Running failure test: ${cmd}"
	${cmd}
	failResults
        
	cmd="vault kv put ${version}/temp-${random} foo=bar"
	echoYellow "Running failure test: ${cmd}"
	${cmd}
	failResults
done


# fail overall script if any of the individual results fail
if [ "${fail}" = true ]; then
        exit 1
fi
