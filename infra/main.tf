data "aws_caller_identity" "current" {}

# ---------------------------------------------------------------------------
# Existing things this config only READS (they were set up by hand and also
# hold the Tuta + SES email records, so Terraform must not own them yet).
# ---------------------------------------------------------------------------

data "aws_route53_zone" "main" {
  name         = var.domain
  private_zone = false
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

# Latest Amazon Linux 2023 for ARM (Graviton). It ships with the SSM agent and
# AWS CLI preinstalled, which is what makes "no SSH at all" possible.
data "aws_ssm_parameter" "al2023_arm64" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64"
}

# ---------------------------------------------------------------------------
# Firewall: only web traffic in. No port 22 - shell access goes through SSM.
# ---------------------------------------------------------------------------

resource "aws_security_group" "web" {
  name        = "portfolio-web"
  description = "Portfolio web server: HTTP/HTTPS in, everything out"
  vpc_id      = data.aws_vpc.default.id
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.web.id
  description       = "HTTP (Caddy redirects to HTTPS, and Lets Encrypt validates here)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "https" {
  security_group_id = aws_security_group.web.id
  description       = "HTTPS"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

resource "aws_vpc_security_group_ingress_rule" "http3" {
  security_group_id = aws_security_group.web.id
  description       = "HTTP/3 (QUIC), which Caddy serves automatically"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "udp"
  from_port         = 443
  to_port           = 443
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.web.id
  description       = "Outbound: package updates, Lets Encrypt, SES, SSM, S3"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# ---------------------------------------------------------------------------
# Private bucket the deploy script uploads release tarballs to.
# ---------------------------------------------------------------------------

resource "aws_s3_bucket" "artifacts" {
  bucket        = "portfolio-artifacts-${data.aws_caller_identity.current.account_id}"
  force_destroy = true # releases are disposable; lets `terraform destroy` clean up
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket                  = aws_s3_bucket.artifacts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    id     = "expire-old-releases"
    status = "Enabled"
    filter {
      prefix = "releases/"
    }
    expiration {
      days = 30
    }
  }
}

# ---------------------------------------------------------------------------
# Instance identity: SSM access, SES sending, reading release tarballs.
# The app gets short-lived credentials from this role - no keys on the server.
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "web" {
  name               = "portfolio-web"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.web.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy_document" "web" {
  statement {
    sid     = "SendContactMail"
    actions = ["ses:SendEmail"]
    resources = [
      "arn:aws:ses:${var.region}:${data.aws_caller_identity.current.account_id}:identity/*",
      "arn:aws:ses:${var.region}:${data.aws_caller_identity.current.account_id}:configuration-set/*",
    ]
  }

  statement {
    sid       = "ReadReleases"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.artifacts.arn}/releases/*"]
  }
}

resource "aws_iam_role_policy" "web" {
  name   = "portfolio-web"
  role   = aws_iam_role.web.id
  policy = data.aws_iam_policy_document.web.json
}

resource "aws_iam_instance_profile" "web" {
  name = "portfolio-web"
  role = aws_iam_role.web.name
}

# ---------------------------------------------------------------------------
# The server
# ---------------------------------------------------------------------------

resource "aws_instance" "web" {
  ami                    = data.aws_ssm_parameter.al2023_arm64.value
  instance_type          = var.instance_type
  subnet_id              = data.aws_subnets.default.ids[0]
  vpc_security_group_ids = [aws_security_group.web.id]
  iam_instance_profile   = aws_iam_instance_profile.web.name

  # The bootstrap script installs Node, Caddy and the services on first boot.
  # Changing it rebuilds the server (it holds no data; deploy again afterwards).
  user_data = templatefile("${path.module}/bootstrap.sh.tftpl", {
    domain        = var.domain
    region        = var.region
    contact_from  = var.contact_from
    contact_to    = var.contact_to
    acme_email    = var.acme_email
    caddy_version = var.caddy_version
  })
  user_data_replace_on_change = true

  # IMDSv2 only: blocks the classic SSRF trick of stealing role credentials.
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  # t4g defaults to "unlimited" CPU credits, which can bill extra under load.
  # "standard" just throttles instead - the right trade-off for a portfolio.
  credit_specification {
    cpu_credits = "standard"
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = var.root_volume_gb
    encrypted   = true
  }

  tags = {
    Name = "portfolio-web"
  }

  lifecycle {
    # Don't rebuild the server every time AWS publishes a newer image;
    # the OS patches itself (see bootstrap).
    ignore_changes = [ami]
  }
}

# Fixed public IP, so DNS never has to change when the instance is replaced.
resource "aws_eip" "web" {
  domain   = "vpc"
  instance = aws_instance.web.id

  tags = {
    Name = "portfolio-web"
  }
}

# ---------------------------------------------------------------------------
# DNS: point the domain at the server. Email records are left untouched.
# ---------------------------------------------------------------------------

resource "aws_route53_record" "apex" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.domain
  type    = "A"
  ttl     = 300
  records = [aws_eip.web.public_ip]
}

resource "aws_route53_record" "www" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "www.${var.domain}"
  type    = "A"
  ttl     = 300
  records = [aws_eip.web.public_ip]
}
