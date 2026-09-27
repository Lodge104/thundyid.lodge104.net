# thundyid.lodge104.net

Terraform/Terragrunt infrastructure for [Zitadel](https://zitadel.com), the
identity/SSO provider for Lodge104, running on Amazon EKS. The layout and
module conventions mirror
[`Lodge104/wp.lodge104.net`](https://github.com/Lodge104/wp.lodge104.net) —
the same `_common/*.hcl` + `_modules/*` + per-environment `terragrunt.hcl`
pattern is reused so both projects stay consistent and easy to cross-reference.

Like WordPress, this project has `dev`/`test`/`prod` environment trees.
All three are exact replicas of each other — identical sizing/architecture —
and differ only in environment name and the resulting domain: `prod` serves
`thundyid.lodge104.net` directly, while `dev` and `test` are reachable at
`dev.thundyid.lodge104.net` and `test.thundyid.lodge104.net` (each with its
own delegated Route53 zone, ACM certificate, and ALB), since a domain/cert/
ALB cannot be shared across separate environments.

## Architecture

- **VPC** (`terraform-aws-modules/vpc/aws`) — dedicated VPC, public/private/
  database subnets, NAT gateway, flow logs.
- **EKS** (`terraform-aws-modules/eks/aws`, **Auto Mode**) — AWS manages
  node pools (`general-purpose`) directly; no `eks_managed_node_groups`.
- **eks-addons** (`aws-ia/eks-blueprints-addons`) — AWS Load Balancer
  Controller (for the shared ALB Ingress pattern) and external-dns.
- **RDS** (`terraform-aws-modules/rds-aurora/aws`) — Aurora PostgreSQL
  Serverless v2, satisfies Zitadel's Postgres 14+ requirement. Master
  password is Terraform-managed (`zitadel-secrets`), not
  `manage_master_user_password`, to avoid a data-source race on fresh
  clusters and to reuse the same value directly in the Helm release.
- **Valkey** (`_modules/valkey-release`, Bitnami Helm chart) — runs
  in-cluster rather than as a managed ElastiCache service, mirroring how
  wp.lodge104.net runs an in-cluster Bitnami Memcached sub-chart instead of
  managed ElastiCache for its cache layer. Zitadel's Redis cache connector
  only supports a single standalone endpoint anyway (no cluster-mode or
  Sentinel support), so a managed replication group would add cost without
  adding usable capability.
- **ACM** (`terraform-aws-modules/acm/aws`) — DNS-validated certificate for
  `thundyid.lodge104.net`.
- **Route53**:
  - `global/route53-thundyid` creates the delegated `thundyid.lodge104.net`
    hosted zone; `global/route53-dev` and `global/route53-test` create the
    per-env `dev.thundyid.lodge104.net` / `test.thundyid.lodge104.net` zones
    (analogous to wp.lodge104.net's `route53-dev`/`-test`/`-prod`).
  - `global/route53-parent` delegates the `thundyid` subdomain (NS + DS
    records) from the shared `lodge104.net` root zone.
  - `global/route53-env-delegation` delegates the `dev` and `test`
    subdomains (NS + DS records) from the `thundyid.lodge104.net` zone down
    to their own per-env zones.
  - Each env's `<env>/us-east-1/route53` unit creates the ALB alias `A`
    record once that env's Zitadel Ingress load balancer exists.
- **zitadel-secrets** (`_modules/zitadel-secrets`) — generates and stores in
  AWS Secrets Manager all credentials the deployment needs up front: the
  32-byte encryption masterkey, the Aurora master password, the Zitadel
  application DB role password, the in-cluster Valkey AUTH token, and the
  initial FirstInstance bootstrap admin password. Centralizing these here
  (instead of in the rds/valkey/zitadel modules individually) lets every
  unit that needs a given value depend on the same output.
- **zitadel** (`_modules/zitadel-release`) — installs the
  [Zitadel Helm chart](https://github.com/zitadel/zitadel-charts), bridging
  the masterkey into a Kubernetes Secret the chart mounts by name, and
  composing sensitive `zitadel.secretConfig` Helm values internally so
  plaintext credentials never appear in a terragrunt.hcl's `values` list.
  TLS terminates at the ALB (`TLS.Enabled: false`); a second ALB Ingress
  group member routes `/ui/v2/login` to the Next.js login service on the
  same shared ALB (see [Zitadel's Kubernetes deployment docs](https://zitadel.com/docs/self-hosting/deploy/kubernetes)).

## Directory structure

```
project.hcl                    # project-wide constants (names, domain)
root.hcl                        # root Terragrunt config: remote state + provider generation
_common/*.hcl                  # shared config per resource type, env-agnostic
_modules/
  zitadel-release/              # helm_release + masterkey Secret bridge
  zitadel-secrets/               # random_password + Secrets Manager
  valkey-release/                 # in-cluster Valkey helm_release + auth Secret bridge
global/
  region.hcl
  route53-thundyid/              # delegated hosted zone for prod
  route53-dev/                    # delegated hosted zone for dev
  route53-test/                   # delegated hosted zone for test
  route53-parent/                 # NS/DS delegation from lodge104.net
  route53-env-delegation/          # NS/DS delegation of dev/test from thundyid.lodge104.net
dev/                            # exact replica of prod, see below
test/                           # exact replica of prod, see below
prod/
  env.hcl                        # env-specific sizing/config (identical across dev/test/prod)
  us-east-1/
    region.hcl
    vpc/ eks/ eks-addons/
    rds/ valkey/
    zitadel-secrets/
    acm/ route53/
    zitadel/
```

## Deploying

```sh
cd prod/us-east-1   # or dev/us-east-1, test/us-east-1
terragrunt run-all init
terragrunt run-all apply
```

Terragrunt's `dependency` blocks enforce ordering automatically (vpc → eks →
eks-addons/rds/zitadel-secrets → valkey → acm → zitadel → route53).

Each environment's remote state is stored under its own `<env>/us-east-1/...`
key in the shared state bucket, so `dev`, `test`, and `prod` never collide.

After apply, retrieve the initial admin credentials:

```sh
aws secretsmanager get-secret-value \
  --secret-id net-lodge104-zitadel-prod/zitadel-admin-credentials \
  --query SecretString --output text | jq .
```
