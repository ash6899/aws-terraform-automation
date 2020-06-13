# Task 1 details for your reference :exclamation:️
# *Task 1* : Have to create/launch Application using Terraform
# 1. Create the key and security group which allow the port 80.
# 2. Launch EC2 instance.
# 3. In this Ec2 instance use the key and security group which we have created in step 1.
# 4. Launch one Volume (EBS) and mount that volume into /var/www/html
# 5. Developer have uploded the code into github repo also the repo has some images.
# 6. Copy the github repo code into /var/www/html
# 7. Create S3 bucket, and copy/deploy the images from github repo into the s3 bucket and change the permission to public readable.
# 8 Create a Cloudfront using s3 bucket(which contains images) and use the Cloudfront URL to  update in code in /var/www/html
# Above task should be done using terraform
provider "aws" {
  region     = "ap-south-1"
  profile    = "yash"
}
resource "tls_private_key" "task-1-private-key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}
resource "aws_key_pair" "task-1-key" {
  depends_on = [
    tls_private_key.task-1-private-key
  ]
  key_name = "task-1-key"
  public_key = "${tls_private_key.task-1-private-key.public_key_openssh}"
}
resource "aws_security_group" "task-1-security-group" {
  depends_on = [
    aws_key_pair.task-1-key
  ]
  name        = "task-1-security-group"
  description = "To Allow SSH AND HTTP requests"
  vpc_id      = "vpc-cffbe6a7"
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "task -1 -security-group"
  }
}
resource "aws_s3_bucket" "task-1-s3-bucket" {
  depends_on = [
    aws_security_group.task-1-security-group
  ]
  bucket = "task-1-s3-bucket"
  force_destroy = true
  acl    = "public-read"
  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Id": "MYBUCKETPOLICY",
  "Statement": [
    {
      "Sid": "PublicReadGetObject",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": "arn:aws:s3:::task-1-s3-bucket/*"
    }
  ]
}
POLICY
}
resource "aws_s3_bucket_object" "task-1-object" {
  bucket = "task-1-s3-bucket"
  key    = "terraform.png"
  source = "G:/MLOPS/CLOUD/task1/terraform.png"
  etag = "G:/MLOPS/CLOUD/task1/terraform.png"
  depends_on = [aws_s3_bucket.task-1-s3-bucket]
}
# Create Cloudfront distribution
resource "aws_cloudfront_distribution" "task-1-cloudfront" {
    depends_on = [
      aws_s3_bucket.task-1-s3-bucket
    ]
    origin {
        domain_name = aws_s3_bucket.task-1-s3-bucket.bucket_regional_domain_name
        origin_id = "S3-task-1-s3-bucket" 
        s3_origin_config {
          origin_access_identity = "origin-access-identity/cloudfront/E1FNKU20YWY63H"
        }
    }       
    enabled = true
    default_root_object = "index.php"
    default_cache_behavior {
        allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
        cached_methods = ["GET", "HEAD"]
        target_origin_id = "S3-task-1-s3-bucket"
        # Forward all query strings, cookies and headers
        forwarded_values {
            query_string = false
            cookies {
               forward = "none"
            }
        }
        viewer_protocol_policy = "allow-all"
        min_ttl = 0
        default_ttl = 3600
        max_ttl = 86400
    }
    # Restricts who is able to access this content
    restrictions {
        geo_restriction {
            # type of restriction, blacklist, whitelist or none
            restriction_type = "none"
        }
    }
    # SSL certificate for the service.
    viewer_certificate {
        cloudfront_default_certificate = true
    }
}
resource "aws_instance" "task-1-os" {
  depends_on = [
      aws_cloudfront_distribution.task-1-cloudfront
  ]
  ami           = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  key_name = "task-1-key"
  security_groups = [ "task-1-security-group" ]
  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = tls_private_key.task-1-private-key.private_key_pem
    host     = aws_instance.task-1-os.public_ip
  }
  provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd  php git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
    ]
  }
  tags = {
    Name = "task-1-os"
  }
}
resource "aws_ebs_volume" "task-1-ebs" {
  depends_on = [
    aws_instance.task-1-os
  ]
  availability_zone = aws_instance.task-1-os.availability_zone
  size              = 1
  tags = {
    Name = "task-1-ebs"
  }
}
resource "aws_volume_attachment" "ebs_att" {
  device_name = "/dev/sdh"
  volume_id   = "${aws_ebs_volume.task-1-ebs.id}"
  instance_id = "${aws_instance.task-1-os.id}"
  force_detach = true
}
resource "null_resource" "null-remote-1"  {
  depends_on = [
      aws_volume_attachment.ebs_att
  ]
  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = tls_private_key.task-1-private-key.private_key_pem
    host     = aws_instance.task-1-os.public_ip
  }
  provisioner "remote-exec" {
      inline = [
        "sudo mkfs.ext4  /dev/xvdh",
        "sudo mount  /dev/xvdh  /var/www/html"
      ]
  }
}
resource "null_resource" "null-remote-2"  {
  depends_on = [
      null_resource.null-remote-1
  ]
  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = tls_private_key.task-1-private-key.private_key_pem
    host     = aws_instance.task-1-os.public_ip
  }
  provisioner "remote-exec" {
      inline = [
        "sudo rm -rf /var/www/html/*",
        "sudo git clone https://github.com/ash6899/aws-terraform-automation.git /var/www/html/"
      ]
  }
}
output "cloudfront-domain-name" {
  value = aws_cloudfront_distribution.task-1-cloudfront.domain_name
}
output "myos_ip" {
  value = aws_instance.task-1-os.public_ip
}
output "private_key" {
  value = tls_private_key.task-1-private-key.private_key_pem
}




