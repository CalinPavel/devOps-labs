Utils:

https://prometheus.io/download/#prometheus
https://prometheus.io/download/#node_exporter
https://github.com/prometheus/node_exporter



Install ssm on linux machine:

sudo snap start amazon-ssm-agent
sudo snap restart amazon-ssm-agent


For my MacOS:
brew install --cask session-manager-plugin


SSM Connection:

aws ssm start-session \
  --target i-08e8b12a32784a52b \
  --document-name AWS-StartPortForwardingSession \
  --parameters '{"portNumber":["3000"],"localPortNumber":["3000"]}'