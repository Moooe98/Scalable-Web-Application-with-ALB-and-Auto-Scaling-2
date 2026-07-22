variable "project_name"         { type = string }
variable "environment"          { type = string }
variable "ami_id"               { type = string }
variable "instance_type"        { type = string }
variable "private_subnet_ids"   { type = list(string) }
variable "ec2_sg_id"            { type = string }
variable "target_group_arn"     { type = string }
variable "ssm_instance_profile" { type = string }
variable "asg_min_size"         { type = number }
variable "asg_max_size"         { type = number }
variable "asg_desired_capacity" { type = number }
variable "rds_endpoint"         { type = string }
variable "db_name"              { type = string }
variable "db_username" {
  type      = string
  sensitive = true
}
variable "db_password" {
  type      = string
  sensitive = true
}
variable "alb_arn_suffix" {
  type    = string
  default = ""
}
variable "tg_arn_suffix" {
  type    = string
  default = ""
}
