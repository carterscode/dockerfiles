# Suricata Docker Build

This repository provides an automated workflow for building and
publishing Docker images of [Suricata](https://suricata.io/), an
open-source network threat detection engine. It is designed to help
anyone---from complete beginners to advanced users---run Suricata in a
containerized environment.

------------------------------------------------------------------------

## 🚀 What is Suricata?

Suricata is a high-performance, open-source intrusion detection system
(IDS), intrusion prevention system (IPS), and network security
monitoring (NSM) engine. It inspects network traffic in real time and
can detect attacks, malware, and suspicious behavior.

By running Suricata in Docker, you get a portable, reproducible
environment with automatic updates and multi-platform support.

------------------------------------------------------------------------

## ⚙️ Automated Build & Deployment

The build process is fully automated using **GitHub Actions**. Every
time changes are pushed to the repository's `main` branch (or scheduled
daily at 2 AM UTC), the workflow will:

1.  **Build Suricata from source** (including dependencies such as nDPI
    and Rust).
2.  **Package Suricata into a Docker image**.
3.  **Push the image to Docker Hub** under
    [carterfields/suricata](https://hub.docker.com/r/carterfields/suricata).

### Workflow Highlights

-   **Triggers**: Runs on pushes to `main`, daily schedule, or manual
    dispatch.
-   **Platforms**: Builds for both `linux/amd64` and `linux/arm64`.
-   **Tags**:
    -   `carterfields/suricata:stable` → Latest stable build from the
        `main` branch.
    -   `carterfields/suricata:latest` → Alias for stable.
    -   `carterfields/suricata:dev` → Development build from the
        `main-8.0.x` branch.

------------------------------------------------------------------------

## 🛠️ Dockerfile Explained

The `Dockerfile` uses a **multi-stage build**:

### Stage 1: Builder

-   Based on **Debian Bookworm Slim**.
-   Installs required build dependencies (C libraries, compilers, Rust
    toolchain, etc.).
-   Installs `cbindgen` for Rust integration.
-   Builds and installs **nDPI** (Deep Packet Inspection library).
-   Clones and compiles **Suricata** with features enabled:
    -   NFQueue support
    -   nDPI (DPI support)
    -   Rust integration
    -   Systemd support

### Stage 2: Runtime

-   Stripped-down Debian with only necessary runtime libraries.
-   Copies Suricata binaries and configuration files from the builder
    stage.
-   Creates required runtime directories.
-   Default command runs Suricata on `eth0` with
    `/etc/suricata/suricata.yaml`.

------------------------------------------------------------------------

## ▶️ How to Use

### Run Suricata with default settings

``` bash
docker run --rm -it --net=host   -v /var/log/suricata:/var/log/suricata   carterfields/suricata:stable
```

### Specify a custom interface and configuration

``` bash
docker run --rm -it --net=host   -e IFACE=enp0s3   -e CONFIG=/etc/suricata/suricata.yaml   -v /var/log/suricata:/var/log/suricata   carterfields/suricata:stable
```

The container will automatically pick up your chosen interface (`IFACE`)
and configuration file (`CONFIG`).

------------------------------------------------------------------------

## 🔄 Workflow File

The GitHub Actions workflow (`.github/workflows/docker-suricata.yml`) handles the
automation: - Checks out the code. - Sets up Docker Buildx (for
multi-arch builds). - Authenticates with Docker Hub. - Builds and pushes
both stable and development images.

------------------------------------------------------------------------

## 📂 File Overview

-   **Dockerfile** → Instructions for building Suricata in two stages
    (builder + runtime).
-   **entrypoint.sh** → Custom entrypoint script for flexible runtime
    configuration.
-   **.github/workflows/docker-suricata.yml** → GitHub Actions workflow that
    automates builds and pushes to Docker Hub.

------------------------------------------------------------------------

## 🌍 Audience

This repository is designed for **everyone**: - **Security
professionals** → Run Suricata quickly for IDS/IPS testing. -
**Developers** → Experiment with Suricata in local or CI/CD pipelines. -
**Beginners** → No need to compile Suricata yourself; just pull the
Docker image.

------------------------------------------------------------------------

## 📦 Docker Hub

Find the published images here:\
👉
[carterfields/suricata](https://hub.docker.com/r/carterfields/suricata)

------------------------------------------------------------------------

## 🤝 Contributing

Contributions are welcome!\
Feel free to submit issues or pull requests if you'd like to improve the
build process or documentation.

------------------------------------------------------------------------

## 📜 License

This project is released under the **GPLv2 License**, the same license
as Suricata.

------------------------------------------------------------------------

### ✅ Summary

This repository gives you a **turnkey Suricata Docker build system**
with: - Automated daily builds - Multi-platform support - Precompiled
Suricata with nDPI and Rust - Easy-to-run Docker images

Perfect for security labs, home setups, or production use!
