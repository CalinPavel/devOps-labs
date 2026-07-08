# toDoList — Serverless Lab (AWS)

A to-do list application built with the [Serverless Framework](https://www.serverless.com/), used as a hands-on AWS lab covering Lambda, API Gateway, SQS, DynamoDB, and VPC networking (private subnets, security groups, VPC endpoints).

## Architecture

```
curl / HTTP client
      |
      v
API Gateway (HTTP API)  --  POST /tasks
      |
      v
Lambda: producer  ── (ENI in private subnet) ──>  SQS: todolist-queue-<stage>
                                                      |
                                                      v
                                              Lambda: consumer
                                                      |
                                                      v
                                          DynamoDB: users-table-<stage>
```

- **producer** — exposed via API Gateway on `POST /tasks`; receives a task and publishes it to the SQS queue. Attached to the VPC (ENI in `PrivateSubnetA`).
- **consumer** — triggered automatically by SQS messages (event source mapping, batches of up to 10, with `ReportBatchItemFailures`); writes items to DynamoDB. Not attached to the VPC.
- **Networking** — dedicated VPC (`10.0.0.0/16`) with two private subnets (eu-west-3a / eu-west-3b), no NAT Gateway. Security group allowing SSH ingress from the VPC CIDR (for EC2 access via EC2 Instance Connect Endpoint).

## Stack

| Component | Details |
|---|---|
| Runtime | Python 3.12 (provider default), producer on 3.11 |
| Region | eu-west-3 (Paris) |
| IaC | Serverless Framework v4 + CloudFormation resources under `resources:` |
| Storage | DynamoDB, table `users-table-<stage>`, PK `userId` (S), provisioned 1/1 RCU/WCU |
| Messaging | SQS standard queue, `todolist-queue-<stage>`, visibility timeout 30s |
| IAM | Shared role with least-privilege statements: CRUD on the table, SendMessage/ReceiveMessage/DeleteMessage on the queue |

## Project structure

```
.
├── serverless.yml     # service definition + CloudFormation resources
├── producer.py        # POST /tasks handler -> SQS
├── consumer.py        # SQS handler -> DynamoDB
└── README.md
```

## Environment variables (injected via serverless.yml)

| Variable | Value | Used by |
|---|---|---|
| `USERS_TABLE` | `users-table-<stage>` | consumer |
| `QUEUE_URL` | SQS queue URL (`!Ref MyQueue`) | producer |

## Deployment

Requires Node.js, Serverless Framework v4, and configured AWS credentials.

```bash
# deploy to the staging stage
sls deploy --stage staging

# stack info (including the API endpoint)
sls info --stage staging

# full teardown
sls remove --stage staging
```

## Testing

### Via the API (real flow)

```bash
curl -X POST https://<api-id>.execute-api.eu-west-3.amazonaws.com/tasks \
  -H 'Content-Type: application/json' \
  -d '{"userId": "u1", "task": "first task"}'
```

### Direct producer invocation (simulating the API Gateway payload)

```bash
sls invoke --function producer --stage staging \
  --data '{"body": "{\"userId\": \"u1\", \"task\": \"test\"}"}' --log
```

### Manual message into the queue (tests the consumer independently of the producer)

```bash
aws sqs send-message \
  --queue-url $(aws sqs get-queue-url --queue-name todolist-queue-staging \
      --region eu-west-3 --query QueueUrl --output text) \
  --message-body '{"userId": "u1", "task": "manual test"}' \
  --region eu-west-3
```

### Verification

```bash
# live logs
sls logs --function consumer --stage staging --tail

# table contents
aws dynamodb scan --table-name users-table-staging --region eu-west-3
```

## Networking — current state and known limitation

**The producer is attached to a private subnet with no NAT Gateway and no VPC endpoints.** Consequence: invocation via API Gateway works (invocation does not go through the VPC), but the `sqs.send_message()` call inside the handler has no route to the SQS API and hangs until the function timeout (10s), with no explicit network error.

The consumer is not in the VPC, so the `SQS → consumer → DynamoDB` chain works normally.

Possible fixes:

1. **Remove the `vpc:` block from the producer** — the standard approach when a Lambda only talks to public AWS services (SQS, DynamoDB). Simplest option.
2. **VPC Endpoints** — keeps the Lambda in the private subnet:
   - Gateway Endpoint for DynamoDB (free, attached to a route table)
   - Interface Endpoint for SQS (ENI + security group, hourly cost per AZ)

## Notes and lessons learned

- **The Lambda handler** is written as `file.function` (`producer.handler`), not `producer.py`.
- **Lambda in a VPC** requires at least one security group — ENIs cannot exist without one. For Lambda, only egress matters (allow-all by default); it never receives inbound connections on its ENI.
- **`!Ref` on an SQS queue returns the URL**, `!GetAtt ... Arn` returns the ARN. Use the ARN for IAM, the URL for boto3.
- **The `httpApi` event automatically generates** all API Gateway v2 resources (Api, Route, Integration, Stage, Lambda Permission) — no manual declaration needed.
- **SQS consumption** is not done manually: the event source mapping polls the queue, invokes the function with batches, and deletes successfully processed messages. `ReportBatchItemFailures` allows retrying only the failed messages.
- **Visibility timeout ≥ function timeout** (6x recommended), otherwise messages become visible again mid-processing → duplicates.
- **Stack deletion can be slow**: Lambda ENIs in a VPC are removed lazily (10–20+ min) and block deletion of subnets/SGs. You cannot deploy over a stack in `DELETE_IN_PROGRESS`.
