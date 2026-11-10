provider "aws" {
        region = "ap-south-1"
    }   
resource "aws_instance" "example" {
  ami           = "ami-05fbd65e334e88c16"
  instance_type = "t3.micro"

}