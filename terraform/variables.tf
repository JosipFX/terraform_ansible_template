variable "aws_region" {
  description = "us-east-1"
  default = "us-east-1"
}
variable "ami" {
  description = "Ami id"
  default     = "ami-022d4249382309a48"
}
variable "instance_count" {
  description = "number of instances"
  default     = "2"
}
variable "instance_type" {
  description = "type of instances"
  default     = "t2.micro"
}

variable "volume_size" {
  description = "volume size"
  default     = 20
}

variable "volume_type" {
  description = "volume type"
  default     = "gp3"
}

variable "ssh_pub_key_path" {
  description = "SSH key path"
  default = "~/.ssh/terra_ans.pub"
}
