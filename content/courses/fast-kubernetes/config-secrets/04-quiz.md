---
kind: quiz
id_key: k8s/config-secrets/quiz
course: fast-kubernetes
section: config-secrets
section_title: ConfigMaps & Secrets
section_position: 5
title: 'Quiz: ConfigMaps & Secrets'
position: 3
estimated_minutes: 10
source:
  - K8s-Configmap.md
  - K8s-Secret.md
pass_percentage: 70
duration_minutes: 15
questions:
  - id_key: q1
    type: mcq
    difficulty: beginner
    points: 1
    prompt: Which object should hold a feature setting like LOG_LEVEL=debug?
    options:
      - text: Secret
        correct: false
      - text: ConfigMap
        correct: true
      - text: PersistentVolume
        correct: false
      - text: Service
        correct: false
    explanation: Non-sensitive settings belong in a ConfigMap. Secrets are for passwords, tokens and keys.
  - id_key: q2
    type: mcq
    difficulty: beginner
    points: 1
    prompt: What are the two ways a pod can consume a ConfigMap or Secret?
    options:
      - text: As environment variables or as files in a mounted volume
        correct: true
      - text: As a Service or as an Ingress
        correct: false
      - text: As a label or as an annotation
        correct: false
      - text: Only through the Kubernetes API from inside the app
        correct: false
    explanation: env/envFrom for variables, and a configMap/secret volume for files.
  - id_key: q3
    type: mcq
    difficulty: intermediate
    points: 1
    prompt: A ConfigMap is mounted as a volume (without subPath). You change one of its values. What happens to the file in the running pod?
    options:
      - text: It never changes
        correct: false
      - text: It is updated automatically after a short delay
        correct: true
      - text: The pod is restarted automatically
        correct: false
      - text: The file is deleted
        correct: false
    explanation: The kubelet refreshes mounted ConfigMap files, usually within a minute. Environment variables and subPath mounts do not update.
  - id_key: q4
    type: mcq
    difficulty: beginner
    points: 1
    prompt: How are values stored in the `data` field of a Secret?
    options:
      - text: Encrypted with AES
        correct: false
      - text: Base64-encoded, which anyone with read access can decode
        correct: true
      - text: Hashed, so they cannot be read back
        correct: false
      - text: As plain text
        correct: false
    explanation: base64 is just encoding. Protect Secrets with RBAC, encryption at rest, and external secret tools.
  - id_key: q5
    type: mcq
    difficulty: intermediate
    points: 1
    prompt: A pod references a ConfigMap key that does not exist, and the reference is not optional. What happens?
    options:
      - text: The variable is set to an empty string
        correct: false
      - text: The container does not start (CreateContainerConfigError)
        correct: true
      - text: Kubernetes creates the key with a default value
        correct: false
      - text: The pod runs on a different node
        correct: false
    explanation: Missing required config keeps the container from starting. Mark the reference optional true if it may be absent.
  - id_key: q6
    type: mcq
    difficulty: beginner
    points: 1
    prompt: Which Secret type lets the kubelet pull images from a private registry?
    options:
      - text: kubernetes.io/tls
        correct: false
      - text: kubernetes.io/dockerconfigjson, referenced in imagePullSecrets
        correct: true
      - text: Opaque, referenced in envFrom
        correct: false
      - text: kubernetes.io/service-account-token
        correct: false
    explanation: Create it with kubectl create secret docker-registry and list it under imagePullSecrets in the pod spec.
  - id_key: q7
    type: mcq
    difficulty: intermediate
    points: 1
    prompt: What is a safe way to keep Secret definitions in Git?
    options:
      - text: Commit the Secret YAML with base64 values
        correct: false
      - text: Use Sealed Secrets, SOPS, or the External Secrets Operator with a vault
        correct: true
      - text: Put passwords in a ConfigMap instead
        correct: false
      - text: Rename the file to .secret.yaml
        correct: false
    explanation: These tools keep only encrypted data or references in Git; the real values are decrypted or fetched inside the cluster.
---
