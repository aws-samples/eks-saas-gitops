output "public_ip" {
  value = aws_instance.gitea.public_ip
}

output "instance_id" {
  value = aws_instance.gitea.id
}

output "security_group_id" {
  value = aws_security_group.gitea.id
}
