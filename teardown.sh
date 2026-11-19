#!/usr/bin/env bash
# Terminates YOUR server (the one tagged with your handle) and deletes your security group, key pair and role. Run with: ./teardown.sh
set -u
cd "$(dirname "$0")"
STUDENT=$(bash .lab/handle.sh) || exit 1
aws sts get-caller-identity >/dev/null 2>&1 || { echo "No working AWS credentials." >&2; exit 1; }
IDS=$(aws ec2 describe-instances --filters Name=tag:lab,Values=aws-ec2-imdsv2 Name=tag:student,Values=$STUDENT Name=instance-state-name,Values=pending,running,stopping,stopped --query 'Reservations[].Instances[].InstanceId' --output text)
if [ -n "$IDS" ]; then aws ec2 terminate-instances --instance-ids $IDS >/dev/null && aws ec2 wait instance-terminated --instance-ids $IDS && echo "terminated $IDS"; fi
for g in $(aws ec2 describe-security-groups --filters Name=group-name,Values=clippy-imds-$STUDENT --query 'SecurityGroups[].GroupId' --output text); do aws ec2 delete-security-group --group-id $g && echo "deleted security group $g"; done
aws ec2 delete-key-pair --key-name clippy-imds-$STUDENT >/dev/null 2>&1 && echo "deleted key pair"
r=clippy-imds-role-$STUDENT
aws iam remove-role-from-instance-profile --instance-profile-name $r --role-name $r 2>/dev/null
aws iam delete-instance-profile --instance-profile-name $r 2>/dev/null && echo "deleted instance profile"
for p in $(aws iam list-role-policies --role-name $r --query PolicyNames --output text 2>/dev/null); do aws iam delete-role-policy --role-name $r --policy-name "$p"; done
for a in $(aws iam list-attached-role-policies --role-name $r --query 'AttachedPolicies[].PolicyArn' --output text 2>/dev/null); do aws iam detach-role-policy --role-name $r --policy-arn "$a"; case "$a" in arn:aws:iam::aws:*) ;; *) aws iam delete-policy --policy-arn "$a" 2>/dev/null;; esac; done
aws iam delete-role --role-name $r 2>/dev/null && echo "deleted role"
rm -f clippy-imds.pem
echo "Now run ./verify-teardown.sh"
