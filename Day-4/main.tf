   provider "aws" {
    region = "ap-south-1"
  }

  resource "aws_instance" "gayatri" {
    instance_type = "t3.micro"
    ami           = "ami-0593d733c2fc5bd2e"


  }
resource "s3_bucket" "gayatri_bucket" {
  bucket = "gayatri-bucket-123456"
  acl    = "private"

  tags = {
    Name        = "Gayatri Bucket"
    Environment = "Dev"
  }
}