variable "admin_cidr" {
  description = "Public IP address allowed to access SSH, Jenkins and the React application"
  type        = string
}
variable "key_name" {
  description = "Existing AWS EC2 key pair name"
  type        = string
}
