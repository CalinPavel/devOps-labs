aws ssm get-parameter --region eu-west-3 \                                                           
  --name /ec2/keypair/key-08932905b080c0d73  --with-decryption \
  --query Parameter.Value --output text > lab-key.pem
