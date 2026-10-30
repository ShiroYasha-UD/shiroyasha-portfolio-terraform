#!/usr/bin/env bash
# Build the site, package site + contact API, upload to S3 and roll it out
# on the server through SSM (no SSH). Run from anywhere inside the project:
#   ./scripts/deploy.sh
# Uses the admin profile (override with AWS_PROFILE=...).
set -euo pipefail

cd "$(dirname "$0")/.."
PROFILE="${AWS_PROFILE:-portfolio-admin}"
REGION="eu-central-1"
AWS=(aws --profile "$PROFILE" --region "$REGION")

BUCKET=$(terraform -chdir=infra output -raw artifacts_bucket)
INSTANCE=$(terraform -chdir=infra output -raw instance_id)

echo "==> Building site"
npm run build

echo "==> Packaging"
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT
mkdir -p "$STAGE/site" "$STAGE/api"
cp -r dist/. "$STAGE/site/"
cp src/backend/server.js "$STAGE/api/"
cp package-lock.json "$STAGE/api/"

# The server only needs the API's runtime dependencies, not Astro/React.
node -e '
  const fs = require("fs");
  const root = JSON.parse(fs.readFileSync("package.json", "utf8"));
  const keep = ["express", "express-rate-limit", "zod", "@aws-sdk/client-sesv2"];
  const dependencies = Object.fromEntries(keep.map((k) => [k, root.dependencies[k]]));
  fs.writeFileSync(process.argv[1] + "/package.json",
    JSON.stringify({ name: root.name, private: true, type: "module", dependencies }, null, 2));
' "$STAGE/api"
# Pure-JS packages, so installing them here works for the ARM server too.
(cd "$STAGE/api" && npm install --omit=dev --no-audit --no-fund --ignore-scripts --loglevel=error)

STAMP=$(date -u +%Y%m%d-%H%M%S)
KEY="releases/$STAMP.tgz"
tar -czf "$STAGE/release.tgz" -C "$STAGE" site api
echo "    $(du -h "$STAGE/release.tgz" | cut -f1) -> s3://$BUCKET/$KEY"

echo "==> Uploading"
"${AWS[@]}" s3 cp --only-show-errors "$STAGE/release.tgz" "s3://$BUCKET/$KEY"

echo "==> Rolling out on $INSTANCE"
CMD_ID=$("${AWS[@]}" ssm send-command \
  --instance-ids "$INSTANCE" \
  --document-name AWS-RunShellScript \
  --comment "portfolio deploy $STAMP" \
  --parameters "{\"commands\":[\"/usr/local/bin/portfolio-deploy s3://$BUCKET/$KEY\"]}" \
  --query Command.CommandId --output text)

"${AWS[@]}" ssm wait command-executed --command-id "$CMD_ID" --instance-id "$INSTANCE" || true

STATUS=$("${AWS[@]}" ssm get-command-invocation --command-id "$CMD_ID" --instance-id "$INSTANCE" \
  --query Status --output text)
"${AWS[@]}" ssm get-command-invocation --command-id "$CMD_ID" --instance-id "$INSTANCE" \
  --query '[StandardOutputContent, StandardErrorContent]' --output text

if [[ "$STATUS" != "Success" ]]; then
  echo "Deploy failed (status: $STATUS)" >&2
  exit 1
fi
echo "==> Live at https://$(terraform -chdir=infra output -raw site_url | sed 's#https://##')"
