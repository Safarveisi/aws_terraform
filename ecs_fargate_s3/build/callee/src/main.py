import os
import logging
from datetime import datetime, timezone

import boto3
from botocore.config import Config
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO").upper()
logging.basicConfig(level=LOG_LEVEL, format="%(asctime)s %(levelname)s %(message)s")
logger = logging.getLogger("fastapi-writer")

BUCKET_NAME = os.getenv("BUCKET_NAME", "sajad-aws-s3-bucket")

# Reuse client, enable retries (good practice on AWS networks)
s3 = boto3.client("s3", config=Config(retries={"max_attempts": 10, "mode": "standard"}))

app = FastAPI(
  title="CSV Count Writer",
  version="1.0.0",
)

class CsvCountPayload(BaseModel):
  count: int = Field(ge=0, description="Number of CSV files found")
  # Optional metadata if you want
  source: str | None = Field(default=None, description="Caller/source identifier")

@app.get("/health")
def health():
  return {"status": "ok"}

@app.post("/csv-count")
def write_csv_count(payload: CsvCountPayload):
  """
  Receives the CSV count and writes it to S3 as a text file.
  """
  try:
    ts = datetime.now(timezone.utc).isoformat()
    body = f"count={payload.count}\nupdated_at_utc={ts}\n"
    if payload.source:
      body += f"source={payload.source}\n"

    OUTPUT_KEY = f"counts/csv_count_{datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')}.txt"

    s3.put_object(
      Bucket=BUCKET_NAME,
      Key=OUTPUT_KEY,
      Body=body.encode("utf-8"),
      ContentType="text/plain; charset=utf-8",
    )

    logger.info("Wrote csv count to s3://%s/%s (count=%s)", BUCKET_NAME, OUTPUT_KEY, payload.count)
    return {"ok": True, "bucket": BUCKET_NAME, "key": OUTPUT_KEY, "count": payload.count}
  except Exception as e:
    logger.exception("Failed writing to S3")
    raise HTTPException(status_code=500, detail=f"Failed writing to S3: {e}")