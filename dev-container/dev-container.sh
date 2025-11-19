#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTAINER_NAME="libsemigroups-x86-dev"
REPO_PATH="/workspace/libsemigroups"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_usage() {
  cat <<EOF
Usage: $0 <command>

Commands:
    start       Start the dev container
    stop        Stop the dev container
    restart     Restart the dev container
    shell       Open a bash shell in the container
    init        Initialize the cloned repository (first time setup)
    sync        Sync changes from host repository to container
    status      Show container status
    clean       Stop and remove container and volumes
    valgrind    Run valgrind tests in the container (optionally specify test target)
    sanitizer   Run sanitizer tests (asan|tsan|ubsan) in the container (optionally specify test target)
    help        Show this help message

Examples:
    $0 start                    # Start the container
    $0 init                     # Clone repo from host (first time)
    $0 sync                     # Pull changes from host repo
    $0 shell                    # Enter container shell
    $0 valgrind                 # Run valgrind on test_all
    $0 valgrind test_order      # Run valgrind on test_order only
    $0 sanitizer asan           # Run address sanitizer on test_all
    $0 sanitizer asan test_order # Run address sanitizer on test_order
EOF
}

is_running() {
  docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"
}

container_exists() {
  docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"
}

cmd_start() {
  if is_running; then
    echo -e "${YELLOW}Container is already running${NC}"
    return 0
  fi

  echo -e "${GREEN}Starting dev container...${NC}"
  cd "$SCRIPT_DIR"
  docker-compose up -d
  echo -e "${GREEN}Container started successfully${NC}"
  echo -e "${YELLOW}Run '$0 init' if this is your first time to clone the repository${NC}"
  echo -e "${YELLOW}Run '$0 shell' to enter the container${NC}"
}

cmd_stop() {
  if ! is_running; then
    echo -e "${YELLOW}Container is not running${NC}"
    return 0
  fi

  echo -e "${GREEN}Stopping dev container...${NC}"
  cd "$SCRIPT_DIR"
  docker-compose stop
  echo -e "${GREEN}Container stopped${NC}"
}

cmd_restart() {
  cmd_stop
  cmd_start
}

cmd_shell() {
  if ! is_running; then
    echo -e "${RED}Container is not running. Start it with: $0 start${NC}"
    exit 1
  fi

  echo -e "${GREEN}Entering container shell...${NC}"
  docker exec -it "$CONTAINER_NAME" /bin/bash
}

cmd_init() {
  if ! is_running; then
    echo -e "${RED}Container is not running. Start it with: $0 start${NC}"
    exit 1
  fi

  echo -e "${GREEN}Initializing repository in container...${NC}"

  # Check if repo already exists
  if docker exec "$CONTAINER_NAME" test -d "$REPO_PATH/.git"; then
    echo -e "${YELLOW}Repository already exists at $REPO_PATH${NC}"
    read -p "Do you want to remove it and re-clone? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      echo -e "${YELLOW}Initialization cancelled${NC}"
      return 0
    fi
    docker exec "$CONTAINER_NAME" rm -rf "$REPO_PATH"
  fi

  # Clone from the mounted host repository
  docker exec "$CONTAINER_NAME" bash -c "
        git clone /host-repo $REPO_PATH
        cd $REPO_PATH
        echo -e '${GREEN}Repository cloned successfully${NC}'
        echo 'Current branch:' \$(git branch --show-current)
        echo 'Latest commit:' \$(git log -1 --oneline)
    "
}

cmd_sync() {
  if ! is_running; then
    echo -e "${RED}Container is not running. Start it with: $0 start${NC}"
    exit 1
  fi

  if ! docker exec "$CONTAINER_NAME" test -d "$REPO_PATH/.git"; then
    echo -e "${RED}Repository not initialized. Run: $0 init${NC}"
    exit 1
  fi

  echo -e "${GREEN}Syncing changes from host repository...${NC}"

  docker exec "$CONTAINER_NAME" bash -c "
        cd $REPO_PATH
        echo 'Fetching all changes...'
        git fetch /host-repo '+refs/heads/*:refs/remotes/host/*'

        CURRENT_BRANCH=\$(git branch --show-current)
        echo \"Current branch: \$CURRENT_BRANCH\"

        # Check if there are uncommitted changes
        if ! git diff-index --quiet HEAD -- 2>/dev/null; then
            echo -e '${YELLOW}Warning: You have uncommitted changes${NC}'
            git status --short
            read -p 'Stash changes and pull? (y/N) ' -n 1 -r
            echo
            if [[ \$REPLY =~ ^[Yy]$ ]]; then
                git stash
                echo 'Changes stashed'
            else
                echo -e '${YELLOW}Sync cancelled${NC}'
                exit 1
            fi
        fi

        # Pull from host
        echo \"Pulling changes from host/\$CURRENT_BRANCH...\"
        git pull /host-repo \$CURRENT_BRANCH

        echo -e '${GREEN}Sync completed${NC}'
        git log -1 --oneline
    "
}

