---
kind: lesson
id_key: interview-prep-45/day-12-backend
course: interview-prep-45
section: backend-apis
section_title: "APIs, Security & Deployment"
section_position: 11
section_group: "Backend"
title: "File Storage with S3"
position: 6
estimated_minutes: 50
source:
    - 45-day-interview-roadmap.md
---

Any backend with user-uploaded content eventually needs a place to put files that isn't your own server's disk. Interviewers use S3 to check something deeper than "can you call `boto3.upload_file()`": whether you understand consistency guarantees and failure handling in a managed service you don't fully control. This lesson covers presigned URLs, multipart upload for large files, what S3's consistency model actually guarantees today, and how to handle its failure modes.

## Why not upload through your own server

Picture a delivery company where every package first gets driven to the company's own office, unpacked, and re-shipped to the warehouse, instead of going straight to the warehouse. That's what happens when a client uploads a file to your API and your API forwards it to S3: you pay for the bandwidth twice, and an app server or worker sits tied up for the entire upload, doing nothing but relaying bytes.

The standard pattern instead: your server hands the client a **presigned URL**, the client uploads directly to S3 using it, and your server never touches the file's bytes at all.

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

The client then does a plain `PUT` to `upload_url` with the file bytes and the matching `Content-Type` header. No AWS credentials ever touch the client. The presigned URL only authorizes the exact operation, bucket, key, and content type it was generated for; a client can't reuse it to write to a different key or with a different content type, S3 rejects the mismatch outright.

> **Remember:** a presigned URL lets the client upload directly to S3 with no AWS credentials of its own, and only for the exact bucket, key, and content type it was signed for.

```knowledge-check
{ "questions": [
    { "id": "backend-apis-s3-presigned-q1", "type": "mcq",
      "prompt": "Why does the server generate a random suffix for the upload key instead of using the client's raw filename directly?",
      "options": [
        {"id":"a","text":"S3 rejects filenames containing spaces"},
        {"id":"b","text":"Trusting the client's filename directly risks collisions and lets a client influence the storage key; a random suffix keeps each upload's key unique regardless of what the client sends"},
        {"id":"c","text":"Random suffixes make uploads faster"},
        {"id":"d","text":"boto3 requires all keys to be UUIDs"}
      ],
      "correct": "b",
      "explanation": "Never trust client input as a storage key verbatim. Two users uploading files with the same name would otherwise collide, and namespacing by user ID plus a random suffix avoids that while keeping the key predictable in shape." }
] }
```

## Multipart upload for large files

Above roughly 100MB, AWS's own recommendation for where multipart starts paying off, and required above 5GB, split the upload into parts uploaded independently. That enables parallelism and lets a single failed part be retried without redoing the whole file.

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

The full flow: the server calls `create_multipart_upload` to get an `UploadId`, presigns one URL per part, the client uploads each part directly, in parallel, retrying any that fail individually, the client reports back each part's ETag, and the server calls `complete_multipart_upload`. If anything goes wrong, call `abort_multipart_upload`. S3 keeps charging for incomplete multipart parts left sitting around, which is exactly why bucket lifecycle rules typically include an "abort incomplete multipart uploads after N days" policy as a safety net.

> **Remember:** multipart upload lets one failed part get retried without redoing the whole file. Always set a lifecycle rule to abort abandoned multipart uploads; S3 bills for them even if they never complete.

```knowledge-check
{ "questions": [
    { "id": "backend-apis-s3-multipart-q1", "type": "mcq",
      "prompt": "During a 20-part multipart upload, part 14 fails once due to a network blip. What has to be redone?",
      "options": [
        {"id":"a","text":"The entire upload must restart from part 1"},
        {"id":"b","text":"Only part 14 needs to be retried; the other 19 parts already uploaded successfully and are unaffected"},
        {"id":"c","text":"The UploadId becomes invalid and a new one must be created"},
        {"id":"d","text":"All parts after 14 must be re-uploaded, but not the ones before it"}
      ],
      "correct": "b",
      "explanation": "Each part uploads independently under the same UploadId. A failed part can simply be retried on its own; the parts that already succeeded remain valid and don't need to be touched again." }
] }
```

