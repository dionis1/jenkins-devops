# Validation record

Completed on 2026-10-07:

- Helm chart lint and rendering passed using Helm 4.3.0.
- Full chart Kubernetes server dry-run validation passed with release-prefixed names.
- Docker Compose base + CI override configuration validation passed.
- Shell syntax check and Python compilation passed.
- Minikube started; Kubernetes control-plane node Ready.
- Namespaces dev, qa, staging, prod verified Active.
- Required Jenkins Pipeline, GitHub, credentials, stage view, and SSH agent plugins installed.
- Jenkins controller started and login endpoint returned HTTP 200 at localhost:8081.
- Both service Docker images built successfully.
- Compose integration tests passed: API schemas, PostgreSQL writes/reads,
  cross-service cast lookup, and rejection of nonexistent casts.
- Detected existing unrelated dev workloads; release-prefixed resource names
  prevent collisions with them.
- Fixed legacy Uvicorn/uvloop startup incompatibility by selecting asyncio.

- Source pushed to https://github.com/dionis1/jenkins-devops (master).
- Both images published to DockerHub with tag `exam-ece1188`.
  Movie digest: `sha256:726871bc5e05f17944e33f8c709cf540b0f0f4df84f573ea1693becde60fb50e`.
  Cast digest: `sha256:85726add384c3ae5b20c838fee2f2867ee7da8a2cad491e61db85feb009c8c1c`.
- Scoped Jenkins RBAC and separate database secrets provisioned in all namespaces.

Jenkins execution results:

- `jenkins-devops-exam/master` build #1: SUCCESS; automatic deployment to dev,
  qa and staging; production skipped.
- `jenkins-devops-exam/dev` build #1: SUCCESS; QA, staging and production skipped.
- `jenkins-devops-exam/master` build #2: SUCCESS; requested production release
  paused for manual input, then approved through the signed-in administrator
  session and deployed to prod. All four environments use tag `2-73e0574382a1`
  after this run.
- Production movie, cast and gateway deployments verified ready.
- Evidence PDF contains six screenshots captured directly from live Jenkins.

Operational limits: Kubernetes credential tokens expire 24 hours after their
creation on 7 October 2026. Renew the Jenkins kubeconfig credentials before later
runs. The local agent runtime and work directory are under `/tmp`, so rebuild the
runtime and reconnect the agent after a reboot. This is a local exam installation
using the legacy application dependencies, not a managed production platform.
