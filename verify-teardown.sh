#!/usr/bin/env bash
# Proves the lab left nothing in AWS. Run with: ./verify-teardown.sh
set -u
ACCOUNT=$(aws sts get-caller-identity --query Account --output text 2>/dev/null) || { echo "No working AWS credentials." >&2; exit 1; }
echo "Checking account $ACCOUNT, region $(aws configure get region)"
pass=0; failn=0
check() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then echo "PASS  $d"; pass=$((pass+1)); else echo "FAIL  $d"; failn=$((failn+1)); fi; }
check "no running or stopped server tagged lab=aws-ec2-imdsv2" bash -c "[ -z \"\$(aws ec2 describe-instances --filters Name=tag:lab,Values=aws-ec2-imdsv2 Name=instance-state-name,Values=pending,running,stopping,stopped --query 'Reservations[].Instances[].InstanceId' --output text)\" ]"
check "no security group clippy-imds" bash -c "[ -z \"\$(aws ec2 describe-security-groups --filters Name=group-name,Values=clippy-imds --query 'SecurityGroups[].GroupId' --output text)\" ]"
check "no key pair clippy-imds" bash -c "[ -z \"\$(aws ec2 describe-key-pairs --filters Name=key-name,Values=clippy-imds --query 'KeyPairs[].KeyName' --output text)\" ]"
check "no role or instance profile clippy-imds-role" bash -c "! aws iam get-role --role-name clippy-imds-role && ! aws iam get-instance-profile --instance-profile-name clippy-imds-role"
check "no clippy-imds.pem file left" bash -c "! test -e clippy-imds.pem"
echo
if [ "$failn" -eq 0 ]; then echo "TEARDOWN VERIFIED ($pass/$pass) in account $ACCOUNT"; else echo "NOT CLEAN: $failn leftover(s). Remove them and run this again."; fi
exit "$failn"
