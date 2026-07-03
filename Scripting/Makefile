BUCKET_NAME   := calin-lab-bucket
TABLE_NAME    := countries
HASH_KEY      := cod
AWS_REGION    := eu-west-3
PYTHON := /Library/Developer/CommandLineTools/usr/bin/python3

.PHONY: create_bucket create_table drop_bucket gen_data

create_bucket:
	aws s3 mb s3://${BUCKET_NAME} --region ${AWS_REGION}

drop_bucket:
	aws s3 rb s3://${BUCKET_NAME} --region ${AWS_REGION}

create_table:
	aws dynamodb create-table \
		--table-name $(TABLE_NAME) \
		--attribute-definitions AttributeName=$(HASH_KEY),AttributeType=S \
		--key-schema AttributeName=$(HASH_KEY),KeyType=HASH \
		--billing-mode PAY_PER_REQUEST \
		--region $(AWS_REGION)

check_table:
	aws dynamodb describe-table --table-name ${TABLE_NAME} \
  --query 'Table.TableStatus' --region eu-west-3

drop_table:
	aws dynamodb delete-table --table-name ${TABLE_NAME} --region eu-west-3
	aws dynamodb wait table-not-exists --table-name $(TABLE_NAME) --region $(AWS_REGION)

gen_data:
	${PYTHON} gen_country.py > gen.json

push_data:
	aws dynamodb batch-write-item --request-items \
  file://gen.json  \
  --region eu-west-3


setup: create_bucket create_table 

load: gen_data push_data 

reload: drop_table create_table load 

teardown: drop_table drop_bucket
