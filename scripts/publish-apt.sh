#!/usr/bin/env bash
# Publish *.deb files to the gh-pages branch as an unsigned apt repository
# (use with: deb [trusted=yes] https://<user>.github.io/<repo> current main)
set -euo pipefail

DEBDIR="${1:?usage: publish-apt.sh <dir-with-debs>}"
SUITE="current"
COMPONENT="main"
ARCH="arm64"
BRANCH="gh-pages"
: "${GH_TOKEN:?GH_TOKEN must be set}"

command -v apt-ftparchive >/dev/null 2>&1 || {
  sudo apt-get update -qq
  sudo apt-get install -y -qq apt-utils dpkg-dev
}

REPO_URL="https://x-access-token:${GH_TOKEN}@github.com/${GITHUB_REPOSITORY}.git"
TMP="$(mktemp -d)"

if git ls-remote --heads "$REPO_URL" "$BRANCH" | grep -q "refs/heads/$BRANCH"; then
  git clone --depth=1 --branch "$BRANCH" "$REPO_URL" "$TMP/repo"
else
  git init -q "$TMP/repo"
  git -C "$TMP/repo" checkout -q --orphan "$BRANCH"
fi

cd "$TMP/repo"
mkdir -p "pool/$SUITE/$COMPONENT/binary-$ARCH" "dists/$SUITE/$COMPONENT/binary-$ARCH"
cp -f "$DEBDIR"/*.deb "pool/$SUITE/$COMPONENT/binary-$ARCH/"

dpkg-scanpackages --arch "$ARCH" "pool/$SUITE/$COMPONENT/binary-$ARCH" /dev/null > "dists/$SUITE/$COMPONENT/binary-$ARCH/Packages"
rm -f "dists/$SUITE/$COMPONENT/binary-$ARCH/Packages.gz"
gzip -9n "dists/$SUITE/$COMPONENT/binary-$ARCH/Packages"

apt-ftparchive \
  -o "APT::FTPArchive::Release::Origin=droidian-oppo-joan" \
  -o "APT::FTPArchive::Release::Label=droidian-oppo-joan" \
  -o "APT::FTPArchive::Release::Suite=$SUITE" \
  -o "APT::FTPArchive::Release::Codename=$SUITE" \
  -o "APT::FTPArchive::Release::Architectures=$ARCH" \
  -o "APT::FTPArchive::Release::Components=$COMPONENT" \
  -o "APT::FTPArchive::Release::Description=Droidian port packages for Oppo A38 (joan)" \
  release "dists/$SUITE" > "dists/$SUITE/Release"

git config user.name "droidian-ci"
git config user.email "ci@localhost"
git add -A
if git diff --cached --quiet; then
  echo "apt repository: nothing to update"
else
  git commit -qm "apt: update $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  git push -q "$REPO_URL" "$BRANCH"
  echo "apt repository published: https://${GITHUB_REPOSITORY%%/*}.github.io/${GITHUB_REPOSITORY##*/} $SUITE $COMPONENT"
fi
