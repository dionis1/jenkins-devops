pipeline {
  agent { label 'docker-kubernetes' }
  options { disableConcurrentBuilds()
    timestamps()
    skipDefaultCheckout(true)
    timeout(time: 60, unit: 'MINUTES')
    buildDiscarder(logRotator(numToKeepStr: '20')) }
  triggers { pollSCM('H/2 * * * *') }
  parameters {
    string(name: 'DOCKERHUB_USER', defaultValue: '1dionisfrangu1', description: 'DockerHub namespace')
    string(name: 'PROD_APPROVERS', defaultValue: '', description: 'Comma-separated Jenkins user IDs allowed to approve production')
    booleanParam(name: 'DEPLOY_PROD', defaultValue: false, description: 'Request manual production approval on master only')
  }
  stages {
    stage('Checkout') {
      steps {
        checkout scm
        script {
          if (!(params.DOCKERHUB_USER ==~ /[a-z0-9][a-z0-9_-]*/)) { error('Set a valid DockerHub namespace') }
          env.REGISTRY = params.DOCKERHUB_USER
          env.IMAGE_TAG = "${env.BUILD_NUMBER}-${sh(script: 'git rev-parse --short=12 HEAD', returnStdout: true).trim()}"
          env.COMPOSE_PROJECT_NAME = "exam-${sh(script: 'printf "%s" "$JOB_NAME" | cksum | cut -d " " -f1', returnStdout: true).trim()}-${env.BUILD_NUMBER}"
          env.DOCKER_CONFIG = "${env.WORKSPACE}/.docker-ci"
        }
      }
    }
    stage('Validate and build') {
      steps {
        sh 'helm lint charts; helm template cinema charts > rendered.yaml'
        sh 'docker compose -f docker-compose.yml -f ci/compose.yaml config -q'
        sh 'docker build -t "$REGISTRY/movie-service:$IMAGE_TAG" movie-service'
        sh 'docker build -t "$REGISTRY/cast-service:$IMAGE_TAG" cast-service'
      }
    }
    stage('Compose integration tests') {
      steps {
        sh 'docker compose -f docker-compose.yml -f ci/compose.yaml up -d --no-build'
        sh '''PORT=$(docker compose -f docker-compose.yml -f ci/compose.yaml port nginx 8080 | cut -d: -f2)
python3 ci/smoke.py "http://127.0.0.1:$PORT"'''
      }
    }
    stage('Publish images') {
      when { not { changeRequest() } }
      steps {
        withCredentials([usernamePassword(credentialsId: 'dockerhub', usernameVariable: 'DH_USER', passwordVariable: 'DH_TOKEN')]) {
          sh 'set +x; printf "%s" "$DH_TOKEN" | docker login -u "$DH_USER" --password-stdin'
          sh 'docker push "$REGISTRY/movie-service:$IMAGE_TAG"; docker push "$REGISTRY/cast-service:$IMAGE_TAG"'
        }
      }
    }
    stage('Deploy dev') {
      when { not { changeRequest() } }
      steps { withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG')]) { sh 'bash ci/deploy.sh dev' } }
    }
    stage('Deploy QA and staging') {
      when { branch 'master' }
      steps { withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG')]) { sh 'bash ci/deploy.sh qa'
        sh 'bash ci/deploy.sh staging' } }
    }
    stage('Manual production approval') {
      when { allOf { branch 'master'
        expression { params.DEPLOY_PROD } } }
      steps {
        script {
          if (!params.PROD_APPROVERS.trim()) { error('Configure PROD_APPROVERS before requesting production') }
          timeout(time: 30, unit: 'MINUTES') {
            input message: "Deploy ${env.IMAGE_TAG} to production?", submitter: params.PROD_APPROVERS
          }
        }
      }
    }
    stage('Deploy production') {
      when { allOf { branch 'master'
        expression { params.DEPLOY_PROD } } }
      steps { withCredentials([file(credentialsId: 'kubeconfig-prod', variable: 'KUBECONFIG')]) { sh 'bash ci/deploy.sh prod' } }
    }
  }
  post {
    always {
      sh 'docker compose -f docker-compose.yml -f ci/compose.yaml logs --no-color > compose.log 2>&1 || true'
      sh 'docker compose -f docker-compose.yml -f ci/compose.yaml down -v --remove-orphans || true'
      sh 'docker logout || true'
      archiveArtifacts artifacts: 'compose.log,rendered.yaml,port-forward.log', allowEmptyArchive: true
    }
  }
}
