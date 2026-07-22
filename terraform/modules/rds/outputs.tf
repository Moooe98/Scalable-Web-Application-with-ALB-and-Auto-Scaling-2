output "rds_endpoint" {
  value     = aws_db_instance.main.endpoint
  sensitive = true
}
output "rds_identifier" { value = aws_db_instance.main.identifier }
output "rds_arn"        { value = aws_db_instance.main.arn }
