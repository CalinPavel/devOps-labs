aws ec2 describe-subnets   --query 'Subnets[].{ID:SubnetId,CIDR:CidrBlock,AZ:AvailabilityZone,VPC:VpcId,Name:Tags[?Key==`Name`]|[0].Value,AutoPublicIP:MapPublicIpOnLaunch}' --output table
