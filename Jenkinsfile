// Poll GitHub, build, and deploy MindForge to a k3s box.
// DEPLOY_TARGET=local deploys to the machine running this agent;
// user@host deploys to another k3s box over SSH (scripts/deploy-remote-k3s.sh).
// Setup: scripts/setup-jenkins.sh. Secrets file lives in the Jenkins credential
// "mindforge-secrets-env" (never in git).
pipeline {
  agent { label 'built-in' } // must run on the k3s host (docker, kubectl, helm, rsync), not a container agent
  options { disableConcurrentBuilds(); timeout(time: 90, unit: 'MINUTES') }
  triggers { pollSCM('H/2 * * * *') } // LAN-only host: no GitHub webhook can reach it
  environment { KUBECONFIG = "${JENKINS_HOME}/.kube/config" }
  parameters {
    string(name: 'DEPLOY_TARGET', defaultValue: 'local', description: 'local, or user@host of another k3s machine')
    string(name: 'BUILD_AGENT', defaultValue: 'built-in', description: 'Node label that runs Test + app image builds (e.g. laptop). Non-default needs IMAGE_REGISTRY')
    string(name: 'IMAGE_REGISTRY', defaultValue: '', description: 'host:port registry the k3s host can pull from; blank = import images into local k3s')
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
        }
        sh '''
          if [ -n "$IMAGE_REGISTRY" ]; then
            awk -v r="$IMAGE_REGISTRY" '{print} /^  - name: mindforge-(backend|labproxy|frontend)$/ {print "    newName: " r "/" $3}' k8s/overlays/local/kustomization.yaml > kustomization.tmp
            mv kustomization.tmp k8s/overlays/local/kustomization.yaml
          fi
          sed -i "s/mindforge\\.127\\.0\\.0\\.1\\.nip\\.io/${APP_DOMAIN}/g" \
            k8s/overlays/local/configmap-domain.patch.yaml k8s/overlays/local/kustomization.yaml
        '''
      }
    }
    stage('Test') {
      parallel {
        stage('Backend') {
          steps { sh 'cd backend && go vet ./... && go test ./...' } // host go: internal/testdb needs the host Docker daemon
        }
        stage('Frontend') {
          agent { label params.BUILD_AGENT }
          steps {
            sh '''
              docker run --rm --user "$(id -u):$(id -g)" -v "$PWD/frontend:/app" -w /app -e HOME=/tmp -e COREPACK_HOME=/tmp/corepack -e npm_config_store_dir=/tmp/pnpm-store node:22 sh -c "corepack enable && pnpm install --frozen-lockfile && pnpm tsc --noEmit && pnpm lint"
            '''
          }
        }
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
    stage('Build images') {
      when { expression { params.DEPLOY_TARGET == 'local' } }
      parallel {
        stage('Backend image') {
          agent { label params.BUILD_AGENT }
          steps { sh 'bash scripts/build-k3s-local-images.sh backend' }
        }
        stage('Frontend image') {
          agent { label params.BUILD_AGENT }
          steps { sh 'bash scripts/build-k3s-local-images.sh frontend' }
        }
        stage('Lab images') { steps { sh 'bash scripts/push-lab-images.sh' } }
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
