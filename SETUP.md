# Jenkins exam setup

The original application is preserved in `movie-service`, `cast-service`, and
`docker-compose.yml`. The supplied chart has been adapted for both APIs, both
databases with persistent volumes, and a gateway. Each namespace gets independent
services, secrets, and storage. Kubernetes namespace names must be lowercase:
`qa` represents the exam's `QA` environment.

## Accounts and source

Create your own GitHub repository (or fork the exam repository), and create two
public DockerHub repositories: `YOUR_USER/movie-service` and
`YOUR_USER/cast-service`. From this directory, change the origin to your repository
and push the `master` branch. Do not submit the upstream URL as your own repository.
Keep secrets out of Git. The application uses legacy dependencies supplied with
the exam; this exercise is not a hardened production deployment.

## Kubernetes

On this workstation Docker, kubectl, Helm 4, and a minikube context are installed.
Minikube has been started and all four namespaces verified Active. To restart
the local cluster later, use `minikube start --driver=docker` and verify `kubectl get nodes`.
Apply environments with `kubectl apply -f infra/namespaces.yaml`.

For each namespace, a Secret has been provisioned using
`python3 infra/bootstrap-secrets.py`. This creates it only when absent and does
not print credentials. The Secret is called `cinema-database-credentials` with four
keys: `movie-password`, `cast-password`, `movie-uri`, `cast-uri`.
URIs must be URL-encoded and match these patterns:

- `postgresql://movie_db_username:PASSWORD@cinema-movie-db/movie_db_dev`
- `postgresql://cast_db_username:PASSWORD@cinema-cast-db/cast_db_dev`

Use different passwords per environment. Create these secrets through a secret
manager or a local file, never through committed manifests. Keep passwords stable
when upgrading: changing a Kubernetes secret does not rotate an existing
PostgreSQL volume's password. Public images avoid registry pull secrets.
Helm deployment scripts require Helm 4 (`--rollback-on-failure`).

## Jenkins: persistent builds and isolated production

Two local Jenkins instances separate branch builds from production credentials:

- http://localhost:8081: multibranch build/test/publish and dev/qa/staging deployments.
- http://localhost:8082: the fixed `production-master` job with manual approval.

The build controller has zero executors. Its inbound agent runs in a persistent
Compose service, with Java 21 and its tools installed in an image. Docker builds
use a separate rootless Docker-in-Docker daemon and volume. Neither the agent nor that
daemon mounts the workstation Docker socket, home directory, or administrator
kubeconfig. The agent and daemon share a network namespace so Compose integration
tests can use their loopback ports. The daemon's unauthenticated Docker API is
bound to loopback in the shared agent/daemon network namespace, with no host
port published. Both deployment clients join Minikube's Docker network to reach
its API; Kubernetes RBAC still controls their namespace access.

The production controller has its own network, Jenkins home, and credentials.
Only its fixed administrator-owned pipeline runs there. It has no Docker socket
or build daemon access. The production credential is removed from the build
controller. Namespace baseline Pod Security also blocks a nonproduction pipeline
from creating privileged/hostPath pods to obtain host administrator credentials.
The daemon runs as UID 1000 with Docker rootless mode. On Ubuntu, a dedicated
AppArmor profile permits its user namespaces without disabling the global
`apparmor_restrict_unprivileged_userns` setting. Docker's official rootless image
still requires the outer container's privileged flag for namespace setup; use
separate hosts for hostile multi-tenant CI.
Reference: https://docs.docker.com/engine/security/rootless/tips/

### First installation

Install Docker Engine with Compose >=2.24.4, Python 3, kubectl, and Helm 4 on the
workstation. Start minikube and apply `infra/namespaces.yaml`, `infra/rbac.yaml`,
and `python3 infra/bootstrap-secrets.py` as described above. Do not place an
administrator kubeconfig inside any Jenkins container.

Start the main controller with:

```sh
docker compose -f infra/jenkins-compose.yaml up -d jenkins
```

Complete its setup at localhost:8081, create administrator `admindf`, and install
Pipeline, Git, GitHub Branch Source, Credentials Binding, Plain Credentials, and
Pipeline Stage View. Restart Jenkins after plugin installation. The startup hook
creates `exam-agent` with label `docker-kubernetes`, one executor, and saves its
remoting secret privately in the controller volume.

Add the `dockerhub` username/password credential using your DockerHub access token.
Then, from the repository root with the workstation's administrator kubeconfig:

