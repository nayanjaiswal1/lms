---
kind: quiz
id_key: k8s/networking/quiz
course: fast-kubernetes
section: networking
section_title: Networking
section_position: 3
title: 'Quiz: Networking'
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
      prompt: What is the default Service type in Kubernetes, and what is its reachability scope?
      multiple: false
      options:
          - text: ClusterIP is the default type; it is only reachable from within the cluster via a stable internal IP
            correct: true
          - text: NodePort is the default type; it is reachable from outside the cluster via any node's IP
            correct: false
          - text: LoadBalancer is the default type; it automatically provisions a cloud load balancer
            correct: false
          - text: ExternalName is the default type; it maps a Service to a DNS name outside the cluster
            correct: false
      explanation: |
          ClusterIP is the default Service type. It exposes the Service on an internal IP that is
          only reachable from within the cluster, as shown with the backend Service in the
          lesson, reached from a frontend Pod via nslookup and curl, never from outside the
          cluster. NodePort and LoadBalancer extend reachability outward; ClusterIP does not.
    - id_key: q2
      type: mcq
      difficulty: intermediate
      points: 3
      prompt: According to the lesson, why can a LoadBalancer Service only get a real external IP when running on a cloud-managed cluster such as AKS, EKS, or GKE, and not on a local minikube cluster?
      multiple: false
      options:
          - text: Provisioning an external IP requires integration with a cloud provider's load balancer, which a local cluster like minikube does not have
            correct: true
          - text: LoadBalancer Services require an Ingress controller to be installed first
            correct: false
          - text: minikube does not support Services of any type
            correct: false
          - text: LoadBalancer type requires a StatefulSet as the backend workload
            correct: false
      explanation: |
          The lesson notes that a LoadBalancer Service can only be tested with a real
          external-ip on a cloud Kubernetes service (Azure AKS, AWS EKS, GCP GKE), because a
          local cluster has no cloud load balancer to provision one from. NodePort together with
          minikube's tunneling feature is the workaround used locally.
    - id_key: q3
      type: coding
      difficulty: intermediate
      points: 5
      prompt: |
          You are given a list of Ingress path rules, one per line as `PATH SERVICE`, listed in
          priority order, followed by a single request path. A rule matches a request if the
          request path starts with the rule's PATH (Prefix matching, like Kubernetes Ingress
          `pathType: Prefix`). Using the first matching rule in the list, print the Service that
          handles the request. If no rule matches, print `default`.

          **Example:**
          ```
          2
          /blue bluesvc
          /green greensvc
          /blue/health
          ```
          Output: `bluesvc`
      languages:
          - python
          - javascript
      starter_code:
          python: |
              import sys
              lines = sys.stdin.read().split('\n')
              n = int(lines[0])
              rules = []
              for i in range(1, n + 1):
                  parts = lines[i].split()
                  rules.append((parts[0], parts[1]))
              request = lines[n + 1].strip()
              result = 'default'
              for path, service in rules:
                  if request.startswith(path):
                      result = service
                      break
              print(result)
          javascript: |
              const lines = require('fs').readFileSync(0, 'utf8').trim().split('\n');
              const n = parseInt(lines[0]);
              const rules = [];
              for (let i = 1; i <= n; i++) {
                const parts = lines[i].trim().split(/\s+/);
                rules.push([parts[0], parts[1]]);
              }
              const request = lines[n + 1].trim();
              let result = 'default';
              for (const [path, service] of rules) {
                if (request.startsWith(path)) {
                  result = service;
                  break;
                }
              }
              console.log(result);
      test_cases:
          - stdin: |
                2
                /blue bluesvc
                /green greensvc
                /blue/health
            expected: 'bluesvc'
            hidden: false
            weight: 1
          - stdin: |
                2
                /blue bluesvc
                /green greensvc
                /green
            expected: 'greensvc'
            hidden: true
            weight: 1
          - stdin: |
                2
                /blue bluesvc
                /green greensvc
                /red
            expected: 'default'
            hidden: true
            weight: 1
---
