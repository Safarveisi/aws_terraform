import os
from datetime import datetime, timezone

import boto3
from botocore.exceptions import ClientError


BUCKET_NAME = "sajad-aws-s3-bucket"


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


def upload_report(s3_client, bucket: str, key: str, message: str) -> None:
    """
    Upload a small text file to S3.
    """
    s3_client.put_object(
        Bucket=bucket,
        Key=key,
        Body=message.encode("utf-8"),
        ContentType="text/plain; charset=utf-8",
    )


def main() -> None:
    # Optional: limit counting to a prefix (folder). Default: whole bucket.
    prefix = os.getenv("S3_PREFIX", "").strip()

    # Optional: choose report key. Default includes timestamp to avoid overwriting.
    default_report_key = f"reports/csv_count_{datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')}.txt"
    report_key = os.getenv("REPORT_KEY", default_report_key).strip()

    s3 = boto3.client("s3")

    try:
        csv_count = count_csv_files(s3, BUCKET_NAME, prefix=prefix)

        scope = f"prefix '{prefix}'" if prefix else "the whole bucket"
        message = (
            f"DOCKER username {os.environ['DOCKER_USERNAME']} generated:"
            f"Bucket: {BUCKET_NAME}\n"
            f"Scope: {scope}\n"
            f"CSV files found: {csv_count}\n"
            f"Generated at (UTC): {datetime.now(timezone.utc).isoformat()}\n"
        )

        upload_report(s3, BUCKET_NAME, report_key, message)
        print(f"CSV count: {csv_count}")
        print(f"Report uploaded to s3://{BUCKET_NAME}/{report_key}")

    except ClientError as e:
        # Make errors readable in logs
        print("AWS ClientError:", e)
        raise


if __name__ == "__main__":
    main()