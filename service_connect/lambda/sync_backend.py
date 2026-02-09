import os
import json
import logging

import boto3
from botocore.config import Config

logger = logging.getLogger()
logger.setLevel(logging.INFO)

config = Config(connect_timeout=5, read_timeout=10)
ecs = boto3.client("ecs", config=config)


def _get_desired_count_from_event(event: dict) -> int | None:
    """
    CloudTrail event -> detail.requestParameters.desiredCount
    Returns None if not present / unexpected.
    """
    try:
        rp = event.get("detail", {}).get("requestParameters", {}) or {}
        desired = rp.get("desiredCount", None)
        if desired is None:
            return None
        return int(desired)
    except Exception:
        return None


def lambda_handler(event, context):
    logger.info("Received event: %s", json.dumps(event))

    cluster = os.environ["CLUSTER_NAME"]
    frontend_service = os.environ["FRONTEND_SERVICE_NAME"]
    backend_service = os.environ["BACKEND_SERVICE_NAME"]

    # 1) Ensure this is actually for the frontend service (defense-in-depth)
    rp = event.get("detail", {}).get("requestParameters", {}) or {}
    event_service = rp.get("service")
    if event_service and event_service != frontend_service:
        logger.info("Ignoring event: service=%s (expected %s)", event_service, frontend_service)
        return {"status": "ignored", "reason": "not-frontend-service"}

    # 2) Extract desiredCount from event
    desired = _get_desired_count_from_event(event)
    if desired is None:
        logger.warning("No desiredCount found in event; nothing to do.")
        return {"status": "ignored", "reason": "no-desiredCount"}

    logger.info("Frontend desiredCount=%s; ensuring backend matches.", desired)

    # 3) Read backend current desiredCount
    resp = ecs.describe_services(cluster=cluster, services=[backend_service])
    services = resp.get("services", [])
    if not services:
        logger.error("Backend service not found: %s", backend_service)
        raise RuntimeError(f"Backend service not found: {backend_service}")

    current = int(services[0].get("desiredCount", 0))
    logger.info("Backend current desiredCount=%s", current)

    # 4) Update only if needed (idempotent)
    if current == desired:
        logger.info("Backend already in sync. No update needed.")
        return {"status": "ok", "updated": False, "desired": desired, "current": current}

    ecs.update_service(cluster=cluster, service=backend_service, desiredCount=desired)
    logger.info("Updated backend desiredCount -> %s", desired)

    return {"status": "ok", "updated": True, "desired": desired, "previous": current}