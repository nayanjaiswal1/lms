---
kind: quiz
id_key: k8s/config-secrets/quiz
course: fast-kubernetes
section: config-secrets
section_title: "Configuration & Secrets"
section_position: 4
title: 'Quiz: Configuration & Secrets'
position: 3
estimated_minutes: 15
source: []
pass_percentage: 60
duration_minutes: 15
questions:
    - id_key: q1
      type: mcq
      difficulty: beginner
      points: 2
      prompt: Which two mechanisms can a Pod use to consume data from a ConfigMap, based on the myconfigmap example in the lesson?
      multiple: false
      options:
          - text: As environment variables via configMapKeyRef (one key at a time) and as mounted files through a configMap volume
            correct: true
          - text: Only as environment variables; ConfigMaps cannot be mounted as volumes
            correct: false
          - text: Only as mounted volumes; ConfigMaps cannot be exposed as environment variables
            correct: false
          - text: Only through the Kubernetes Dashboard UI, not through Pod spec fields
            correct: false
      explanation: |
          The configmappod example wires myconfigmap two ways: db_server and database are
          injected as environment variables through configMapKeyRef, while the same ConfigMap
          is also mounted at /config through a configMap volume, giving the container both an
          env-var view and a file view of the same data.
    - id_key: q2
      type: mcq
      difficulty: intermediate
      points: 3
      prompt: In the mysecret example, which statement correctly describes the Opaque type and the stringData field together?
      multiple: false
      options:
          - text: Opaque is the default, generic Secret type, and stringData lets you write plain-text values that Kubernetes automatically base64-encodes when it stores the Secret
            correct: true
          - text: stringData values must be pre-encoded in base64 by the user before being added to the YAML
            correct: false
          - text: The Opaque type means the Secret's values are encrypted client-side before being sent to the API server
            correct: false
          - text: Secrets can only be consumed as environment variables, never mounted as a volume
            correct: false
      explanation: |
          mysecret is declared with type Opaque, Kubernetes' default generic Secret type, and
          its db_server, db_username, and db_password values are written under stringData as
          plain text for convenience, with Kubernetes storing them base64-encoded internally.
          The lesson also shows Secrets consumed both as a mounted volume (secretvolumepod) and
          as environment variables via secretKeyRef and envFrom (secretenvpod, secretenvallpod).
    - id_key: q3
      type: coding
      difficulty: intermediate
      points: 5
      prompt: |
          You receive a list of `key=value` pairs, one per line, representing `--from-literal`
          arguments passed to `kubectl create secret generic`. For each pair, print `KEY: VALUE`,
          but if the key contains the substring `password` (case-insensitive), mask the value by
          replacing every character with an asterisk instead of printing it in plain text.

          **Example:**
          ```
          3
          db_server=db.example.com
          db_username=admin
          db_password=P@ssw0rd!
          ```
          Output:
          ```
          db_server: db.example.com
          db_username: admin
          db_password: *********
          ```
      languages:
          - python
          - javascript
      starter_code:
          python: |
              import sys
              lines = sys.stdin.read().split('\n')
              n = int(lines[0])
              for i in range(1, n + 1):
                  key, value = lines[i].split('=', 1)
                  if 'password' in key.lower():
                      print(f"{key}: {'*' * len(value)}")
                  else:
                      print(f"{key}: {value}")
          javascript: |
              const lines = require('fs').readFileSync(0, 'utf8').trim().split('\n');
              const n = parseInt(lines[0]);
              for (let i = 1; i <= n; i++) {
                const idx = lines[i].indexOf('=');
                const key = lines[i].slice(0, idx);
                const value = lines[i].slice(idx + 1);
                if (key.toLowerCase().includes('password')) {
                  console.log(`${key}: ${'*'.repeat(value.length)}`);
                } else {
                  console.log(`${key}: ${value}`);
                }
              }
      test_cases:
          - stdin: |
                3
                db_server=db.example.com
                db_username=admin
                db_password=P@ssw0rd!
            expected: |
                db_server: db.example.com
                db_username: admin
                db_password: *********
            hidden: false
            weight: 1
          - stdin: |
                2
                api_key=abc123
                API_PASSWORD=hunter2
            expected: |
                api_key: abc123
                API_PASSWORD: *******
            hidden: true
            weight: 1
          - stdin: |
                1
                theme=dark
            expected: |
                theme: dark
            hidden: true
            weight: 1
---
