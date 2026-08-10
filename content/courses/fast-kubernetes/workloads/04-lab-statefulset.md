---
kind: lab
id_key: k8s/workloads/lab-statefulset
course: fast-kubernetes
section: workloads
section_title: Workloads & Controllers
section_position: 2
title: 'Lab: StatefulSet'
position: 3
estimated_minutes: 30
source:
    - labs/statefulset/statefulset.yaml
lab_type: terminal
environment: mindforge/lab-k8s:1.31
preview_port: 0
workspace_layout: ""
run_script: ""
max_duration: 60
max_resets: 3
hint_penalty_pct: 10
is_required: true
setup_script: |
    #!/bin/bash
    set -euo pipefail
    kubectl cluster-info >/dev/null 2>&1 || { echo "cluster not ready"; exit 1; }
files:
    - path: statefulset.yaml
      content: "apiVersion: v1\r\nkind: Service\r\nmetadata:\r\n  labels:\r\n    app: cassandra\r\n  name: cassandra\r\nspec:\r\n  clusterIP: None\r\n  ports:\r\n  - port: 9042\r\n  selector:\r\n    app: cassandra\r\n---\r\napiVersion: apps/v1\r\nkind: StatefulSet\r\nmetadata:\r\n  name: cassandra\r\n  labels:\r\n    app: cassandra\r\nspec:\r\n  serviceName: cassandra\r\n  replicas: 2\r\n  selector:\r\n    matchLabels:\r\n      app: cassandra\r\n  template:\r\n    metadata:\r\n      labels:\r\n        app: cassandra\r\n    spec:\r\n      terminationGracePeriodSeconds: 1800\r\n      containers:\r\n      - name: cassandra\r\n        image: gcr.io/google-samples/cassandra:v13\r\n        imagePullPolicy: Always\r\n        ports:\r\n        - containerPort: 7000\r\n          name: intra-node\r\n        - containerPort: 7001\r\n          name: tls-intra-node\r\n        - containerPort: 7199\r\n          name: jmx\r\n        - containerPort: 9042\r\n          name: cql\r\n        resources:\r\n          limits:\r\n            cpu: \"500m\"\r\n            memory: 1Gi\r\n          requests:\r\n            cpu: \"500m\"\r\n            memory: 1Gi\r\n        securityContext:\r\n          capabilities:\r\n            add:\r\n              - IPC_LOCK\r\n        lifecycle:\r\n          preStop:\r\n            exec:\r\n              command: \r\n              - /bin/sh\r\n              - -c\r\n              - nodetool drain\r\n        env:\r\n          - name: MAX_HEAP_SIZE\r\n            value: 512M\r\n          - name: HEAP_NEWSIZE\r\n            value: 100M\r\n          - name: CASSANDRA_SEEDS\r\n            value: \"cassandra-0.cassandra.default.svc.cluster.local\"\r\n          - name: CASSANDRA_CLUSTER_NAME\r\n            value: \"K8Demo\"\r\n          - name: CASSANDRA_DC\r\n            value: \"DC1-K8Demo\"\r\n          - name: CASSANDRA_RACK\r\n            value: \"Rack1-K8Demo\"\r\n          - name: POD_IP\r\n            valueFrom:\r\n              fieldRef:\r\n                fieldPath: status.podIP\r\n        readinessProbe:\r\n          exec:\r\n            command:\r\n            - /bin/bash\r\n            - -c\r\n            - /ready-probe.sh\r\n          initialDelaySeconds: 15\r\n          timeoutSeconds: 5\r\n        volumeMounts:\r\n        - name: cassandra-data\r\n          mountPath: /cassandra_data\r\n  volumeClaimTemplates:\r\n  - metadata:\r\n      name: cassandra-data\r\n    spec:\r\n      accessModes: [ \"ReadWriteOnce\" ]\r\n      storageClassName: standard\r\n      resources:\r\n        requests:\r\n          storage: 1Gi"
# TODO(authoring): add tasks — see content/fast-kubernetes/labs/statefulset/ for the source manifests this lab is based on
tasks: []
---