```sh
bash infra/install-rootless-profile.sh
bash infra/install-agents.sh
```

The first command requires sudo and installs the dedicated AppArmor profile.
The second builds the tools image, seeds the production instance with the main
controller's installed plugins and initial administrator authentication, generates
both scoped kubeconfigs, and starts all services. On this workstation, the same
existing administrator login initially works at both URLs. Only trusted production
operators should have accounts on the production instance. Keep its job
configuration and `infra/Jenkinsfile.production` administrator-controlled.

Create a Multibranch Pipeline on localhost:8081 pointing to your GitHub repository,
with script path `Jenkinsfile`. Use periodic branch scans or a GitHub webhook.
Protect `master` and restrict who can modify it. For another user's fork, update
the fixed repository URL, DockerHub namespace, and approver ID in
`infra/Jenkinsfile.production`, then rebuild the tools image and recreate production.

### Normal builds and production

Branch builds validate, build, test with Compose, publish images, and deploy dev.
`master` additionally deploys qa and staging and prints the image tag in
`Production handoff`. Pull requests skip publishing and deployment.

To deploy production, sign in at localhost:8082, run `production-master` with that
successful master build's `IMAGE_TAG`, then click Proceed at its approval step.
The production job always checks out lowercase `master` and rejects tags whose
commit suffix differs from its current commit. There are no SCM triggers or
remote build tokens on this job. Only `admindf` (or a Jenkins administrator) can
approve it. If master has advanced, use the successful build for its new commit.
The build controller cannot invoke production with a stored production credential.

### Credential generation and renewal

Run this as the workstation administrator, after active builds have finished:

```sh
bash infra/renew-credentials.sh
```

It creates new 24-hour service-account tokens, installs each credential only on
its designated controller, and restarts both controllers to load them. Their
agents reconnect automatically. It does not run builds or deploy production.
Kubernetes decides the actual allowed token lifetime; the default request is 24h.
Renew before rerunning the project after that period. For generation only:

```sh
python3 infra/generate-kubeconfigs.py --output-dir .jenkins-local/credentials
```

The output files are `nonprod.json` (dev/qa/staging) and `prod.json` (prod), with
permissions 0600. Tokens are never printed. `.jenkins-local/` is Git-ignored and
excluded from image build contexts. If using another Jenkins installation, upload
these as Secret File credentials `kubeconfig` and `kubeconfig-prod` to the separate
build and production controllers respectively.

### Restarting and checking the setup

```sh
docker compose -f infra/jenkins-compose.yaml up -d
docker compose -f infra/jenkins-compose.yaml ps
docker compose -f infra/jenkins-compose.yaml logs --tail=30 agent
```

All four services use `restart: unless-stopped` and persistent volumes. With Docker
configured to start on boot, they recover without an open terminal or `/tmp`
files. Start minikube again if necessary and renew expired tokens. Avoid
`docker compose down -v`: it would delete Jenkins and build storage.

To view the app, run `kubectl -n dev port-forward service/cinema-gateway 8080:8080`
and open `/api/v1/movies/docs` or `/api/v1/casts/docs` at localhost:8080.
Rollout checks quietly retry while their tunnel starts, print an explicit PASS
on success, and print curl/tunnel diagnostics on a real failure.

The original submission screenshots document the earlier successful workflow;
they predate the separate production controller. Capture new evidence if you want
the submission PDF to show this revised setup.

## Recreating evidence

Capture real Jenkins screenshots after successful runs:

1. A complete successful master pipeline through staging.
2. The manual production approval prompt including the image tag.
3. A successful approved production deployment.
4. A non-master build showing production stages skipped.
5. Console output of the integration test and published image tags.

Combine screenshots into `deliverables/jenkins-results.pdf`. Do not substitute
configuration screenshots or fabricated results for executed pipeline evidence.
Write your GitHub URL into `deliverables/github.txt` and your DockerHub profile
URL into `deliverables/dockerhub.txt`. Once these real artifacts exist, run:

```sh
python3 ci/package.py Dionis Frangu Jul26 2026
```

This produces `deliverables/dionis_frangu_jul26_2026.zip` containing the two link
files and the Jenkins results PDF. The packaging script refuses placeholders or
missing evidence. Source code belongs in your GitHub repository.

Reference: https://www.jenkins.io/doc/book/pipeline/syntax/
Helm 4 upgrade: https://helm.sh/docs/helm/helm_upgrade/
