import json

def handler(event, context):
    batch_item_failures = []

    for record in event["Records"]:
        try:
            body = json.loads(record["body"])
            print(f"Procesez mesaj: {body}")
            # logica ta aici, ex: scriere in DynamoDB
        except Exception as e:
            print(f"Eroare la {record['messageId']}: {e}")
            batch_item_failures.append({"itemIdentifier": record["messageId"]})

    return {"batchItemFailures": batch_item_failures}