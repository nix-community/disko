{
  writeShellApplication,
  bash,
  coreutils,
  git,
  gh,
  nix-fast-build,
}:
writeShellApplication {
  name = "create-release";
  runtimeInputs = [
    bash
    git
    gh
    coreutils
    nix-fast-build
  ];
  text = ''
    set -x

    version=''${1:-}
    if [[ -z "$version" ]]; then
      echo "USAGE: nix run .#create-release -- <version>" >&2
      exit 1
    fi

    # Check if we're running from the root of the repository
    if [[ ! -f "flake.nix" || ! -f "version.nix" ]]; then
      echo "This script must be run from the root of the repository" >&2
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
      echo -e "There are uncommited changes, exiting:\n''${uncommited_changes}" >&2
      exit 1
    fi
    git pull git@github.com:nix-community/disko master
    unpushed_commits=$(git log --format=oneline origin/master..master)
    if [[ "$unpushed_commits" != "" ]]; then
      echo -e "\nThere are unpushed changes, exiting:\n$unpushed_commits" >&2
      exit 1
    fi

    branch_name="release/v$version"

    # Check if branch already exists
    if git show-ref --verify --quiet "refs/heads/$branch_name"; then
      echo "Branch $branch_name already exists locally, please delete it first" >&2
      exit 1
    fi

    # Check if tag already exists (locally or remotely)
    if git show-ref --verify --quiet "refs/tags/v$version" || git ls-remote --tags origin "v$version" | grep -q .; then
      echo "Tag v$version already exists, aborting" >&2
      exit 1
    fi

    # Create release branch
    git checkout -b "$branch_name"

    # Update the version file
    cat > version.nix <<EOF
    {
      version = "$version";
      released = true;
    }
    EOF

    # Commit the release version bump
    git commit -am "release: v$version"

    # Push branch and create PR
    git push -u origin "$branch_name"
    pr_url=$(gh pr create --title "release: v$version" --body "Release v$version" --base master)
    echo "Created PR: $pr_url"

    # Add to merge queue
    gh pr merge --merge --auto "$pr_url"
    echo "PR added to merge queue, waiting for merge..."

    # Wait for PR to be merged
    while true; do
      state=$(gh pr view "$pr_url" --json state --jq '.state')
      if [[ "$state" == "MERGED" ]]; then
        echo "PR merged!"
        break
      elif [[ "$state" == "CLOSED" ]]; then
        echo "PR was closed without merging, aborting release" >&2
        git checkout master
        git branch -D "$branch_name"
        exit 1
      fi
      echo "Waiting for PR to merge (current state: $state)..."
      sleep 10
    done

    # Switch back to master and pull the merged commit
    git checkout master
    git pull origin master

    # Delete the local release branch
    git branch -D "$branch_name"

    # Tag the release and push tags
    git tag -a "v$version" -m "release: v$version"
    git tag -d "latest" 2>/dev/null || true
    git tag -a "latest" -m "release: v$version"
    git push origin "v$version"
    git push --force origin latest

    # Create follow-up branch to reset released flag
    followup_branch="release/v$version-followup"
    git checkout -b "$followup_branch"

    cat > version.nix <<EOF
    {
      version = "$version";
      released = false;
    }
    EOF
    git commit -am "release: reset released flag"

    git push -u origin "$followup_branch"
    followup_pr_url=$(gh pr create --title "release: reset released flag after v$version" --body "Reset released flag after v$version release" --base master)
    echo "Created follow-up PR: $followup_pr_url"
    gh pr merge --merge --auto "$followup_pr_url"

    # Switch back to master
    git checkout master

    # Create a draft GitHub release with auto-generated notes
    release_url=$(gh release create "v$version" --draft --generate-notes --verify-tag)
    edit_url=''${release_url/\/tag\//\/edit\/}

    echo
    echo "Release v$version complete!"
    echo "Edit and publish the draft release:"
    echo
    echo "  $edit_url"
  '';
}
