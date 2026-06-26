aws ec2 create-key-pair \
  --key-name demo-ssh \
  --query 'KeyMaterial' \
  --output text > my-key-ssh.pem

chmod 400 my-key-ssh.pem
