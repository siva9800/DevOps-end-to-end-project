output "runner_instance_id" {
  description = "EC2 instance ID — use this to start SSM session"
  value       = aws_instance.runner.id
}

output "runner_private_ip" {
  description = "Private IP address of the runner"
  value       = aws_instance.runner.private_ip
}

output "runner_security_group_id" {
  description = "Security group ID of the runner"
  value       = aws_security_group.runner.id
}

output "runner_iam_role_arn" {
  description = "IAM role ARN of the runner"
  value       = aws_iam_role.runner.arn
}

output "ssm_token_parameter_name" {
  description = "SSM parameter path where runner token is stored"
  value       = aws_ssm_parameter.runner_token.name
}

output "ssm_connect_command" {
  description = "Ready-to-use command to SSM into the runner"
  value       = "aws ssm start-session --target ${aws_instance.runner.id} --region ${var.aws_region}"
}