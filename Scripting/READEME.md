# AWS DynamoDB & S3 Lab — Makefile Workflow

Hands-on AWS lab automating the full lifecycle of a **DynamoDB** table and an **S3** bucket using the AWS CLI, orchestrated through a `Makefile`. Data is generated with a small Python script that outputs JSON already shaped for DynamoDB's `batch-write-item` API.

```
gen_country.py ──► gen.json (DynamoDB batch format) ──► aws dynamodb batch-write-item
```

## Prerequisites

- AWS CLI v2 configured with valid credentials (`aws configure`)
- Python 3
- `make`
- Region: `eu-west-3` (Paris)

## Configuration

Key variables at the top of the `Makefile`:

| Variable | Value | Description |
|---|---|---|
| `BUCKET_NAME` | `calin-lab-bucket` | S3 bucket name |
| `TABLE_NAME` | `countries` | DynamoDB table name |
| `HASH_KEY` | `cod` | Partition key (type `S`) |
| `AWS_REGION` | `eu-west-3` | Target AWS region |
| `PYTHON` | system python3 | Interpreter used for data generation |

## Project Structure

```
.
├── Makefile           # entry point for all operations
├── gen_country.py     # generates country data in DynamoDB batch format
├── gen.json           # generated payload (output of make gen_data)
└── README.md
```

## Makefile Targets

### Atomic targets

| Target | Description |
|---|---|
| `make create_bucket` | Creates the S3 bucket in the configured region |
| `make drop_bucket` | Removes the S3 bucket |
| `make create_table` | Creates the DynamoDB table (`cod` as HASH key, on-demand billing) |
| `make check_table` | Prints the table status (`CREATING` / `ACTIVE` / ...) |
| `make drop_table` | Deletes the table and **waits** until it no longer exists |
| `make gen_data` | Runs `gen_country.py` and writes the payload to `gen.json` |
| `make push_data` | Batch-writes `gen.json` into the table via `batch-write-item` |

### Composite targets (workflows)

| Target | Expands to | Use case |
|---|---|---|
| `make setup` | `create_bucket create_table` | Initial provisioning |
| `make load` | `gen_data push_data` | Generate fresh data and insert it |
| `make reload` | `drop_table create_table load` | Full reset of the table with new data |
| `make teardown` | `drop_table drop_bucket` | Clean up everything |

## Usage

```bash
# Provision infrastructure
make setup

# Verify the table is ACTIVE before loading
make check_table

# Generate and insert data
make load

# Start over with fresh data
make reload

# Tear everything down
make teardown
```




## What I Learned

- DynamoDB fundamentals: partition keys, typed attributes, on-demand billing, batch operations
- The asynchronous nature of AWS resource lifecycle and how CLI *waiters* solve it
- Composing multi-step cloud workflows with Make composite targets
- Bridging tooling gaps with small Python scripts

## Demo

```bash


pavelcalin@E1712586 ~/Desktop/devOps-labs/Scripting % make create_table
aws dynamodb create-table \
		--table-name countries \
		--attribute-definitions AttributeName=cod,AttributeType=S \
		--key-schema AttributeName=cod,KeyType=HASH \
		--billing-mode PAY_PER_REQUEST \
		--region eu-west-3
{
    "TableDescription": {
        "AttributeDefinitions": [
            {
                "AttributeName": "cod",
                "AttributeType": "S"
            }
        ],
        "TableName": "countries",
        "KeySchema": [
            {
                "AttributeName": "cod",
                "KeyType": "HASH"
            }
        ],
        "TableStatus": "CREATING",
        "CreationDateTime": "2026-07-06T10:37:51.551000+03:00",
        "ProvisionedThroughput": {
            "NumberOfDecreasesToday": 0,
            "ReadCapacityUnits": 0,
            "WriteCapacityUnits": 0
        },
        "TableSizeBytes": 0,
        "ItemCount": 0,
        "TableArn": "arn:aws:dynamodb:eu-west-3:368287211169:table/countries",
        "TableId": "486b8a7f-d5ed-4c37-a596-8379beb76112",
        "BillingModeSummary": {
            "BillingMode": "PAY_PER_REQUEST"
        },
        "DeletionProtectionEnabled": false
    }
}
pavelcalin@E1712586 ~/Desktop/devOps-labs/Scripting % make push_data
aws dynamodb batch-write-item --request-items \
  file://gen.json  \
  --region eu-west-3
{
    "UnprocessedItems": {}
}
pavelcalin@E1712586 ~/Desktop/devOps-labs/Scripting % 

```

