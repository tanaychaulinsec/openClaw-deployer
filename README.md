# OpenClaw EC2 Pipeline

This repo gives you a disposable deployment pipeline for OpenClaw on a small EC2 host.

It is tuned for a `t3.small` with a `16 GB` root volume:

- do not build OpenClaw on the instance
- bootstrap a clean Ubuntu host with Docker
- deploy the OpenClaw container over SSH from GitHub Actions
- keep the service bound to `127.0.0.1:18789`
- let you stop or terminate the box when you are not using it

## Why this shape

OpenClaw's official install docs support Docker for isolated VPS-style deployments, and the security docs recommend treating one gateway host as one trust boundary. The official Docker flow builds a local image named `openclaw:local` from the OpenClaw source tree first; there is not a public `openclaw/openclaw:latest` image to pull. On a `t3.small`, building on the EC2 host is still a bad fit for a tight `2 GB` RAM and `16 GB` disk budget, so the practical next step is to build the image outside the instance and then deploy that built image.

References:

- [OpenClaw Docker install docs](https://docs.openclaw.ai/install/docker)
- [OpenClaw install overview](https://docs.openclaw.ai/install)
- [OpenClaw security guidance](https://docs.openclaw.ai/gateway/security)
- [OpenClaw upstream docker-compose uses `openclaw:local`](https://github.com/openclaw/openclaw/blob/main/docker-compose.yml)

## Repo layout

- [docker/docker-compose.yml](/Users/tanay.chauli/openClaw-deployer/docker/docker-compose.yml) runs OpenClaw with host persistence under `/opt/openclaw/home`
- [deploy/bootstrap-ec2.sh](/Users/tanay.chauli/openClaw-deployer/deploy/bootstrap-ec2.sh) is used as EC2 user data for a fresh Ubuntu instance
- [deploy/deploy-openclaw.sh](/Users/tanay.chauli/openClaw-deployer/deploy/deploy-openclaw.sh) pulls and starts the container on the host
- [deploy/prune-host.sh](/Users/tanay.chauli/openClaw-deployer/deploy/prune-host.sh) frees disk space on the EC2 box
- [.github/workflows/launch-and-deploy.yml](/Users/tanay.chauli/openClaw-deployer/.github/workflows/launch-and-deploy.yml) creates a new EC2 instance and deploys OpenClaw
- [.github/workflows/deploy-to-existing-ec2.yml](/Users/tanay.chauli/openClaw-deployer/.github/workflows/deploy-to-existing-ec2.yml) redeploys to an already running instance
- [.github/workflows/stop-or-terminate-ec2.yml](/Users/tanay.chauli/openClaw-deployer/.github/workflows/stop-or-terminate-ec2.yml) stops or terminates the instance by tag

## GitHub secrets you need

Create these repository secrets before running the workflows:

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_REGION`
- `EC2_SUBNET_ID`
- `EC2_SECURITY_GROUP_ID`
- `EC2_KEY_PAIR_NAME`
- `EC2_SSH_PRIVATE_KEY`
- `OPENCLAW_GATEWAY_PASSWORD`
- `MODEL_BACKEND_URL` if you want OpenClaw to talk to a remote model backend

## Expected AWS setup

Before using the workflows, create:

- a VPC/subnet that can assign a public IP
- a security group that allows `22/tcp` from your IP
- an EC2 key pair whose private key is saved in `EC2_SSH_PRIVATE_KEY`

Do not expose `18789` publicly unless you are intentionally putting a reverse proxy and auth in front of it.

## How to use it

### 1. Launch and deploy

Run the GitHub Actions workflow `Launch And Deploy OpenClaw`.

Inputs:

- `instance_name`: tag for the disposable instance, for example `openclaw-ephemeral`
- `instance_type`: leave as `t3.small`
- `volume_size`: leave as `16`
- `ssh_user`: `ubuntu`
- `openclaw_image`: use a real image you built and published yourself, or keep `openclaw:local` only if you load that image onto the host before deploy
- `public_base_url`: leave blank unless you have your own HTTPS reverse proxy
- `ami_id`: optional override

The workflow will:

- create a new Ubuntu instance
- install Docker with cloud-init
- upload the compose file and env file
- try to start OpenClaw using the image name you provide

## Important correction

The first version of this scaffold used `openclaw/openclaw:latest`. That image does not currently exist publicly.

The official OpenClaw Docker docs and the upstream compose file expect a locally built image:

```bash
docker build -t openclaw:local -f Dockerfile .
```

That means this deployment repo still needs one more step before it is production-ready:

- either build OpenClaw from source in GitHub Actions and transfer the image to EC2
- or publish your own image to a registry you control and set `openclaw_image` to that image

### 2. Access OpenClaw safely

Use an SSH tunnel from your laptop:

```bash
ssh -i /path/to/your-key.pem -L 18789:127.0.0.1:18789 ubuntu@EC2_PUBLIC_IP
```

Then open:

```text
http://127.0.0.1:18789
```

### 3. Redeploy later

If the instance is still running, use `Deploy To Existing EC2`.

### 4. Stop or terminate when idle

Run `Stop Or Terminate EC2`.

- `stop` keeps the root EBS volume and is faster to resume
- `terminate` deletes the instance and its root disk because `DeleteOnTermination=true` is set

## Data persistence warning

This setup stores OpenClaw state on the EC2 root volume at `/opt/openclaw/home`.

That means:

- `stop`: data stays
- `terminate`: data is lost

If you want disposable compute but durable OpenClaw state, move `/opt/openclaw/home` to a separate EBS volume or snapshot the volume before termination.

## Notes for a small instance

- Keep only one OpenClaw container on the host.
- Avoid local model inference on the same `t3.small`.
- Keep the port loopback-only and access through SSH.
- Use the included cleanup script if disk starts filling:

```bash
ssh -i /path/to/your-key.pem ubuntu@EC2_PUBLIC_IP 'bash /opt/openclaw/prune-host.sh'
```
