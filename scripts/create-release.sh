# Don't run directly! Instead, use
# nix run .#create-release

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
cd "$SCRIPT_DIR/.."

version=${1:-}
if [[ -z "$version" ]]; then
  echo "USAGE: nix run .#create-release -- <version>" >&2
  exit 1
fi

# Check if the version matches the semver pattern (without suffixes)
semver_regex="^([0-9]+)\.([0-9]+)\.([0-9]+)$"
if [[ ! "$version" =~ $semver_regex ]]; then
  echo "Version must match the semver pattern (e.g., 1.0.0, 2.3.4)" >&2
  exit 1
fi

if [[ "$(git symbolic-ref --short HEAD)" != "master" ]]; then
  echo "must be on master branch" >&2
  exit 1
fi

# Ensure there are no uncommitted or unpushed changes
uncommited_changes=$(git diff --compact-summary)
if [[ -n "$uncommited_changes" ]]; then
  echo -e "There are uncommited changes, exiting:\n${uncommited_changes}" >&2
  exit 1
fi
git pull git@github.com:nix-community/disko master
unpushed_commits=$(git log --format=oneline origin/master..master)
if [[ "$unpushed_commits" != "" ]]; then
  echo -e "\nThere are unpushed changes, exiting:\n$unpushed_commits" >&2
  exit 1
fi

# Update the version file
echo "{ version = \"$version\"; released = true; }" > version.nix

# Commit and tag the release
git commit -am "release: v$version"
git tag -a "v$version" -m "release: v$version"
git tag -a "latest" -m "release: v$version"

echo "now run 'git push --tags origin master'"
# a revsion suffix when run from the tagged release commit
echo "{ version = \"$version\"; released = false; }" > version.nix
git commit -am "release: reset released flag"

echo "now run 'git push --tags origin master'"
