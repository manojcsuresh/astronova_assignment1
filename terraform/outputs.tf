output "control_plane_public_ip" {
  description = "Public IP of the control plane node"
  value       = aws_instance.k8s_nodes[0].public_ip
}

output "control_plane_private_ip" {
  description = "Private IP of the control plane node"
  value       = aws_instance.k8s_nodes[0].private_ip
}

output "worker_1_public_ip" {
  description = "Public IP of worker node 1"
  value       = aws_instance.k8s_nodes[1].public_ip
}

output "worker_1_private_ip" {
  description = "Private IP of worker node 1"
  value       = aws_instance.k8s_nodes[1].private_ip
}

output "worker_2_public_ip" {
  description = "Public IP of worker node 2"
  value       = aws_instance.k8s_nodes[2].public_ip
}

output "worker_2_private_ip" {
  description = "Private IP of worker node 2"
  value       = aws_instance.k8s_nodes[2].private_ip
}

output "ssh_connection_commands" {
  description = "SSH commands to connect to each node"
  value = {
    control_plane = "ssh -i ~/.ssh/${var.key_name}.pem ubuntu@${aws_instance.k8s_nodes[0].public_ip}"
    worker_1      = "ssh -i ~/.ssh/${var.key_name}.pem ubuntu@${aws_instance.k8s_nodes[1].public_ip}"
    worker_2      = "ssh -i ~/.ssh/${var.key_name}.pem ubuntu@${aws_instance.k8s_nodes[2].public_ip}"
  }
}

output "security_group_ids" {
  description = "Security group IDs created"
  value = {
    ssh     = aws_security_group.k8s_ssh.id
    web     = aws_security_group.k8s_web.id
    cluster = aws_security_group.k8s_cluster.id
  }
}
