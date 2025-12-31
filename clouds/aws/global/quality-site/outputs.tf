output "runner_public_ip" {
    value = var.runner_enabled ? aws_instance.runner[0].public_ip : null
}