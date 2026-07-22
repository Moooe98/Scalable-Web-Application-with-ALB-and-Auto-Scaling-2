variable "project_name" { type = string }
variable "environment"  { type = string }
variable "alb_dns_name" { type = string }
variable "certificate_arn" {
  type    = string
  default = ""
}
