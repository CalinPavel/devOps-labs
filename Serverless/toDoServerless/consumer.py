import json
import os
import boto3

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(os.environ["USERS_TABLE"])

def handler(event, context):
    failures = []

    for record in event["Records"]:
        try:
            body = json.loads(record["body"])
            table.put_item(Item={
                "userId": body["userId"],
                "task": body.get("task", ""),
            })
        except Exception as e:
            print(f"Eroare la mesajul {record['messageId']}: {e}")
            failures.append({"itemIdentifier": record["messageId"]})

    return {"batchItemFailures": failures}