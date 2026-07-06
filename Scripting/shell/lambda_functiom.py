import json
import boto3

dynamodb = boto3.resource("dynamodb", region_name="eu-west-3")
table = dynamodb.Table("countries")

def lambda_handler(event, context):
    response = table.scan()
    items = response["Items"]

    while "LastEvaluatedKey" in response:
        response = table.scan(ExclusiveStartKey=response["LastEvaluatedKey"])
        items.extend(response["Items"])

    return {
        "statusCode": 200,
        "body": json.dumps(items, default=str),
        "count": len(items),
    }