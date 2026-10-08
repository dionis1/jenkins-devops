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

## Infrastructure fixes verified on 2026-10-08

- Added a kubeconfig generator that writes only scoped service-account identities
  with mode 0600; regression tests check that administrator key material is excluded.
- Ran `infra/renew-credentials.sh` successfully. Both controllers restarted and
  loaded renewed credentials. Tokens expire on 9 October 2026 at approximately
  09:13 Europe/Tirane time; renew before later builds.
- Replaced the terminal agent with a Compose service and persistent workspace.
  Docker is enabled at boot; the agent reconnects after controller restarts.
- Agent and its separate Docker daemon have no workstation Docker socket or
  administrator kubeconfig mounted. The daemon sees only its own storage and
  the agent workspace. Controller home volumes are separate from the agent.
- Build Jenkins has only `dockerhub` and `kubeconfig`; production Jenkins has only
  `kubeconfig-prod`. The build controller has zero local executors.
- Kubernetes authorization checks: nonprod can patch dev but cannot patch prod;
  prod can patch prod but cannot patch dev.
- A server dry-run privileged pod creation using nonprod credentials was denied
  by namespace baseline Pod Security.
- The production controller's fixed pipeline passed Jenkins Declarative Pipeline
  validation. It checks out master, requires a matching commit suffix in the
  image tag, and waits for administrator approval. No production deployment was
  initiated as part of these infrastructure fixes.
- Rollout regression tests pass for a quiet temporary connection failure followed
  by success, and for a persistent failure with visible error diagnostics.

The evidence PDF and ZIP still contain the original 7 October runs; they have not
been regenerated. The legacy application dependencies and the previously reported
movie-update response bug were outside this change's scope.
