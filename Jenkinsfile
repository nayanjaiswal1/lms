// Poll GitHub, build, and deploy MindForge to a k3s box.
// DEPLOY_TARGET=local deploys to the machine running this agent;
// user@host deploys to another k3s box over SSH (scripts/deploy-remote-k3s.sh).
// Setup: scripts/setup-jenkins.sh. Secrets file lives in the Jenkins credential
// "mindforge-secrets-env" (never in git).
// Runs cmd; when IMAGE_REGISTRY is ghcr.io/..., logged in first with a throwaway docker config
def registrySh(String cmd) {
  if (params.IMAGE_REGISTRY.startsWith('ghcr.io')) {
    withCredentials([usernamePassword(credentialsId: 'ghcr-token', usernameVariable: 'GHCR_USER', passwordVariable: 'GHCR_TOKEN')]) {
      withEnv(["CMD=${cmd}"]) {
        sh '''
          export DOCKER_CONFIG="$(mktemp -d)"
          trap 'rm -rf "$DOCKER_CONFIG"' EXIT
          echo "$GHCR_TOKEN" | docker login ghcr.io -u "$GHCR_USER" --password-stdin
          bash -c "$CMD"
        '''
      }
    }
  } else {
    sh cmd
  }
}

pipeline {
  agent { label 'built-in' } // must run on the k3s host (docker, kubectl, helm, rsync), not a container agent
  // 180 min: the first run after the lab-debug image changes verifies every platform recipe in 'Lab artifacts';
  // later runs only verify recipes whose hash changed (cache hits are free).
  options { disableConcurrentBuilds(); timeout(time: 180, unit: 'MINUTES'); timestamps(); buildDiscarder(logRotator(numToKeepStr: '20')) }
  triggers { pollSCM('H/2 * * * *') } // LAN-only host: no GitHub webhook can reach it
  environment { KUBECONFIG = "${JENKINS_HOME}/.kube/config" }
  parameters {
    string(name: 'DEPLOY_TARGET', defaultValue: 'local', description: 'local, or user@host of another k3s machine')
    string(name: 'BUILD_AGENT', defaultValue: 'laptop', description: 'Node label that runs Test + app image builds (e.g. laptop). set to built-in to build on the k3s host')
    string(name: 'IMAGE_REGISTRY', defaultValue: 'ghcr.io/nayanjaiswal1', description: 'registry prefix the k3s host can pull from (ghcr.io/<user> logs in with credential ghcr-token); blank = import images into local k3s (only when BUILD_AGENT is built-in)')
    string(name: 'DOMAIN', defaultValue: '', description: 'Hostname to serve on; blank = mindforge.<hostname>.local')
  }
  stages {
    stage('Prepare') {
      steps {
        withCredentials([file(credentialsId: 'mindforge-secrets-env', variable: 'SECRETS_FILE')]) {
          sh 'install -m 600 "$SECRETS_FILE" k8s/overlays/local/secrets.env'
        }
        script {
          env.APP_DOMAIN = params.DOMAIN?.trim() ?: sh(script: 'echo "mindforge.$(hostname).local"', returnStdout: true).trim()
          env.DOMAIN = env.APP_DOMAIN
          env.IMAGE_TAG = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim() // new tag per commit so k3s re-pulls
        }
        sh '''
          if [ -n "$IMAGE_REGISTRY" ]; then
            awk -v r="$IMAGE_REGISTRY" -v t="$IMAGE_TAG" '/^  - name: mindforge-(backend|labproxy|frontend)$/ {print; print "    newName: " r "/" $3; f=1; next} f && /newTag:/ {print "    newTag: " t; f=0; next} {print}' k8s/overlays/local/kustomization.yaml > kustomization.tmp
            mv kustomization.tmp k8s/overlays/local/kustomization.yaml
            # no stage builds mindforge-minio:local; use the pinned upstream image from base
            sed -i '/^  - name: minio\\/minio$/,$d' k8s/overlays/local/kustomization.yaml
          fi
          sed -i "s/mindforge\\.127\\.0\\.0\\.1\\.nip\\.io/${APP_DOMAIN}/g" \
            k8s/overlays/local/configmap-domain.patch.yaml k8s/overlays/local/kustomization.yaml
        '''
      }
    }
    // Tests, cluster setup and image builds are independent of each other; only Deploy needs all of them.
    stage('Test & Build') {
      parallel {
        stage('Backend') {
          steps { sh 'cd backend && go vet ./... && go test ./...' } // host go: internal/testdb needs the host Docker daemon
        }
        stage('Frontend') {
          agent { label params.BUILD_AGENT }
          steps {
            // host dir (user-owned, unlike a named volume) keeps bun's package cache between runs (the container itself is throwaway)
            sh '''
              mkdir -p "$HOME/.cache/mindforge-bun-cache"
              docker run --rm --user "$(id -u):$(id -g)" -v "$PWD/frontend:/app" -v "$HOME/.cache/mindforge-bun-cache:/bun-cache" -w /app -e HOME=/tmp -e BUN_INSTALL_CACHE_DIR=/bun-cache oven/bun:1.3.14 sh -c "bun install --frozen-lockfile && { bun run type-check & t=\\$!; bun run lint & l=\\$!; wait \\$t && wait \\$l; }"
            '''
          }
        }
        stage('Cluster setup') {
          when { expression { params.DEPLOY_TARGET == 'local' } }
          steps {
            sh '''
              bash scripts/setup-k3s-local.sh
              if command -v sysbox-runc >/dev/null; then bash scripts/setup-sysbox-local.sh; fi
            '''
          }
        }
        stage('Backend image') {
          when { expression { params.DEPLOY_TARGET == 'local' } }
          agent { label params.BUILD_AGENT }
          steps { script { registrySh('bash scripts/build-k3s-local-images.sh backend') } }
        }
        stage('Frontend image') {
          when { expression { params.DEPLOY_TARGET == 'local' } }
          agent { label params.BUILD_AGENT }
          steps { script { registrySh('bash scripts/build-k3s-local-images.sh frontend') } }
        }
        // Platform labs are rendered + verified HERE, not in the app (docs/debug-labs.md B5).
        // Only recipes not already in the agent's verify cache (<recipe_hash>-<runtime_id>) run;
        // any failure fails the pipeline. The labset/cache hold graders and fix/cheat overlays:
        // only the new cache entries are stashed (Jenkins-internal) and only reports are archived.
        stage('Lab artifacts') {
          agent { label params.BUILD_AGENT } // needs docker + go; BUILD_AGENT=built-in verifies one sandbox at a time
          environment { LAB_VERIFY_PARALLEL = "${params.BUILD_AGENT == 'built-in' ? '1' : '2'}" }
          steps {
            sh '''
              set -eu
              for tool in docker go; do
                command -v "$tool" >/dev/null || { echo "Lab artifacts: '$tool' is not installed on agent $NODE_NAME (BUILD_AGENT=${BUILD_AGENT}); install it or set BUILD_AGENT=built-in" >&2; exit 1; }
              done
              docker info >/dev/null 2>&1 || { echo "Lab artifacts: the docker daemon is not reachable by the jenkins user on $NODE_NAME" >&2; exit 1; }
              docker network inspect mindforge-labs >/dev/null 2>&1 || docker network create mindforge-labs >/dev/null
              docker build -t mindforge/lab-debug:1 -f lab-images/lab-debug/Dockerfile lab-images
              rid="$(docker run --rm --entrypoint cat mindforge/lab-debug:1 /opt/mindforge/RUNTIME_ID | tr -d '[:space:]')"
              cache="$HOME/.cache/mindforge-lab-verify"
              mkdir -p "$cache"
              ls "$cache" | sort > lab-cache-before.txt
              rm -rf labset lab-cache-new lab-reports && mkdir -p lab-cache-new lab-reports
              (cd backend && go run ./cmd/coursegen blocks verify --parallel "$LAB_VERIFY_PARALLEL" --artifact ../labset \
                --cache "$cache" --prune --runtime-id "$rid" --report ../lab-reports/verify.json --git-sha "$GIT_COMMIT" --ci-build "$BUILD_NUMBER")
              ls "$cache" | sort | comm -13 lab-cache-before.txt - | grep -v '[.]tmp-' | while read -r e; do cp -a "$cache/$e" lab-cache-new/; done
              echo "$rid" > lab-reports/runtime-id
              rm -rf labset lab-cache-before.txt
            '''
            stash name: 'lab-cache-new', includes: 'lab-cache-new/**', allowEmpty: true
            archiveArtifacts artifacts: 'lab-reports/**', allowEmptyArchive: true // reports only; NEVER labset/ or the cache
            sh 'rm -rf lab-cache-new'
          }
        }
        stage('Lab images') {
          when { expression { params.DEPLOY_TARGET == 'local' } }
          steps {
            script {
              // images already in the registry are skipped; rebuild only when this build touched lab-images/
              def labChanged = currentBuild.changeSets.any { cs -> cs.items.any { it.affectedPaths.any { p -> p.startsWith('lab-images/') } } }
              withEnv(["FORCE_LAB_REBUILD=${labChanged ? 1 : 0}"]) { sh 'bash scripts/push-lab-images.sh' }
            }
          }
        }
      }
    }
    // Gate BEFORE Deploy (local target only): merge the new verify-cache entries into the built-in agent's cache and prove every
    // platform recipe has a verified artifact for this environment's lab runtime. A missing or stale artifact
    // fails here, so a backend is never rolled out while its labs cannot be published (no in-app fallback).
    stage('Check labs') {
      when { expression { params.DEPLOY_TARGET == 'local' } }
      steps {
        unstash 'lab-cache-new'
        sh '''
          set -eu
          cache="$JENKINS_HOME/mindforge-lab-verify-cache"
          mkdir -p "$cache"
          if [ -d lab-cache-new ]; then cp -a lab-cache-new/. "$cache/"; fi
          rm -rf labset lab-cache-new
          trap 'rm -rf labset' EXIT
          bash scripts/import-lab-artifacts.sh --target k8s --from-cache "$cache" --assemble-only labset
        '''
      }
    }
    stage('Deploy') {
      steps {
        sh '''
          if [ "$DEPLOY_TARGET" = "local" ]; then
            bash scripts/deploy-k8s.sh local
          else
            bash scripts/deploy-remote-k3s.sh "$DEPLOY_TARGET" "$APP_DOMAIN"
          fi
        '''
      }
    }
    // Publish the CI-verified platform labs into the deployed backend, local or over SSH (DEPLOY_TARGET=user@host).
    // For a local target the cache was already proved complete by 'Check labs'; a remote target has no pre-deploy gate
    // (its lab image is only built inside deploy-remote-k3s.sh), so a missing artifact fails here, after the rollout.
    stage('Import labs') {
      steps {
        unstash 'lab-cache-new'
        sh '''
          set -eu
          cache="$JENKINS_HOME/mindforge-lab-verify-cache"
          mkdir -p "$cache"
          if [ -d lab-cache-new ]; then cp -a lab-cache-new/. "$cache/"; fi
          rm -rf labset lab-cache-new
          trap 'rm -rf labset' EXIT
          if [ "$DEPLOY_TARGET" = "local" ]; then
            bash scripts/import-lab-artifacts.sh --target k8s --from-cache "$cache" labset
          else
            bash scripts/import-lab-artifacts.sh --target k8s --ssh "$DEPLOY_TARGET" --from-cache "$cache" labset
          fi
        '''
      }
    }
    stage('Verify') {
      when { expression { params.DEPLOY_TARGET == 'local' } }
      steps { sh 'bash scripts/verify-k3s-local.sh' }
    }
  }
  post {
    always { sh 'rm -f k8s/overlays/local/secrets.env' }
    success { echo "Deployed: https://${env.APP_DOMAIN}" }
  }
}
