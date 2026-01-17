import os
from datetime import datetime, timezone

import boto3
from botocore.exceptions import ClientError
import requests

BUCKET_NAME = "sajad-aws-s3-bucket"

# The internal DNS address exposed by Cloud Map (set in Terraform outputs)
FASTAPI_WRITER_URL = os.getenv(
    "FASTAPI_WRITER_URL",
    "http://model-writer.service.local:8000/csv-count",
).strip()


def count_csv_files(s3_client, bucket: str, prefix: str = "") -> int:
    """
    Counts objects ending with .csv in the given bucket/prefix.
    Uses pagination to handle large buckets.
    """
    paginator = s3_client.get_paginator("list_objects_v2")
    count = 0

    for page in paginator.paginate(Bucket=bucket, Prefix=prefix):
        for obj in page.get("Contents", []):
            key = obj.get("Key", "")
            if key.lower().endswith(".csv"):
                count += 1

    return count

def send_count_to_fastapi(count: int, source: str = "csv-counter-task") -> None:
    """
    Sends the CSV count to the FastAPI writer service.
    """
    payload = {
        "count": count,
        "source": source,
    }

    try:
        response = requests.post(FASTAPI_WRITER_URL, json=payload, timeout=5)
        response.raise_for_status()
        print(f"Successfully sent count ({count}) to FastAPI endpoint.")

    except requests.exceptions.RequestException as e:
        print("Failed to call FastAPI writer service:", e)
        raise


def main() -> None:
    prefix = os.getenv("S3_PREFIX", "").strip()

    try:
        s3_client = boto3.client("s3")
        csv_count = count_csv_files(s3_client, BUCKET_NAME, prefix=prefix)
        
        # Send count to FastAPI writer
        send_count_to_fastapi(csv_count)

    except ClientError as e:
        print("AWS ClientError:", e)
        raise


if __name__ == "__main__":
    main()