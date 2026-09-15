#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Slavi Pantaleev
#
# SPDX-License-Identifier: AGPL-3.0-or-later

# Exercises bin/compute-next-tag.sh against throwaway git repositories.
#
# Usage: bin/test-compute-next-tag.sh
#
# Every scenario creates a repository in a temporary directory, gives it role
# files and a release history, and then replays a series of merges through the
# real script, tagging as it goes just like the autotag workflow does. This
# repository is never touched and no network access is needed.

set -euo pipefail

script_under_test="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/compute-next-tag.sh"

failures=0
workdir=''

cleanup() {
	cd /
	if [ -n "$workdir" ]; then
		rm -rf "$workdir"
		workdir=''
	fi
}

trap cleanup EXIT

# Starts a scenario with a repository at Jellyfin 10.11.11 which has already
# seen two releases of it (v10.11.11-0 and v10.11.11-1), plus the `v3.14.6-0`
# tag this repository really carries from the era when the version was read out
# of Renovate's commit subjects - that one is the version of Python the tests
# run on, and must not be counted as a release of anything.
#
# The defaults file deliberately carries the traps this role's real one has: the
# `# renovate:` annotation that names a version-looking image, a commented-out
# example of the version variable, and an image tag derived from it. None of
# those may be picked up as the version.
scenario() {
	echo "$1"

	cleanup
	workdir="$(mktemp -d)"

	mkdir -p "$workdir/bin" "$workdir/defaults" "$workdir/meta" "$workdir/tasks" "$workdir/templates"
	cp "$script_under_test" "$workdir/bin/"
	cd "$workdir"

	git init -q -b main .
	git config user.email 'test@example.com'
	git config user.name 'Test'
	git config commit.gpgsign false

	cat > defaults/main.yml <<-'YAML'
		# jellyfin_version: 9.9.9

		# renovate: datasource=docker depName=lscr.io/linuxserver/jellyfin versioning=semver
		jellyfin_version: 10.11.11
		jellyfin_arch: amd64

		jellyfin_container_image: "{{ jellyfin_container_image_registry_prefix }}linuxserver/jellyfin:{{ jellyfin_container_image_tag }}"
		jellyfin_container_image_tag: "{{ jellyfin_version }}"
	YAML
	printf 'placeholder\n' > meta/main.yml
	printf 'placeholder\n' > tasks/main.yml
	printf 'placeholder\n' > templates/env.j2
	printf 'placeholder\n' > README.md

	git add -A
	git commit -qm 'Initial commit'

	local tag
	for tag in v3.14.6-0 v10.11.11-0 v10.11.11-1; do
		git tag "$tag"
	done
}

# Applies a change, commits it, and tags whatever the script says it should be.
# Prints the tag, or nothing when the script decided against a release.
merge() {
	local change="$1" tag

	eval "$change"
	git add -A
	git commit -qm 'Merge'

	tag="$(bin/compute-next-tag.sh 2>/dev/null)"

	if [ -n "$tag" ]; then
		git tag "$tag"
	fi

	printf '%s' "$tag"
}

expect() {
	local description="$1" expected="$2" actual="$3"

	if [ "$actual" = "$expected" ]; then
		printf '  ok   | %s -> %s\n' "$description" "${actual:-no release}"
	else
		printf '  FAIL | %s -> expected %s, got %s\n' "$description" "${expected:-no release}" "${actual:-no release}"
		failures=$((failures + 1))
	fi
}

bump_version="sed -i 's|^jellyfin_version: 10.11.11|jellyfin_version: 10.11.12|' defaults/main.yml"
revert_version="sed -i 's|^jellyfin_version: 10.11.12|jellyfin_version: 10.11.11|' defaults/main.yml"
edit_task="printf 'a task\n' >> tasks/main.yml"
edit_template="printf 'a line\n' >> templates/env.j2"
edit_meta="printf 'a line\n' >> meta/main.yml"
edit_readme="printf 'documentation\n' >> README.md"
edit_script="printf '# a comment\n' >> bin/compute-next-tag.sh"
bump_annotation="sed -i 's|versioning=semver|versioning=docker|' defaults/main.yml"

# The two merge orders below apply the same updates and must each end up with
# every update released exactly once, whichever order they arrive in.

scenario 'A version bump merged before other role changes'
expect 'version bump' v10.11.12-0 "$(merge "$bump_version")"
expect 'task edit'    v10.11.12-1 "$(merge "$edit_task")"
expect 'template'     v10.11.12-2 "$(merge "$edit_template")"

scenario 'A version bump merged after other role changes'
expect 'task edit'    v10.11.11-2 "$(merge "$edit_task")"
expect 'version bump' v10.11.12-0 "$(merge "$bump_version")"

# `v3.14.6-0` exists in every scenario, from the day the commit-message era
# mistook Renovate's "Update python Docker tag to v3.14.6" for a release of this
# role. It belongs to no Jellyfin version and must never be counted as one.
scenario 'The Python tag left over from the commit-message era'
expect 'a task' v10.11.11-2 "$(merge "$edit_task")"

scenario 'Commits that do not affect the role'
expect 'README'   ''           "$(merge "$edit_readme")"
expect 'a script' ''           "$(merge "$edit_script")"
expect 'meta'     v10.11.11-2  "$(merge "$edit_meta")"

# The Renovate annotation sits in defaults/main.yml, immediately above the
# version. Editing it is a change to the role's release-relevant surface, and it
# must not be mistaken for the version itself.
scenario 'Editing the Renovate annotation'
expect 'annotation' v10.11.11-2 "$(merge "$bump_annotation")"

scenario 'Release numbers past 9'
for release_number in 2 3 4 5 6 7 8 9 10; do
	git tag "v10.11.11-$release_number"
done
expect 'a task' v10.11.11-11 "$(merge "$edit_task")"

scenario 'Reverting to an already released version'
merge "$bump_version" > /dev/null
# The role is now identical to what v10.11.11-1 already published, so there is
# nothing new to release.
expect 'a revert' ''           "$(merge "$revert_version")"

scenario 'Reverting to an already released version, with a change'
merge "$bump_version" > /dev/null
expect 'a revert' v10.11.11-2 "$(merge "$revert_version && $edit_task")"

if [ "$failures" -gt 0 ]; then
	echo >&2 "$failures scenario(s) behaved unexpectedly"
	exit 1
fi

echo 'All scenarios behaved as expected'
