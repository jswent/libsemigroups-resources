# x86 Development Container for libsemigroups

This directory contains Docker-based tooling for running x86 (amd64) tests on ARM-based macOS systems. It mimics the GitHub CI environment for sanitizer and valgrind testing.

## Features

- **x86_64 emulation** on ARM-based Macs via Docker
- **Isolated test environment** with cloned repository (separate from host)
- **Easy syncing** of changes from host to container
- **Persistent storage** for development work and ccache
- **Pre-configured** with all CI dependencies (valgrind, sanitizers, etc.)
- **Quick test runners** for valgrind and sanitizers

## Prerequisites

- Docker Desktop for Mac with Rosetta 2 emulation enabled
- Docker Compose (included with Docker Desktop)

## Quick Start

### 1. Start the container

```bash
./dev-container.sh start
```

This will:
- Build the x86 Ubuntu container (first time only)
- Mount your host repository as read-only at `/host-repo`
- Create persistent volumes for workspace and ccache

### 2. Initialize the repository

```bash
./dev-container.sh init
```

This clones your host repository into `/workspace/libsemigroups` inside the container. This is a separate Git repository that you can modify without affecting your host.

### 3. Enter the container

```bash
./dev-container.sh shell
```

You're now in an x86_64 Ubuntu environment!

## Workflow

### Basic Development Flow

```bash
# On host: Make changes to your code
vim src/some-file.cpp

# Commit changes (optional but recommended)
git commit -am "My changes"

# Sync changes to container
./dev-container.sh sync

# Enter container to test
./dev-container.sh shell

# Inside container: build and test
cd /workspace/libsemigroups
make -j4
./test_all
```

### Running Sanitizers

Run sanitizers directly from the host:

```bash
# Address Sanitizer
./dev-container.sh sanitizer asan

# Thread Sanitizer
./dev-container.sh sanitizer tsan

# Undefined Behavior Sanitizer
./dev-container.sh sanitizer ubsan
```

These commands will:
1. Configure the build with the appropriate sanitizer flags
2. Build the project
3. Run the test suite
4. Report any issues found

### Running Valgrind

```bash
./dev-container.sh valgrind
```

This runs the full valgrind memory check as configured in CI.

### Manual Testing Inside Container

```bash
# Enter the container
./dev-container.sh shell

# Navigate to repository
cd /workspace/libsemigroups

# Configure and build
mkdir -p m4 && ./autogen.sh
./configure CXX="clang++" CXXFLAGS="-fsanitize=address -g -O1"
make -j4

# Run specific tests
./test_all "[some-tag]"

# Or run valgrind manually
valgrind --leak-check=full ./test_all "[quick]"
```

## Available Commands

```bash
./dev-container.sh <command>
```

| Command | Description |
|---------|-------------|
| `start` | Start the dev container |
| `stop` | Stop the dev container |
| `restart` | Restart the dev container |
| `shell` | Open a bash shell in the container |
| `init` | Clone repository from host (first time) |
| `sync` | Pull latest changes from host repository |
| `status` | Show container and repository status |
| `clean` | Remove container and all volumes (WARNING: deletes cloned repo) |
| `valgrind` | Run valgrind tests |
| `sanitizer <type>` | Run sanitizer tests (asan, tsan, or ubsan) |
| `help` | Show help message |

## Syncing Changes

There are two ways to sync changes from your host repository to the container:

### From Host (Recommended)

```bash
./dev-container.sh sync
```

### From Inside Container

```bash
cd /workspace/libsemigroups
/host-repo/dev-container/sync-from-host.sh
```

Both methods:
- Fetch all branches from the host repository
- Pull changes for the current branch
- Offer to stash uncommitted changes if present

## Architecture

### Directory Structure

```
Host System:
  /Users/you/Projects/VIP/libsemigroups/     <- Your main repo
    dev-container/
      Dockerfile                              <- Container definition
      docker-compose.yml                      <- Container orchestration
      dev-container.sh                        <- Main management script
      sync-from-host.sh                       <- Sync script for inside container
      README.md                               <- This file

Container:
  /host-repo/                                 <- Host repo (read-only mount)
  /workspace/libsemigroups/                   <- Cloned dev repo
  /root/.ccache/                              <- Persistent ccache
```

### Volumes

- **dev-workspace**: Persistent storage for `/workspace` (contains cloned repository)
- **ccache**: Persistent ccache storage for faster rebuilds

### Why Separate Repositories?

The container uses a separate clone of your repository to:
1. **Match CI behavior**: GitHub Actions checks out a fresh copy
2. **Prevent interference**: Changes in container don't affect host
3. **Allow experimentation**: Test destructive operations safely
4. **Enable clean state**: Easy to reset by re-running `init`

## Tips and Tricks

### Check Container Status

```bash
./dev-container.sh status
```

Shows whether the container is running and the repository state.

### Fast Rebuilds with ccache

The container uses ccache to speed up rebuilds. The cache persists between container restarts.

### Working with Branches

The sync command works with any branch:

```bash
# On host: switch branch
git checkout my-feature-branch

# Sync to container
./dev-container.sh sync

# The container repo will now be on my-feature-branch
```

### Running Multiple Test Suites

```bash
# Run all sanitizers in sequence
for san in asan tsan ubsan; do
  echo "Running $san..."
  ./dev-container.sh sanitizer $san
done

# Run valgrind
./dev-container.sh valgrind
```

### Performance on ARM Macs

x86 emulation on ARM is slower than native. Expect:
- Compilation: ~2-3x slower than native
- Test execution: ~2-4x slower than native
- Still much faster than waiting for CI!

## Troubleshooting

### Container won't start

```bash
# Check Docker is running
docker ps

# Check logs
cd dev-container && docker-compose logs

# Clean and restart
./dev-container.sh clean
./dev-container.sh start
```

### Sync fails

```bash
# Check you've initialized the repo
./dev-container.sh status

# If not initialized:
./dev-container.sh init
```

### Out of disk space

```bash
# Remove unused Docker images/containers
docker system prune -a

# Clean this specific container
./dev-container.sh clean
```

### Tests fail in container but pass on host

This might indicate:
- Architecture-specific bug (x86 vs ARM)
- Memory issue caught by valgrind
- Race condition caught by thread sanitizer

These are valuable findings!

## Comparison with CI

This setup closely mirrors the GitHub Actions sanitizer configuration:

| Feature | CI | Dev Container |
|---------|----|--------------:|
| Architecture | x86_64 | x86_64 |
| OS | Ubuntu 22.04 | Ubuntu 22.04 |
| Compiler | clang++ / g++ | clang++ / g++ |
| Sanitizers | ✓ | ✓ |
| Valgrind | ✓ | ✓ |
| ccache | ✓ | ✓ |

## Cleaning Up

### Remove container but keep volumes

```bash
./dev-container.sh stop
docker-compose down
```

### Remove everything (including cloned repository)

```bash
./dev-container.sh clean
```

## Advanced Usage

### Building with Custom Flags

```bash
./dev-container.sh shell

cd /workspace/libsemigroups
./configure CXX="g++" CXXFLAGS="-O3 -march=native"
make -j4
```

### Accessing Container Files from Host

```bash
# Copy files out of container
docker cp libsemigroups-x86-dev:/workspace/libsemigroups/test.log ./

# Copy files into container
docker cp ./my-test.cpp libsemigroups-x86-dev:/workspace/libsemigroups/
```

### Using Different Ubuntu Versions

Edit `Dockerfile` to change the base image:

```dockerfile
FROM ubuntu:24.04  # or ubuntu:20.04
```

Then rebuild:

```bash
cd dev-container
docker-compose build --no-cache
```
