# BTP Configuration

## Container Registry
- **Type**: Local only (no ECR push yet)
- **Image prefix**: `pirma-bio-{tool_name}`
- **Local tag format**: `pirma-bio-{tool_name}:{tool_version}`
- **Note**: No ECR repos exist yet. Build and scan locally. Images will be migrated to oamd ECR later.

## Authentication
- **ECR not configured** — local builds only
- When ECR is needed later, will use same AWS ECR at `025066257930.dkr.ecr.us-east-1.amazonaws.com`

## Ticketing
- **System**: GitHub Issues
- **Repo**: `smagala/pirma`
- **Assignee**: smagala
- **Lifecycle**: Update corresponding pirma issue when starting work, comment with results, update on completion
- **No JIRA integration**

## Git Conventions
- **Repo**: `https://github.com/smagala/bfx-dockerfiles`
- **Base branch**: `main`
- **Branch naming**: pirma issue reference (e.g., `pirma-16-ssw`, `pirma-20-irma-core`)
- **One dockerfile per branch**: Yes
- **PR title**: `pirma#{issue}: {tool_name} {tool_version}`
- **PR target**: `main`
- **Post-merge**: Clean up local and remote feature branches, update pirma issue

## Dockerfile Location
- **New dockerfiles**: `{tool_name}/pirma-bio-{tool_name}-{tool_version}.dockerfile`
- **Support files**: `{tool_name}/pirma-bio-{tool_name}-{tool_version}/` subdirectory (for long scripts, patched configs)

## PR Checklist

```
## PR Approval Checklist

- [ ] Final Trivy scan
- [ ] ps installed and available
- [ ] Container runs as non-root user default
- [ ] Tool version verification
```

## AI Review Policy
- **Ignore**: Whitespace on last line, suggestions to immediately update-ca-certificates after install, purely cosmetic changes
- **Consider**: Quality/maintainability improvements, security suggestions, missing runtime deps, layer optimization
- **Ask user**: If unsure whether to implement a suggested fix

## Dockerfile Best Practices

### Base Image
```dockerfile
ARG BASE_IMAGE=025066257930.dkr.ecr.us-east-1.amazonaws.com/oamd-bio-base-ubuntu@sha256:96fa78a49cf6325e61b8820ea227ca85fcf3380b5a11674b2c02e7846312c718
```
Note: Same base image as oamd. SHA changes over time as vulnerabilities are discovered. Check for latest.

### What Base Image Provides (do NOT reinstall)
- `procps` - ps command for NextFlow
- `default` user (UID 1001) - non-root execution
- `WORKDIR /tmp` - read-only rootfs support
- `VOLUME /tmp` - avoid EFS mount issues
- Note: `s5cmd` is NOT included in the base image

### Required in ALL Dockerfiles
- `USER default` as the last directive in final stage
- APT cache mount pattern for all apt-get commands
- No heredocs (`<<EOF`) - use printf/echo/COPY instead
- No LABEL directives
- No CMD directive (except micromamba containers)
- No git in final stage
- Runtime libraries only in final stage (not -dev packages)
- ARGs must be re-declared after each FROM in stages that use them

### HTTPS Access
- Builder stages that download from the internet need `ca-certificates` installed via apt
- Do NOT run `update-ca-certificates` — the base image is kept current; installing the package is sufficient
- The base image does NOT have ca-certificates pre-installed

### APT Cache Mount Pattern
```dockerfile
RUN --mount=target=/var/lib/apt/lists,type=cache,sharing=locked \
    --mount=target=/var/cache/apt,type=cache,sharing=locked \
    rm -f /etc/apt/apt.conf.d/docker-clean \
 && apt-get update \
 && apt-get -y --no-install-recommends install \
      package1 \
      package2
```

### Pip Cache Mount Pattern
```dockerfile
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install package1 package2
```

### Wrapper Scripts
- **Short (< 10 lines)**: `printf '%s\n' 'line1' 'line2' > /path/to/script && chmod 755 /path/to/script`
- **Medium (10-30 lines)**: Multiple `echo 'line' >> /path/to/script` commands
- **Long (> 30 lines)**: Place in `{tool}/pirma-bio-{tool}-{ver}/` subdirectory and `COPY --chmod=755`

