output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.fraud_detection_server.id
}

output "public_ip" {
  description = "Elastic IP (stable public IP for Ansible inventory)"
  value       = aws_eip.fraud_detection_eip.public_ip
}

output "instance_public_dns" {
  description = "Public DNS name"
  value       = aws_instance.fraud_detection_server.public_dns
}

output "service_urls" {
  description = "URLs for all services once Ansible provisioning is complete"
  value = {
    fraud_api  = "http://${aws_eip.fraud_detection_eip.public_ip}:5000"
    portainer  = "http://${aws_eip.fraud_detection_eip.public_ip}:9000"
    grafana    = "http://${aws_eip.fraud_detection_eip.public_ip}:3000"
    prometheus = "http://${aws_eip.fraud_detection_eip.public_ip}:9090"
    jenkins    = "http://${aws_eip.fraud_detection_eip.public_ip}:8080"
  }
}

output "ssh_command" {
  description = "SSH command to connect to the server"
  value       = "ssh -i ~/.ssh/${var.key_pair_name}.pem ec2-user@${aws_eip.fraud_detection_eip.public_ip}"
}
