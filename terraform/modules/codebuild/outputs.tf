output "arn" {
  description = "ARN of AWS CodeBuild project"
  value       = aws_codebuild_project.example.arn
}

output "id" {
  description = "ID of AWS CodeBuild project"
  value       = aws_codebuild_project.example.id
}