### Runtime vs Dev Dependencies
| Builder Stage | Final Stage |
|--------------|-------------|
| build-essential | (omit) |
| libbz2-dev | libbz2-1.0 |
| libcurl4-openssl-dev | libcurl4 |
| liblzma-dev | liblzma5 |
| libncurses-dev | libncurses6 |
| zlib1g-dev | zlib1g |

## Stage Naming Convention

Use consistent stage names across all dockerfiles. Use underscores, not hyphens:

| Stage | Name | Purpose |
|-------|------|---------|
| Python base | `python_builder` | Python + venv setup (no pip packages) |
| Pip compilation | `pip_builder` | Build deps + pip install, inherits from `python_builder` |
| Micromamba base | `micromamba_builder` | Micromamba + conda env setup |
| Compiled tools | `builder` | Generic compilation stage |
| Specific builders | `{tool}_builder` | e.g., `go_builder`, `samtools_builder` |
| Final | `final` | Production image |

## Dockerfile Patterns

### Pattern: Simple Compiled Binary
For C/C++ tools using make, cmake, or autotools (e.g., seqtk, samtools, bedtools).
- Builder stage: build-essential, dev libs, ca-certificates, git
- WORKDIR /build for source builds
- Shallow clone: `git clone --depth 1 --branch v{tag}`
- Final stage: COPY binary, runtime libs only

### Pattern: Python with venv
For pip-installable tools (e.g., multiqc, cutadapt, hostile).
- `python_builder` stage: identical across all containers (layer sharing)
- Install python3.12, python3.12-venv, python3-pip, create venv at /opt/venv
- Do NOT install pip packages in python_builder
- Final stage inherits from python_builder, installs pip packages
- If pip needs compilation: add pip_builder stage, COPY /opt/venv to final

### Pattern: Micromamba/Conda
For tools requiring conda packages (e.g., freyja, gatk).
- micromamba_builder stage sets up environment
- CMD ["/bin/bash", "-l"] required
- Clean pkg cache after pip upgrades: `rm -rf /home/default/micromamba/pkgs`
- Watch for Go binary vulns in conda packages (recompile or rm)

### Pattern: Java
For Maven/Gradle/Ant tools (e.g., trimmomatic, snpeff).
- Builder: JDK + build tool + ca-certificates
- Final: JRE only (openjdk-21-jre-headless)
- Wrapper script using echo/printf (no heredocs)
- For uber-JARs with vulns: JAR surgery may be needed

### Pattern: Pre-compiled Binary
For tools with official release binaries (e.g., spades, fastp, blast).
- Builder: wget/curl + ca-certificates, download binary
- Final: COPY binary, install runtime deps

## Build and Scan
- **Build command**: `docker build -f {tool}/pirma-bio-{tool}-{ver}.dockerfile -t pirma-bio-{tool}:{ver} .` (from repo root)
- **Scan command**: `docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v ~/.trivy/:/root/.cache/trivy aquasec/trivy image --severity HIGH,CRITICAL --no-progress pirma-bio-{tool}:{ver}`
- **Scan threshold**: 0 HIGH, 0 CRITICAL (few exceptions)
- **Container tests** (all mandatory):
  - `whoami` returns `default`
  - Main tool reports correct version
  - `ps --version` succeeds
  - All bundled tools/CLIs work

## Layer Security

Some vulnerability scanners (Clair, quay.io) scan each image layer independently, not just the final filesystem. A vulnerable file that is created in one layer and overwritten in a later layer is still visible in the earlier layer's diff.

**Rule: Every RUN layer must be secure on its own.** Do not rely on a subsequent COPY or RUN to fix vulnerabilities introduced in an earlier layer.

## Known Build Issues
- **pkg_resources missing**: Check for newer tool version with pyproject.toml; if not available, add setuptools
- **GCC 13+ compatibility**: Missing `<cstdint>` (add include), deprecated `std::binary_function` (add CXXFLAGS)
- **Conda Go binary vulns**: Recompile from Go source or rm -f if unused
- **Stale conda pkg cache**: rm -rf /home/default/micromamba/pkgs after pip upgrades
- **Multi-stage pip COPY**: Must copy BOTH site-packages/ AND bin/ from venv
