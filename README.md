# GitHub Actions runner in Docker

Ubuntu 24.04 with GitHub Actions Runner 2.337.0, Docker CLI, Buildx, Compose,
curl, Git, GitHub CLI (`gh`), Maven with Java, and Python 3 with pip.
Works with Docker Desktop on Windows in **Linux containers** mode and with
Docker Engine on Linux VPS hosts. The default image targets x86-64.
It uses the host Docker daemon through the mounted socket.

## Windows — Docker Desktop

Start Docker Desktop and select **Linux containers** mode. In PowerShell,
from the repository directory, run:

```powershell
Copy-Item .env.example .env
notepad .env
```

Set the repository URL in `.env`: replace `OWNER` with the repository owner
and `REPOSITORY` with the repository name. Enter a fresh GitHub registration
token from Settings → Actions → Runners → New self-hosted runner.
See “Where to get RUNNER_TOKEN” below for detailed instructions.

Useful links:

- Runner setup URL: `https://github.com/OWNER/REPOSITORY/settings/actions/runners/new?arch=x64&os=linux`. Replace `OWNER` and `REPOSITORY` with your own values (requires access to the repository settings).
- [GitHub documentation: managing self-hosted runners](https://docs.github.com/en/actions/how-tos/manage-runners/self-hosted-runners).

```powershell
docker compose up -d --build
docker compose logs -f runner
```

## Linux — Docker Engine on a VPS or local machine

You need a running Docker Engine with the Docker Compose plugin and permission
to run `docker` commands. From the repository directory, run:

```bash
cp .env.example .env
nano .env
# Replace OWNER/REPOSITORY and enter a fresh RUNNER_TOKEN.
docker compose up -d --build
docker compose logs -f runner
```

If Docker requires administrator privileges, prefix the `docker` commands with
`sudo`. On both systems, Compose mounts `/var/run/docker.sock` so the runner
can build images using the host Docker daemon.

## Where to get RUNNER_TOKEN

The source of `RUNNER_TOKEN` is the **self-hosted runner setup page in the target
GitHub repository's settings**. GitHub generates a registration token there.

1. Sign in to GitHub with an account that has administrator access to the repository.
2. Open the repository specified in `RUNNER_URL` and go to
   **Settings → Actions → Runners → New self-hosted runner**.
3. Select **Linux** and **x64** for the default image. Also select Linux when using
   Docker Desktop on Windows, because the runner runs inside a Linux container.
4. In the **Configure** section, find this command:

   ```sh
   ./config.sh --url https://github.com/OWNER/REPOSITORY --token GENERATED_TOKEN
   ```

5. Copy only the value after `--token` into your local `.env` file:

   ```dotenv
   RUNNER_URL=https://github.com/OWNER/REPOSITORY
   RUNNER_TOKEN=GENERATED_TOKEN
   ```

`OWNER`, `REPOSITORY`, and `GENERATED_TOKEN` are placeholders to replace.
The token must come from the settings of the repository matching `RUNNER_URL`.
It is a runner registration token, distinct from a Personal Access Token (PAT)
and the `GITHUB_TOKEN` used in workflows. The registration token **expires after
one hour**: obtain it shortly before starting the container for the first time.
If it expires before registration, obtain a new token from the same page.
After successful registration, the runner uses credentials saved in the volume,
so a new registration token is not required for every restart.
The token is not included in the built image.

For an organization runner, obtain the token from the **organization settings**:
**Settings → Actions → Runners → New runner → New self-hosted runner**,
and set `RUNNER_URL` to `https://github.com/ORGANIZATION`.

Source for these instructions and the token lifetime:
[GitHub Docs — Adding self-hosted runners](https://docs.github.com/en/actions/how-tos/manage-runners/self-hosted-runners/add-runners).

## Stopping and restarting

In your workflow, use labels such as `runs-on: [self-hosted, Linux, X64, docker]`.
Stop with `docker compose stop` and restart with `docker compose start`.
The `runner-data` volume preserves registration, runner updates, and the work
directory, including when the container is recreated. Do not share this volume
between runners running at the same time.

The URL, name, labels, and group are configured during the first registration.
To change the repository, remove the old runner registration in GitHub, run
`docker compose down -v` (also deletes job data), enter a fresh token, and start
again. Stopping the container does not remove its registration in GitHub.

## Running without Compose

```sh
docker build -t github-runner:local .
docker run -d --name github-runner --restart unless-stopped --env-file .env -v github-runner-data:/runner -v /var/run/docker.sock:/var/run/docker.sock github-runner:local
```

## Parameters

| Parameter | How to pass it | Meaning |
| --- | --- | --- |
| UBUNTU_VERSION | Build argument | Defaults to 24.04 |
| RUNNER_VERSION | Build argument | Defaults to 2.337.0 |
| RUNNER_ARCH | Build argument | x64 or arm64 |
| RUNNER_SHA256 | Build argument | SHA-256 for the selected version and architecture |
| RUNNER_URL | Environment variable | Repository or organization URL |
| RUNNER_TOKEN | Environment variable | Runner registration token |
| RUNNER_TOKEN_FILE | Environment variable | Alternative path to a mounted file containing the token |
| RUNNER_NAME | Environment variable | Defaults to the container hostname |
| RUNNER_LABELS | Environment variable | Comma-separated labels |
| RUNNER_GROUP | Environment variable | Optional organization runner group |
| RUNNER_WORKDIR | Environment variable | Defaults to /runner/_work |

When changing the runner version, also update the checksum from the
[official release](https://github.com/actions/runner/releases/tag/v2.337.0).
For ARM64, use `docker build --platform linux/arm64` with
`--build-arg RUNNER_ARCH=arm64 --build-arg RUNNER_SHA256=...`.
The runner updates automatically; rebuilding the image does not replace the
installation in an existing volume. Ubuntu versions other than 24.04 require
separate package compatibility verification.

## What is tini used for?

`tini` is a small init process that runs as PID 1 inside the container.
It forwards termination signals to the runner and reaps exited child processes,
preventing zombie processes. The `-g` option forwards signals to the runner's
entire process group. This allows the runner to handle termination signals from
`docker stop` and `docker compose stop`. Docker may force termination after the
timeout; stopping the runner during a job can interrupt the workflow.
Compose sets this timeout to two minutes (`stop_grace_period: 2m`).

## Docker in workflows

The runner runs as root and has access to the host Docker daemon: run trusted
workflows. `docker build`, `docker push`, and Buildx use that daemon.
For `container:` jobs, service containers, and custom `docker run -v` commands,
bind mount paths must exist on the daemon host at the same paths as inside the
runner. The default configuration supports jobs running directly in the runner.
Container jobs require shared path configuration. On Linux, for example, mount
`/srv/runner-work:/srv/runner-work` and set `RUNNER_WORKDIR=/srv/runner-work`
before the first registration.