## S3's consistency model

Historically, S3 offered only **eventual consistency for overwrite PUTs and deletes**, meaning a `GET` right after an overwrite or a delete could briefly return stale data, while a brand-new object's first `PUT` was always strongly consistent. **As of December 2020, AWS made all S3 operations strongly read-after-write consistent**: a `GET` immediately after any successful `PUT` or `DELETE` now reflects that change. This is a genuinely popular interview trivia question because it overturned a widely known "fact" about S3. Know the current behavior, strong consistency, but also be able to explain what eventual consistency *means* in general, a write succeeds, but a read right afterward might not reflect it yet, converging eventually, since interviewers sometimes use S3 only as an example while really testing the general concept.

One consistency question still matters operationally, though: **a CDN in front of S3** (CloudFront) still serves stale content until its cache invalidates or its TTL expires. That's a real staleness window you have to design around, versioned object keys instead of overwriting, or an explicit cache invalidation on update, regardless of what S3 itself guarantees underneath.

> **Remember:** S3 has been strongly read-after-write consistent for every operation since December 2020. A CDN sitting in front of it is a separate staleness source you still have to design around.

```knowledge-check
{ "questions": [
    { "id": "backend-apis-s3-consistency-q1", "type": "mcq",
      "prompt": "A candidate says \"S3 is only eventually consistent, so a GET right after a PUT might return stale data.\" Is this still accurate?",
      "options": [
        {"id":"a","text":"Yes, this has always been true and remains true today"},
        {"id":"b","text":"No, since December 2020 all S3 operations are strongly read-after-write consistent; a GET right after a successful PUT or DELETE reflects that change"},
        {"id":"c","text":"Yes, but only for objects larger than 5GB"},
        {"id":"d","text":"No, S3 was always strongly consistent and never had this limitation"}
      ],
      "correct": "b",
      "explanation": "Before December 2020, overwrite PUTs and deletes were only eventually consistent. AWS changed this so every S3 operation is now strongly read-after-write consistent, which is exactly why this question is a common trivia trap: the old fact is outdated." }
] }
```

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

Categorize S3 errors the same way you'd categorize any external dependency's errors. **Transient** errors, `SlowDown` (you're being throttled), `ServiceUnavailable`, network blips, get retried with backoff. **Permanent** errors, `AccessDenied`, `NoSuchBucket`, `InvalidArgument`, fail immediately, since retrying changes nothing about the outcome. `SlowDown` specifically means you've exceeded S3's request-rate limit for that key prefix; the fix beyond backoff is spreading keys across more prefixes, since S3 scales its request rate partly by how spread out your prefixes are.

For presigned-URL uploads specifically, there's a different failure mode: the client's direct `PUT` to S3 can fail without your server ever finding out, since your server was never in that request path. The standard mitigation is having the client explicitly report completion back to your API, or having your server verify the object exists with `head_object` before trusting that an upload actually finished.

> **Remember:** retry transient errors like SlowDown with backoff; fail immediately on permanent errors like AccessDenied. For presigned uploads, your server only learns an upload succeeded if the client reports it, or your server checks with head_object.

```knowledge-check
{ "questions": [
    { "id": "backend-apis-s3-failures-q1", "type": "mcq",
      "prompt": "A client uses a presigned URL to upload a file directly to S3, and the upload silently fails partway through due to a client-side network error. How does the server find out?",
      "options": [
        {"id":"a","text":"S3 automatically notifies the server of every failed upload"},
        {"id":"b","text":"It doesn't, unless the client explicitly reports back, or the server later checks whether the object actually exists with head_object; the server was never part of that upload request"},
        {"id":"c","text":"The presigned URL itself expires immediately on any failure"},
        {"id":"d","text":"boto3 raises an exception on the server automatically"}
      ],
      "correct": "b",
      "explanation": "A presigned upload goes directly from client to S3, bypassing the server entirely. The server has no automatic way to know the outcome, so it needs either a client-reported completion signal or its own head_object check to confirm the object landed." }
] }
```
