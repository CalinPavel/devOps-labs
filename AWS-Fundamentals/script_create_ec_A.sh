aws ec2 run-instances \
  --image-id ami-00034b0b6e2e5a27e \
  --instance-type t3.micro \
  --key-name demo-ssh \
  --security-group-ids sg-0b414287240a63f16 \
  --subnet-id subnet-09ff7d4a67e32a6f2 \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=NodeA}]'
