# Jenkins CI/CD exam project

This repository packages the DataScientest Jenkins exam application as a CI/CD
exercise. It contains two FastAPI services (`movie-service` and `cast-service`),
their Docker Compose setup, a Helm chart, and Jenkins pipelines for validation,
image publishing, and Kubernetes deployments.

## Environments and delivery flow

Kubernetes uses four namespaces: `dev`, `qa` (the lowercase Kubernetes name for
the exam's `QA` environment), `staging`, and `prod`.

The multibranch pipeline in [`Jenkinsfile`](Jenkinsfile) validates the chart and
Compose configuration, builds both images, runs Compose integration tests, and
publishes successful non-PR builds to DockerHub. Branch builds deploy to `dev`;
the `master` branch also deploys to `qa` and `staging`. Production is a separate,
manual deployment: an administrator starts the `production-master` job, supplies
the image tag from a successful current `master` build, and approves the prompt.
The production pipeline is in [`infra/Jenkinsfile.production`](infra/Jenkinsfile.production).

## Run the application locally

Requirements: Docker Engine and the Docker Compose plugin.

```sh
docker compose up -d --build
```

Open the API documentation at:

- Movie service: <http://localhost:8080/api/v1/movies/docs>
- Cast service: <http://localhost:8080/api/v1/casts/docs>

Stop the local stack with `docker compose down`.

## Setup and validation

See [`SETUP.md`](SETUP.md) for the Kubernetes namespaces, Jenkins controllers,
scoped credentials, DockerHub setup, manual production approval, and credential
renewal steps. The setup uses a local Minikube cluster and two Jenkins instances
to isolate production deployment access.

See [`VALIDATION.md`](VALIDATION.md) for the checks performed and the recorded
Jenkins build results. The current evidence files are in [`deliverables/`](deliverables/):
the GitHub and DockerHub links and a PDF with Jenkins evidence. The PDF retains
the captured Jenkins screenshots and includes a written record of the later
successful master build.

To recreate the submission archive after updating those deliverables, run from
the repository root:

```sh
python3 ci/package.py Dionis Frangu Jul26 2026
```

This writes `deliverables/dionis_frangu_jul26_2026.zip` with the two account-link
files and `jenkins-results.pdf`.
