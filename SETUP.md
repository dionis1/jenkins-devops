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

For each namespace, provision a Secret called `database-credentials` with four
keys: `movie-password`, `cast-password`, `movie-uri`, `cast-uri`.
URIs must be URL-encoded and match these patterns:

- `postgresql://movie_db_username:PASSWORD@movie-db/movie_db_dev`
- `postgresql://cast_db_username:PASSWORD@cast-db/cast_db_dev`

Use different passwords per environment. Create these secrets through a secret
manager or a local file, never through committed manifests. Keep passwords stable
when upgrading: changing a Kubernetes secret does not rotate an existing
PostgreSQL volume's password. Public images avoid registry pull secrets.
Helm deployment scripts require Helm 4 (`--rollback-on-failure`).

## Jenkins

The persistent controller has been started and responds at localhost:8081.
To start it again later:

```sh
docker compose -f infra/jenkins-compose.yaml up -d
```

Open http://localhost:8081 and complete the setup wizard. Get the initial password
locally with `docker compose -f infra/jenkins-compose.yaml exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword`.
Install Pipeline, Git, GitHub Branch Source, Credentials Binding, and Pipeline
Stage View. Configure a Linux agent named/labeled `docker-kubernetes`, with Java
21, Git, Python 3, curl, Docker Engine access, Docker Compose >=2.24.4, kubectl,
and Helm 4. The controller container does not include these agent tools.
Use Jenkins's SSH agent launch method or its generated inbound-agent command.
The agent must reach the cluster API; a container cannot use a localhost-only
kubeconfig endpoint. Limit the agent to one executor because deployment smoke
tests use local port 18080.

Apply `infra/rbac.yaml` once as a cluster administrator. It binds a shared
deployment role only within each designated namespace, using separate nonprod
and prod service accounts. Provision kubeconfigs for those identities using your
cluster authentication method; short-lived tokens need renewal. Do not use your
cluster-admin kubeconfig for routine Jenkins builds.

Add Jenkins credentials:

- `dockerhub`: username/password; use a DockerHub access token as the password.
- `kubeconfig`: secret file permitting deployment into dev, qa, staging.
- `kubeconfig-prod`: separate secret file permitting deployment into prod.

Create a Multibranch Pipeline pointing to **your** GitHub repository, with script
path `Jenkinsfile`. Protect `master` in GitHub and restrict edits to the Jenkins
job and production credentials. Jenkins administrators can approve input steps;
set `PROD_APPROVERS` to the designated approver user IDs. Scan the repository
initially and configure periodic branch scans (e.g. every minute), or configure
GitHub's Jenkins webhook for a reachable Jenkins endpoint.

Set `DOCKERHUB_USER` on the first build. Normal builds run chart validation,
image builds, isolated Compose integration tests, publish immutable build/commit
tags, and deploy dev. Pull requests skip publishing and deployments. `master`
builds additionally promote the same images to qa and staging. Production requires
`DEPLOY_PROD=true`, an authorized manual approval, and the `master` branch.
No automatic production deployment occurs. The exact branch is lowercase
`master`, matching the upstream repository; rename the condition if your actual
branch is capitalized `Master`.

After deployment, view an environment:

```sh
kubectl -n dev port-forward service/gateway 8080:8080
```

Then open `/api/v1/movies/docs` and `/api/v1/casts/docs` at localhost:8080.
The Compose integration test checks database writes, reads, service-to-service
cast validation, and rejection of nonexistent casts. Deployment checks verify
readiness and movie database access without inserting production test records.

## Required evidence and submission

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
