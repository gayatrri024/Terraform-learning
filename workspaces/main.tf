provider "aws" {
  region = "ap-southeast-1"

}

variable "ami" {
  description = "The AMI to use for the EC2 instance"
  type        = string
  #default     = "ami-0c55b159cbfafe1f0"
}


variable "instance_type" {



  description = "The type of instance to use"
  type        = string
  # default = "t3.micro"

}




resource "aws_instance" "example" {
  ami = var.ami

  instance_type = (
    terraform.workspace == "dev" ? "t3.micro" :
    terraform.workspace == "staging" ? "t3.small" :
    terraform.workspace == "prod" ? "t3.medium" : "t3.micro"
  )


}








