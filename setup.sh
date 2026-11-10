#!/usr/bin/env bash
# Launches the server "the way it was launched that day". Run once: ./setup.sh
set -u
cd "$(dirname "$0")"
aws sts get-caller-identity >/dev/null 2>&1 || { echo "No working AWS credentials." >&2; exit 1; }
if aws ec2 describe-instances --filters Name=tag:lab,Values=aws-ec2-imdsv2 Name=instance-state-name,Values=pending,running --query 'Reservations[].Instances[].InstanceId' --output text | grep -q 'i-'; then echo "The server already exists."; exit 0; fi
VPC=$(aws ec2 describe-vpcs --filters Name=isDefault,Values=true --query 'Vpcs[0].VpcId' --output text)
[ "$VPC" != None ] || { echo "No default VPC in this region. This lab uses the default VPC." >&2; exit 1; }
SUBNET=$(aws ec2 describe-subnets --filters Name=vpc-id,Values=$VPC Name=map-public-ip-on-launch,Values=true --query 'Subnets[0].SubnetId' --output text)
MYIP=$(curl -s https://checkip.amazonaws.com)
[ -n "$MYIP" ] || { echo "Cannot find your public IP." >&2; exit 1; }
# the key pair (the private key stays on your disk, gitignored)
aws ec2 delete-key-pair --key-name clippy-imds >/dev/null 2>&1
aws ec2 create-key-pair --key-name clippy-imds --key-type ed25519 --query KeyMaterial --output text > clippy-imds.pem && chmod 600 clippy-imds.pem
# the role: it can list buckets, which is already too much
aws iam create-role --role-name clippy-imds-role --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ec2.amazonaws.com"},"Action":"sts:AssumeRole"}]}' --tags Key=lab,Value=aws-ec2-imdsv2 >/dev/null
aws iam attach-role-policy --role-name clippy-imds-role --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess
aws iam create-instance-profile --instance-profile-name clippy-imds-role >/dev/null
aws iam add-role-to-instance-profile --instance-profile-name clippy-imds-role --role-name clippy-imds-role
SG=$(aws ec2 create-security-group --group-name clippy-imds --description "Clippy IMDS lab" --vpc-id $VPC --tag-specifications 'ResourceType=security-group,Tags=[{Key=lab,Value=aws-ec2-imdsv2}]' --query GroupId --output text)
aws ec2 authorize-security-group-ingress --group-id $SG --protocol tcp --port 22 --cidr $MYIP/32 >/dev/null
aws ec2 authorize-security-group-ingress --group-id $SG --protocol tcp --port 80 --cidr 0.0.0.0/0 >/dev/null
AMI=$(aws ssm get-parameter --name /aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id --query Parameter.Value --output text)
sleep 10   # IAM propagation
ID=$(aws ec2 run-instances --image-id $AMI --instance-type t3.micro --subnet-id $SUBNET --security-group-ids $SG --key-name clippy-imds \
  --iam-instance-profile Name=clippy-imds-role --user-data file://userdata.sh \
  --metadata-options HttpTokens=optional,HttpPutResponseHopLimit=2,HttpEndpoint=enabled \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=lab,Value=aws-ec2-imdsv2},{Key=Name,Value=clippy-imds}]' --query 'Instances[0].InstanceId' --output text)
aws ec2 wait instance-running --instance-ids $ID
IP=$(aws ec2 describe-instances --instance-ids $ID --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
echo "Server $ID is running at $IP (SSH allowed from $MYIP only)."
echo "  ssh -i clippy-imds.pem -o IdentitiesOnly=yes ubuntu@$IP"
echo "Clippy needs a minute or two to install: http://$IP/healthz"
