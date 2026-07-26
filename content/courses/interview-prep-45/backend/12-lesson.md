---
kind: lesson
id_key: interview-prep-45/day-12-backend
course: interview-prep-45
section: backend
section_title: "Backend Engineering"
section_position: 3
title: "AWS S3 and Storage"
position: 12
estimated_minutes: 45
source:
    - 45-day-interview-roadmap.md
---
Every backend system with user-uploaded content eventually needs S3, and interviewers use it to probe whether you understand consistency models and failure handling in a managed service you don't control — not just whether you can call `boto3.upload_file()`. Today: presigned URLs, multipart upload, S3's consistency guarantees, and how to handle its failure modes.

## Why not upload through your server

The naive approach — client sends the file to your API, your API forwards it to S3 — doubles bandwidth cost and ties up an app server/worker for the entire upload duration. The standard pattern is: your server generates a **presigned URL**, the client uploads directly to S3 using it, your server never touches the file bytes.

```python
import boto3
from botocore.config import Config

s3 = boto3.client(
    "s3",
    region_name="us-east-1",
    config=Config(signature_version="s3v4"),
)

def generate_upload_url(bucket: str, key: str, content_type: str, expires_in: int = 300) -> str:
    return s3.generate_presigned_url(
        ClientMethod="put_object",
        Params={"Bucket": bucket, "Key": key, "ContentType": content_type},
        ExpiresIn=expires_in,  # seconds — keep short; a leaked URL is a temporary write hole
    )
```

```python
from fastapi import FastAPI
from pydantic import BaseModel
import uuid

app = FastAPI()

class UploadRequest(BaseModel):
    filename: str
    content_type: str

@app.post("/uploads/presign")
async def presign_upload(req: UploadRequest, current_user=Depends(get_current_user)):
    # namespace the key by user and a random suffix — never trust the client's filename directly
    key = f"uploads/{current_user.id}/{uuid.uuid4()}-{req.filename}"
    url = generate_upload_url("my-bucket", key, req.content_type)
    return {"upload_url": url, "key": key}
```

The client then does a plain `PUT` to `upload_url` with the file bytes and the matching `Content-Type` header — no AWS credentials ever touch the client. **Interview detail worth stating:** the presigned URL only authorizes the specific operation, bucket, key, and (if you set `Content-Type` in the signed params) content type it was generated for — a client can't reuse it to write to a different key or with a different content type; S3 rejects the mismatch.

## Multipart upload for large files

Above ~100MB (AWS recommends multipart starting around there, required above 5GB), split the upload into parts uploaded independently — enables parallelism and resumability if a part fails.

```python
def start_multipart_upload(bucket: str, key: str) -> str:
    response = s3.create_multipart_upload(Bucket=bucket, Key=key)
    return response["UploadId"]

def presign_part_url(bucket: str, key: str, upload_id: str, part_number: int, expires_in: int = 3600) -> str:
    return s3.generate_presigned_url(
        ClientMethod="upload_part",
        Params={
            "Bucket": bucket,
            "Key": key,
            "UploadId": upload_id,
            "PartNumber": part_number,  # 1-indexed, up to 10,000 parts
        },
        ExpiresIn=expires_in,
    )

def complete_multipart_upload(bucket: str, key: str, upload_id: str, parts: list[dict]) -> None:
    # parts: [{"ETag": "...", "PartNumber": 1}, {"ETag": "...", "PartNumber": 2}, ...]
    # ETags come back from each part's PUT response — the client must collect and report them
    s3.complete_multipart_upload(
        Bucket=bucket,
        Key=key,
        UploadId=upload_id,
        MultipartUpload={"Parts": sorted(parts, key=lambda p: p["PartNumber"])},
    )

def abort_multipart_upload(bucket: str, key: str, upload_id: str) -> None:
    # ALWAYS clean up on failure — abandoned multipart uploads still count against storage billing
    s3.abort_multipart_upload(Bucket=bucket, Key=key, UploadId=upload_id)
```

