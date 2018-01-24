provider "aws" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region     = "${var.region}"
}

# Provision the machine
resource "aws_instance" "_InternationalJumpbox" {
  ami           = "ami-aa2ea6d0"
  instance_type = "t2.micro"
  security_groups = ["${aws_security_group.allow_ssh.name}"]
  key_name = "terraform-keypair-test"
  
  # provisioner "local-exec" {
  #   command = "echo ${aws_instance._InternationalJumpbox.public_ip} > ip_address"
  # }

}

# Add an elastic IP to the machine
resource "aws_eip" "my_elastic_ip" {
  instance = "${aws_instance._InternationalJumpbox.id}"

  provisioner "local-exec" {
    command = "echo ${aws_eip.my_elastic_ip.public_ip} > ip_address"
  }

}

# Security group for ssh
resource "aws_security_group" "allow_ssh" {
  name = "SSH"
  description = "Allow ssh"

  # SSH access from anywhere
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}

# Keypair for ssh access
resource "aws_key_pair" "terraform-keypair" {
  key_name = "terraform-keypair-test"
  public_key = "${var.public_key}"
}
