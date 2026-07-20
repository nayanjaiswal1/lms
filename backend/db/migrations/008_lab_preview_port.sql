-- Live app preview for web-app labs (Django/FastAPI/React sandboxes).
-- preview_port is the port inside the lab container where the lab's
-- application listens; 0 means the lab has no previewable app and the
-- workspace UI shows no preview pane. The labproxy exposes the port to the
-- browser via its authenticated /preview/{token}/ reverse proxy.
ALTER TABLE lab_definitions
  ADD COLUMN preview_port INT NOT NULL DEFAULT 0
  CHECK (preview_port >= 0 AND preview_port <= 65535);
