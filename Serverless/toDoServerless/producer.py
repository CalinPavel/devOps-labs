import json
import os
import boto3

sqs = boto3.client("sqs")
QUEUE_URL = os.environ["QUEUE_URL"]


def handler(event, context):
    try:
        body = json.loads(event.get("body") or "{}")
    except json.JSONDecodeError:
        return _response(400, {"error": "body-ul nu e JSON valid"})

    task = body.get("task")
    if not task or not isinstance(task, str):
        return _response(400, {"error": "campul 'task' (string) e obligatoriu"})

    message = {
        "task": task,
        "priority": body.get("priority", "normal"),
    }

    result = sqs.send_message(
        QueueUrl=QUEUE_URL,
        MessageBody=json.dumps(message),
    )

    return _response(201, {"status": "queued", "messageId": result["MessageId"]})


def _response(status, payload):
    return {
        "statusCode": status,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(payload),
    }