import json
import random
import sys

import pycountry

TABLE_NAME = "countries"

n = int(sys.argv[1]) if len(sys.argv) > 1 else 10
tari = random.sample(list(pycountry.countries), n)

requests = [
    {
        "PutRequest": {
            "Item": {
                "nume": {"S": t.name},
                "cod": {"S": t.alpha_2},
                "cod3": {"S": t.alpha_3},
                "numeric": {"S": t.numeric},
            }
        }
    }
    for t in tari
]

print(json.dumps({TABLE_NAME: requests}, indent=2, ensure_ascii=False))
