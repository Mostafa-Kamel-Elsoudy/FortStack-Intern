# FortStack-Intern

This repository contains the infrastructure and deployment setup for a simple
Todo‑List application written in Node.js.  The goal of this project is to
demonstrate how to:

- Clone an existing Node.js application and configure it to use your own
  MongoDB database.
- Containerize the application and publish images to a private container
  registry using GitHub Actions (CI).
- Provision a Linux virtual machine (VM) and install Docker & Docker Compose
  using Ansible (configuration as code).
- Deploy the application on the VM with Docker Compose, including health
  checks and automatic updates when new images are published (CD).
- (Bonus) Provide guidance on replacing Docker Compose with Kubernetes and
  using Argo CD for continuous deployment.

## Part 1 – Application setup and containerization

### Clone and configure the application

The application code in this repo originates from
[Ankit6098/Todo‑List‑nodejs](https://github.com/Ankit6098/Todo-List-nodejs).
The server listens on port `4000` and uses MongoDB via Mongoose.  To connect
to your own database you need to provide a `mongoDbUrl` environment
variable.  Do **not** commit real credentials – instead copy `.env.example` to
`.env` and populate the variables:

```sh
cp .env.example .env
# edit .env and set mongoDbUrl to your own connection string
nano .env
```

The `.env` file is ignored by git so your secrets stay local.

### Dockerfile

A Dockerfile is provided in the root of this repository.  It installs Node.js
dependencies and exposes port `4000`.  To build and run locally:

```sh
docker build -t fortstack-intern:latest .
docker run --env-file .env -p 4000:4000 fortstack-intern:latest
```

### GitHub Actions (CI)

A workflow is defined in `.github/workflows/docker-image.yml`.  On every push
to the `main` branch it will:

1. Check out the repository.
2. Authenticate to GitHub Container Registry (GHCR) using the secret
   `GHCR_TOKEN` (create this secret in your repo settings).
3. Build the Docker image and push it to
   `ghcr.io/<your-account>/fortstack-intern:latest`.

You can monitor the workflow runs in the “Actions” tab of your repository.

## Part 2 – VM provisioning with Ansible

You may use any virtualization platform (VirtualBox, VMware, KVM) or any cloud
provider’s free tier to create a small Linux VM.  This repo assumes an
Ubuntu‑based distribution but the tasks can be adapted for other families.

1. Update the `ansible/hosts` file with your VM’s IP address or hostname,
   SSH user and private key.
2. Copy `.env.example` to `.env` and set the `mongoDbUrl` to point at a
   database reachable from the VM.
3. From the `ansible` directory run the playbook:

```sh
cd ansible
ansible-playbook -i hosts playbook.yml
```

The playbook performs these steps:

- Updates package caches and installs Docker Engine, CLI and the compose
  plugin.
- Adds the deployment user to the `docker` group.
- Copies `docker-compose.yml` and the `.env` file to the VM.
- Starts the application using `docker compose up -d`.
- Verifies running containers.

## Part 3 – Deployment with Docker Compose and automatic updates

The `docker-compose.yml` file defines two services:

- **app** – Runs the Node.js application using the image pushed to GHCR.
  It exposes port `4000`, loads environment variables from `.env`, and
  defines a health check via `wget` to ensure the server is responding.
  A label is added so that the update service knows which containers to
  monitor.
- **watchtower** – Uses the lightweight
  [containrrr/watchtower](https://containrrr.dev/watchtower/) image to
  monitor running containers and automatically pull and restart them when
  new images are published.  It polls the registry every 5 minutes
  (`WATCHTOWER_POLL_INTERVAL=300`) and cleans up old images.

**Why watchtower?**  Watchtower is a popular, open‑source tool for
automating container updates.  It integrates easily with Docker Compose,
requires no additional infrastructure and respects restart policies.
When a new image is pushed to your private registry (via the GitHub Actions
workflow), watchtower detects the change and updates the running service
with zero manual intervention.

## Bonus – Kubernetes and Argo CD

To further enhance this setup you can replace Docker Compose with a
lightweight Kubernetes distribution such as
[k3s](https://k3s.io/) or [microk8s](https://microk8s.io/).  Install the
chosen distribution on your VM, then:

1. Write Kubernetes manifests for the deployment, service and a health
   probe.
2. Push the manifests to a separate Git repository or a folder within
   this repo.
3. Install [Argo CD](https://argo-cd.readthedocs.io/) on the cluster and
   create an application pointing at your manifests.
4. Configure Argo CD to watch the image tag in the container registry for
   automatic rollouts (Argo can be integrated with GitHub Actions via
   image updater plugins).

This approach provides declarative, Git‑ops‑style continuous delivery and
fine‑grained control over rollouts, scaling and health monitoring.

## Assumptions and notes

- The playbook assumes a Debian/Ubuntu host.  For other distributions
  adapt the package installation tasks accordingly.
- A MongoDB instance must be reachable from the VM; you can use MongoDB
  Atlas or run it locally in another container.
- Secrets such as database credentials and GHCR tokens are never committed
  to version control.  Use `.env` and GitHub repository secrets instead.
- Replace placeholder values (e.g., VM IP, SSH user, registry owner) with
  your actual details.

Happy hacking!  Feel free to extend this setup with additional
monitoring, logging or CI/CD enhancements.