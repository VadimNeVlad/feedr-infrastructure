#!/usr/bin/env bash
# Copies FeedR application images from GHCR to ECR, keeping the same tag (and the same digest).
#
# A stand-in for CI pushing to ECR: the application repositories' workflows would push there
# directly, but that needs GitHub OIDC, which the AWS Free plan forbids. Run it after `aws-lab`.
#
# Usage: scripts/ecr-mirror.sh <tag> [image...]
#   scripts/ecr-mirror.sh sha-05d46d4                     all three images
#   scripts/ecr-mirror.sh sha-05d46d4 feedr-frontend      one image
#
# Requires Docker, the AWS CLI with credentials (aws-lab) and a GHCR login for private images:
#   echo "$GITHUB_TOKEN" | docker login ghcr.io -u <github-user> --password-stdin   (read:packages)
set -euo pipefail

SOURCE="ghcr.io/vadimnevlad"
ALL_IMAGES=(feedr-backend feedr-backend-migrate feedr-frontend)

usage() {
    echo "usage: $0 <tag> [image...]   (tag: sha-xxxxxxx; images: ${ALL_IMAGES[*]})" >&2
    exit 2
}

[[ $# -ge 1 ]] || usage
tag="$1"
shift
# Only immutable release tags: ECR repositories reject overwriting a tag, and `latest` is
# resolved to a sha-* tag at deploy time anyway.
[[ "$tag" =~ ^sha-[0-9a-f]{7,40}$ ]] || { echo "tag must look like sha-05d46d4" >&2; exit 2; }
if [[ $# -gt 0 ]]; then
    images=("$@")
else
    images=("${ALL_IMAGES[@]}")
fi
for image in "${images[@]}"; do
    [[ " ${ALL_IMAGES[*]} " == *" ${image} "* ]] || { echo "unknown image: ${image}" >&2; usage; }
done

: "${AWS_REGION:?run aws-lab first (AWS_REGION is not set)}"
account="$(aws sts get-caller-identity --query Account --output text)"
registry="${account}.dkr.ecr.${AWS_REGION}.amazonaws.com"

# ECR login tokens live 12 hours; Docker keeps them in ~/.docker/config.json.
aws ecr get-login-password | docker login --username AWS --password-stdin "$registry"

for image in "${images[@]}"; do
    src="${SOURCE}/${image}:${tag}"
    dst="${registry}/${image}:${tag}"
    echo "==> ${src} -> ${dst}"
    docker pull --platform linux/amd64 "$src"
    docker tag "$src" "$dst"
    # Only the linux/amd64 image, not the whole index: Docker's containerd store would push an
    # OCI index + the image + a build attestation, with the tag on the index. ECR scans images,
    # not indexes (no findings for the tag), and the untagged children could be expired by the
    # "untagged after 1 day" lifecycle rule, leaving a tag that can't be pulled.
    docker push --platform linux/amd64 "$dst"
done

echo "Scan results (basic scanning runs on push):"
for image in "${images[@]}"; do
    echo "  aws ecr describe-image-scan-findings --repository-name ${image} --image-id imageTag=${tag}"
done
