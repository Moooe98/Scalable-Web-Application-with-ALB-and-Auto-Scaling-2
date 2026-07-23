variable "project_name"   { type = string }
variable "environment"    { type = string }
variable "aws_region" {
  type    = string
  default = "us-east-1"
}
variable "alb_arn_suffix" { type = string }
variable "tg_arn_suffix"  { type = string }
variable "asg_name"       { type = string }
variable "rds_identifier" { type = string }
variable "sns_email"      { type = string }
