import json
import urllib.parse
import logging
import urllib.request
import urllib.error

logger = logging.getLogger()
logger.setLevel(logging.INFO)

MODEL_WRITER_URL = "http://model-writer.service.local:8000/csv-count"

def lambda_handler(event, context):
    logger.info("Received event: %s", json.dumps(event))

    try:
        bucket = event["detail"]["bucket"]["name"]
        raw_key = event["detail"]["object"]["key"]
        key = urllib.parse.unquote_plus(raw_key)

        logger.info("S3 upload detected: bucket=%s key=%s", bucket, key)

        payload = {"count": 1, "source": "lambda-function"}
        data = json.dumps(payload).encode("utf-8")

        req = urllib.request.Request(
            MODEL_WRITER_URL,
            data=data,
            headers={"Content-Type": "application/json"},
            method="POST",
        )

        # Keep timeouts explicit to avoid “hanging” Lambdas
        with urllib.request.urlopen(req, timeout=5) as resp:
            resp_body = resp.read().decode("utf-8", errors="replace")
            status = getattr(resp, "status", 200)

        logger.info("Model-writer response: status=%s body=%s", status, resp_body)

        return {
            "statusCode": 200,
            "body": json.dumps({
                "bucket": bucket,
                "key": key,
                "model_writer_status": status,
                "model_writer_body": resp_body,
            })
        }

    except KeyError as e:
        logger.warning("Missing expected field %s. Event was: %s", e, json.dumps(event))
        return {"statusCode": 400, "body": json.dumps({"error": f"Missing field: {str(e)}"})}

    except urllib.error.HTTPError as e:
        err_body = e.read().decode("utf-8", errors="replace") if hasattr(e, "read") else str(e)
        logger.exception("HTTP error calling model-writer: %s %s", getattr(e, "code", "n/a"), err_body)
        return {"statusCode": 502, "body": json.dumps({"error": "model-writer HTTPError", "detail": err_body})}

    except Exception as e:
        logger.exception("Unexpected error calling model-writer: %s", str(e))
        return {"statusCode": 502, "body": json.dumps({"error": "model-writer call failed", "detail": str(e)})}