# GitHub Actions Self-hosted immutable runner

[![Project Status: WIP – Initial development is in progress, but there has not yet been a stable, usable release suitable for the public.](https://www.repostatus.org/badges/latest/wip.svg)](https://www.repostatus.org/#wip)

This is still work in progress.

Tested Actions runner version: [2.322.0](https://github.com/actions/runner/releases) [2025/3/6]

----

[![Japanese language](images/Japanese.256.png)](https://github.com/kekyo/ga_runner/blob/main/README_ja.md)

## What is this?

GitHub Actions self-hosted runners are convenient, but have you ever thought about running them in an immutable way?

The runners hosted by GitHub are immutable, and are destroyed each time a build is run,
so you can assume a clean build environment.
However, because self-hosted runners cannot directly mimic this behavior,
it is quite troublesome to set up a clean build environment.

This script configures GitHub Actions self-hosted runners to run immutably.
It is very easy to use, and the prepared runner instance is reset each time a job is executed, which improves the reproducibility of CI/CD.

## How it works

This script has been tested on Ubuntu 24.04 host
(it is probably also compatible with recent Ubuntu and Debian, but this has not been tested).
And the runner runs based on [Ubuntu 24.04 docker image](https://hub.docker.com/_/ubuntu/).

The script installs [`podman` (an OSS implementation compatible with Docker)](https://podman.io/)
and builds a self-hosted runner instance on a container.

When the runner finishes executing the job, this container also terminates,
the container is deleted on the spot, and the container is executed again.

`podman` runs as the superuser, but runs as a normal user inside the container (you can also use `sudo`).

This series of actions is registered as a `systemd` service,
so once the host OS starts up, everything is handled automatically.

In other words, as the administrator of the host machine, you don't have to do anything! ...maybe ;)

## How to use it

The script has `sudo` inserted appropriately, so you can start working as a normal user.
We will explain the repository that wants to install the self-hosted runner as `https://github.com/kekyo/foobar`:

1. Clone `ga_runner` repository on your host machine:
   ```bash
   $ git clone https://github.com/kekyo/ga_runner
   ```
2. Build `podman` image (You have to run only once per the host).
   It will be installed `curl` and `podman` automatically:
   ```bash
   $ cd ga_runner
   $ ./build.sh
   ```
3. Pick your repository "Actions runner token" from GitHub.
   It is NOT "personal access token":
   ![Step 1](images/step1.png)
   ![Step 2](images/step2.png)
4. Install runner service by:
   `install.sh <GitHub user name> <GitHub repository name> <Actions runner token>`. For example:
   ```bash
   $ ./install.sh kekyo foobar ABP************************
   ```

Done!

The `systemd` service is named as `github-actions-runner_kekyo_foobar`.
Therefore, to check the service in operation:

```bash
$ sudo systemctl status github-actions-runner_kekyo_foobar
```

Please be careful: The Git local repository contains scripts that are referenced by `systemd`,
so it is necessary to keep it even after installation.

## Storing configuration information

When runner access GitHub for the first time, you will be authenticated using your "Actions runner token".
The results of this authentication will be stored in the `scripts/config/` directory.

If something goes wrong, delete the service using `remove.sh` and start again from the beginning, obtaining a new "Actions runner token".

## Installed packages on the job container

The number of packages installed in the container is minimal.
The list is shown below:

```
sudo, curl, libxml2-utils, git, unzip, libicu-dev
```

See [Dockerfile](scripts/Dockerfile) for detail.

If necessary, you can install additional packages using `apt-get` or other tools within the Actions job YAML script.
In other words, you can control it using only the YAML script without having to rebuild the container image.

## Install multiple runner instance

TODO: WIP

Yes, you can run multiple runner instance on one host OS.
Execute `install.sh` multiple time with different user/repository name.

Even in that case, you only need to run the container image builder (`build.sh`) only once.

## Actions runner package will be cached

The Actions runner try to download latest package version `actions-runner-linux-x64-*.tar.gz`
from official [GitHub Actions runner release repository](https://github.com/actions/runner/releases) each started.

And it will be cached the directory `scripts/runner-cache/` automatically.
When this files are valid to latest, the runner reuse it.

## Redirect HTTP/HTTPS to the proxy server

You may want to cache the HTTP/HTTPS access that the job performs.
These can be redirected to your nearest local proxy server, which will then cache them.
This will speed up the download of packages and content.

The URL to the proxy server is specified as the fourth optional argument to `install.sh`:

```bash
$ ./install.sh kekyo foobar ABP************************ http://proxy.example.com:3128
```

The URL you specify must be a valid hostname that can be accessed from within the runner container.
In other words, please note that `localhost` cannot be used.

### Using squid proxy server

Here is an example configuration for the [`squid` proxy server](https://www.squid-cache.org/) that can be used for this purpose.
This is an example of co-locating `squid` with maximum 1000MB (files each 100MB) disk cache on the machine that hosts `podman`:

```bash
$ sudo apt install squid
$ echo "http_access allow localnet" | sudo tee /etc/squid/conf.d/localnet.conf
$ echo "cache_dir ufs /var/spool/squid 1000 16 256" | sudo tee /etc/squid/conf.d/cache_dir.conf
$ echo "maximum_object_size 100 MB" | sudo tee -a /etc/squid/conf.d/cache_dir.conf
$ sudo systemctl restart squid
```

`podman` can specify the host's virtual network address by using the special `host.containers.internal` FQDN, so you can specify the URL as follows:

```bash
$ ./install.sh kekyo foobar ABP************************ http://host.containers.internal:3128
```

## Remove the runner service

```bash
$ ./remove.sh kekyo foobar
```

----

## TODO

* Supports multiple runner instance on same repository.
* Cache the packages into `runner-cache/` (APT, NPM, NuGet and etc)

## License

MIT
