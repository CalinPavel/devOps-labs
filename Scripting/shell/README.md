# 🕵️ h4ck3r Shell — AWS Lambda Lab

A hacker-themed interactive Python REPL that talks to AWS Lambda functions backed by DynamoDB. Built as a hands-on lab to learn how Lambda functions are **created**, **invoked**, and **exposed as public API endpoints**.

```
root@h4ck3r:~$ lambda
[*] Invoking remote function...
[+] 250 records retrieved from target.
```

## What this lab covers

- **Creating Lambda functions** — both functions (`hello` and `getData`) were built and deployed **directly in the AWS Console**, with the code edited and deployed from the built-in editor.
- **Exposing Lambda as an API endpoint** — each function is published via a **Lambda Function URL**, giving it a public HTTPS endpoint (`https://<id>.lambda-url.eu-west-3.on.aws/`) without needing API Gateway.
- **Invoking Lambda two different ways**:
  - **HTTPS** — plain `requests.get()` against the Function URL (no AWS credentials needed)
  - **AWS API (boto3 / CLI)** — direct `lambda:InvokeFunction` calls using AWS credentials
- **IAM isolation & least privilege** — the AWS API invocations run under a **dedicated, isolated IAM user** (`lambda-caller`) that is only allowed to invoke the Lambda function, nothing else (see screenshots). The Lambda execution role itself only has read access to the DynamoDB table.
- **DynamoDB integration** — `getData` scans the `countries` table (partition key `cod`, on-demand billing) and returns all items as JSON.
- **Data generation via Makefile** — the table was created and populated using **Makefile-driven scripts** (`make create_table` for the DynamoDB table, plus a Python generator script for the country data loaded through the AWS CLI), keeping the whole lab pipeline reproducible.

## Architecture

```
┌─────────────┐   HTTPS (Function URL)   ┌──────────────┐        ┌────────────┐
│             │ ───────────────────────► │              │  scan  │  DynamoDB  │
│  h4ck3r     │                          │   Lambda     │ ─────► │  countries │
│  REPL       │   boto3 invoke           │   getData    │        │  (eu-west-3)│
│  (main.py)  │ ───────────────────────► │              │        └────────────┘
└─────────────┘   as IAM user            └──────────────┘
                  lambda-caller
```

Region: **eu-west-3 (Paris)**

## Commands

| Command  | Description                                                            |
|----------|------------------------------------------------------------------------|
| `help`   | Show the list of available commands                                    |
| `hello`  | Call the `hello` Lambda over its public Function URL (HTTPS)           |
| `lambda` | Call `getData` over HTTPS and render the DynamoDB items as a rich table |
| `invoke` | Invoke `getData` through the AWS API with boto3 (IAM-authenticated)    |
| `whoami` | Show the current AWS identity via STS (`get-caller-identity`)          |
| `exit`   | Close the session                                                      |

## Setup

Requirements: Python 3.10+, AWS CLI configured.

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install boto3 requests rich
```

Configure the isolated IAM user profile used for `invoke` and `whoami`:

```bash
aws configure --profile lambda-caller
export AWS_PROFILE=lambda-caller
```

Run:

```bash
python main.py
```

## IAM setup (least privilege)

The `lambda-caller` user has a single inline policy scoped to one function:

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": "lambda:InvokeFunction",
    "Resource": "arn:aws:lambda:eu-west-3:<ACCOUNT_ID>:function:getData"
  }]
}
```

The Lambda execution role has `AWSLambdaBasicExecutionRole` (CloudWatch logs) plus read-only access to the `countries` DynamoDB table.

## What I learned

- How to create and deploy a Lambda function from the AWS Console
- How to build a reproducible data pipeline with a Makefile — creating the DynamoDB table and generating/loading the country data through scripted targets
- How to expose a Lambda as a public HTTPS endpoint with Function URLs (auth type `NONE` vs `AWS_IAM`)
- The difference between invoking over HTTP vs through the AWS API (`lambda:InvokeFunction`)
- How Lambda execution roles work and how to fix `AccessDeniedException` on DynamoDB (`dynamodb:Scan`)
- How to isolate credentials with a dedicated IAM user and named AWS CLI profiles
- Debugging Lambda through CloudWatch logs and direct CLI invocation (502 / `FunctionError: Unhandled`)
- Reading the boto3 invoke response (`Payload` stream, `FunctionError` field)

## Sample invocation (AWS CLI)

Invoking `getData` directly through the AWS API, authenticated as the isolated `lambda-caller` IAM user:

```bash
aws lambda invoke \
  --function-name getData \
  --region eu-west-3 \
  output.json && cat output.json
```

```json
{
    "StatusCode": 200,
    "ExecutedVersion": "$LATEST"
}
{"statusCode": 200, "body": "[{\"cod3\": \"ESH\", \"numeric\": \"732\", \"nume\": \"Western Sahara\", \"cod\": \"EH\"}, {\"cod3\": \"IND\", \"numeric\": \"356\", \"nume\": \"India\", \"cod\": \"IN\"}, ...]", "count": 10}
```

The CLI writes the function's response payload to `output.json` and prints the invocation metadata (`StatusCode`, `ExecutedVersion`) to stdout. The payload follows the Lambda proxy format: the DynamoDB items are JSON-serialized inside the `body` field, with `count` reporting the number of records.

## Screenshots

See the `screenshots/` folder for the Lambda console setup, Function URL configuration, and the isolated IAM user policy.

---