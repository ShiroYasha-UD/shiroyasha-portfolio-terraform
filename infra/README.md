# Infrastructure

Terraform for the portfolio server on AWS (eu-central-1).

```
Internet ─► Route 53 (shiroyasha.dev, www) ─► Elastic IP ─► EC2 t4g.micro (Amazon Linux 2023)
                                                              ├─ Caddy: HTTPS, static site from /srv/portfolio/current/site
                                                              └─ /api/contact ─► Node contact API ─► Amazon SES
```

- **No SSH.** Port 22 is closed; shell access and deploys go through AWS Systems Manager.
- **No keys on the server.** The instance role allows only SES sending, reading release tarballs, and SSM.
- **IMDSv2 required**, encrypted gp3 disk, CPU credits set to `standard` (no surprise bills).
- **Caddy** gets and renews the Let's Encrypt certificate itself and serves HTTP/3.
- **Automatic security updates** via `dnf-automatic`.
- The hosted zone and the email records (Tuta, SES) were created by hand and are only *read* here.

## Requirements

- Terraform ≥ 1.6 (or OpenTofu)
- AWS CLI profile `portfolio-admin` with admin rights (change with `-var aws_profile=...`)
- For `aws ssm start-session`: the Session Manager plugin

## Usage

```sh
cd infra
terraform init
terraform plan
terraform apply
```

Then, from the project root:

```sh
./scripts/deploy.sh
```

Shell on the server: `terraform output -raw shell`, then run the printed command.

## Cost (approx., Frankfurt)

| Item | Per month |
|---|---|
| t4g.micro | ~$7 |
| 8 GB gp3 | ~$0.75 |
| Public IPv4 | ~$3.65 |
| Route 53 zone | $0.50 |
| S3, SES, SSM | cents |

## Notes

- Changing `bootstrap.sh.tftpl` replaces the instance. Run `./scripts/deploy.sh` afterwards.
  Each rebuild requests a new certificate, so avoid rebuilding more than a few times a week.
- Bootstrap log on the server: `/var/log/cloud-init-output.log`.