The full flow: server calls `create_multipart_upload` to get an `UploadId`, server presigns a URL per part, client uploads each part directly (in parallel, retrying any that fail individually), client reports back the part ETags, server calls `complete_multipart_upload`. If anything goes wrong, call `abort_multipart_upload` — S3 charges for incomplete multipart parts sitting around, which is exactly why bucket lifecycle rules typically include an "abort incomplete multipart uploads after N days" policy as a safety net.

## Eventual consistency in S3

Historically S3 offered only **eventual consistency for overwrite PUTs and deletes** (a `GET` right after an `overwrite PUT` or `DELETE` could briefly return stale data) while new-object `PUT`s were always strongly consistent. **As of December 2020, AWS made all S3 operations strongly read-after-write consistent** — a `GET` immediately after any successful `PUT`/`DELETE` now reflects that change. This is a genuinely common interview trivia question because it changed a widely-known "fact" about S3; know the current behavior (strong consistency), but also be ready to explain what eventual consistency *means* generally (a write succeeds, but reads may not reflect it immediately, converging eventually) since interviewers may be testing the concept via S3 as the example even if the specific service behavior has moved on.

The consistency question that still matters operationally: **caching and CDNs in front of S3** (CloudFront) still serve stale content until cache invalidation or TTL expiry — that's a real staleness window you need to design around (versioned object keys instead of overwriting, or explicit cache invalidation on update) regardless of S3's own consistency guarantees.

## Handling S3 failures

```python
import time
from botocore.exceptions import ClientError, EndpointConnectionError

def upload_with_retry(bucket: str, key: str, body: bytes, max_attempts: int = 4) -> None:
    for attempt in range(1, max_attempts + 1):
        try:
            s3.put_object(Bucket=bucket, Key=key, Body=body)
            return
        except ClientError as exc:
            error_code = exc.response["Error"]["Code"]
            if error_code in ("SlowDown", "ServiceUnavailable", "InternalError"):
                # transient — retry with exponential backoff
                if attempt == max_attempts:
                    raise
                time.sleep(2 ** attempt)
                continue
            # NoSuchBucket, AccessDenied, etc. — permanent, don't retry
            raise
        except EndpointConnectionError:
            if attempt == max_attempts:
                raise
            time.sleep(2 ** attempt)
```

Categorize S3 errors the same way you'd categorize any external dependency's errors: **transient** (`SlowDown` — you're being throttled, `ServiceUnavailable`, network blips) get retried with backoff; **permanent** (`AccessDenied`, `NoSuchBucket`, `InvalidArgument`) fail immediately since retrying won't change the outcome. `SlowDown` specifically means you've exceeded S3's request-rate limits for that prefix — the fix beyond backoff is spreading keys across more prefixes, since S3 scales request rate partly by key prefix distribution.

For presigned-URL uploads specifically, the failure mode is different: the client's direct `PUT` to S3 can fail without your server ever knowing. The standard mitigation is having the client report completion back to your API (or your server verifying the object exists via `head_object` before trusting an upload is done) rather than assuming success.

## Key takeaways

- Presigned URLs let clients upload directly to S3, skipping your app server entirely for the actual bytes — generate them narrowly scoped (bucket, key, content type) and short-lived.
- Multipart upload splits large files into independently-uploadable, independently-retryable parts; always pair it with an abort-on-failure path and a lifecycle rule to clean up abandoned uploads.
- S3 has been strongly read-after-write consistent for all operations since December 2020 — know this current behavior, but also understand the general eventual-consistency concept since it's often tested as the example.
- CDN/cache layers in front of S3 (CloudFront) introduce their own staleness window independent of S3's own consistency — design with versioned keys or explicit invalidation.
- Categorize S3 errors as transient (retry with backoff: `SlowDown`, `ServiceUnavailable`) vs permanent (fail fast: `AccessDenied`, `NoSuchBucket`) — retrying a permanent error wastes time and hides the real problem.
