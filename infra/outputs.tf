output "public_ip" {
  description = "Elastic IP the domain points at."
  value       = aws_eip.web.public_ip
}

output "instance_id" {
  description = "Used by the deploy script and for SSM sessions."
  value       = aws_instance.web.id
}

output "artifacts_bucket" {
  description = "Private bucket for release tarballs."
  value       = aws_s3_bucket.artifacts.bucket
}

output "shell" {
  description = "Open a root-capable shell on the server (needs the Session Manager plugin)."
  value       = "aws ssm start-session --profile ${var.aws_profile} --region ${var.region} --target ${aws_instance.web.id}"
}

output "site_url" {
  value = "https://${var.domain}"
}