cmd_status() {
  echo -e "${GREEN}Container Status:${NC}"
  if is_running; then
    echo -e "  Status: ${GREEN}Running${NC}"
    docker exec "$CONTAINER_NAME" bash -c "
            if [ -d '$REPO_PATH/.git' ]; then
                cd $REPO_PATH
                echo '  Repository: Initialized'
                echo \"  Branch: \$(git branch --show-current)\"
                echo \"  Commit: \$(git log -1 --oneline)\"
            else
                echo '  Repository: Not initialized (run: $0 init)'
            fi
        "
  elif container_exists; then
    echo -e "  Status: ${YELLOW}Stopped${NC}"
  else
    echo -e "  Status: ${RED}Not created${NC}"
  fi
}

cmd_clean() {
  echo -e "${RED}This will stop and remove the container and all volumes (including cloned repo)${NC}"
  read -p "Are you sure? (y/N) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled"
    return 0
  fi

  cd "$SCRIPT_DIR"
  docker-compose down -v
  echo -e "${GREEN}Cleaned up successfully${NC}"
}

cmd_valgrind() {
  local TEST_TARGET="${1:-test_all}"
  local TEST_TAGS="${2:-[quick][exclude:no-valgrind]}"

  if ! is_running; then
    echo -e "${RED}Container is not running. Start it with: $0 start${NC}"
    exit 1
  fi

  if ! docker exec "$CONTAINER_NAME" test -d "$REPO_PATH/.git"; then
    echo -e "${RED}Repository not initialized. Run: $0 init${NC}"
    exit 1
  fi

  echo -e "${GREEN}Running valgrind on $TEST_TARGET...${NC}"

  docker exec -it "$CONTAINER_NAME" bash -c "
        cd $REPO_PATH
        mkdir -p m4
        ./autogen.sh
        ./configure --enable-debug --disable-hpcombi
        make -j12
        make $TEST_TARGET -j12
        echo -e '${GREEN}Running valgrind...${NC}'
        valgrind --version
        unbuffer libtool --mode=execute valgrind --leak-check=full --error-exitcode=1 ./$TEST_TARGET '$TEST_TAGS'
    "
}

cmd_sanitizer() {
  local SANITIZER="${1:-}"
  local TEST_TARGET="${2:-test_all}"

  if [[ ! "$SANITIZER" =~ ^(asan|tsan|ubsan)$ ]]; then
    echo -e "${RED}Invalid sanitizer. Choose: asan, tsan, or ubsan${NC}"
    echo "Usage: $0 sanitizer <asan|tsan|ubsan> [test_target]"
    exit 1
  fi

  if ! is_running; then
    echo -e "${RED}Container is not running. Start it with: $0 start${NC}"
    exit 1
  fi

  if ! docker exec "$CONTAINER_NAME" test -d "$REPO_PATH/.git"; then
    echo -e "${RED}Repository not initialized. Run: $0 init${NC}"
    exit 1
  fi

  # Map short names to full names
  case "$SANITIZER" in
  asan) FULL_NAME="address" ;;
  tsan) FULL_NAME="thread" ;;
  ubsan) FULL_NAME="undefined" ;;
  esac

  echo -e "${GREEN}Running $FULL_NAME sanitizer on $TEST_TARGET...${NC}"

  docker exec -it "$CONTAINER_NAME" bash -c "
        cd $REPO_PATH
        mkdir -p m4
        ./autogen.sh
        ./configure CXX='clang++' CXXFLAGS='-fsanitize=$FULL_NAME -fdiagnostics-color -fno-omit-frame-pointer -g -O1'
        make -j12
        make $TEST_TARGET -j12
        echo -e '${GREEN}Running tests with $FULL_NAME sanitizer...${NC}'

        case '$SANITIZER' in
            tsan)
                TSAN_OPTIONS='suppressions=tsan-suppression.cfg' ./$TEST_TARGET '[quick][exclude:no-sanitize-thread]'
                ;;
            ubsan)
                UBSAN_OPTIONS=log_path=ubsan.log ./$TEST_TARGET '[quick][exclude:no-sanitize-undefined]'
                if [ -f ubsan.log* ]; then
                    echo -e '${RED}UndefinedBehaviorSanitizer found issues:${NC}'
                    cat ubsan.log*
                    exit 1
                fi
                ;;
            asan)
                ./$TEST_TARGET '[quick][exclude:no-sanitize-address]'
                ;;
        esac

        echo -e '${GREEN}All tests passed!${NC}'
    "
}

# Main command dispatcher
case "${1:-}" in
start)
  cmd_start
  ;;
stop)
  cmd_stop
  ;;
restart)
  cmd_restart
  ;;
shell)
  cmd_shell
  ;;
init)
  cmd_init
  ;;
sync)
  cmd_sync
  ;;
status)
  cmd_status
  ;;
clean)
  cmd_clean
  ;;
valgrind)
  cmd_valgrind "${2:-}" "${3:-}"
  ;;
sanitizer)
  cmd_sanitizer "${2:-}" "${3:-}"
  ;;
help | --help | -h)
  print_usage
  ;;
*)
  print_usage
  exit 1
  ;;
esac
