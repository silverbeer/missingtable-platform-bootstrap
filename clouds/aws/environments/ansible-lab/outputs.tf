output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.radius_server.id
}

output "public_ip" {
  description = "Public IP address of the RADIUS server"
  value       = aws_instance.radius_server.public_ip
}

output "public_dns" {
  description = "Public DNS name of the RADIUS server"
  value       = aws_instance.radius_server.public_dns
}

output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh -i ~/.ssh/ansible-lab ubuntu@${aws_instance.radius_server.public_ip}"
}

output "ami_id" {
  description = "AMI ID used for the instance"
  value       = data.aws_ami.ubuntu.id
}

output "s3_bucket_name" {
  description = "S3 bucket for RADIUS server config"
  value       = aws_s3_bucket.radius_server_config.id
}
