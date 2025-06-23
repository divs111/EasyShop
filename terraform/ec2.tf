data "aws_ami" "os_image" {
  owners = ["099720109477"]
  most_recent = true
  filter {
    name   = "state"
    values = ["available"]
  }
  filter {
    name = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/*24.04-amd64*"]
  }
}

resource "aws_key_pair" "deployer" {
  key_name   = "terra-automate-key"
  public_key = file("terra-key.pub")
}

resource "aws_default_vpc" "default" {

}

resource "aws_security_group" "allow_user_to_connect" {
  name        = "allow TLS"
  description = "Allow user to connect"
  vpc_id      = aws_default_vpc.default.id
  ingress {
    description = "port 22 allow"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = " allow all outgoing traffic "
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "port 80 allow"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "port 443 allow"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "port 8080 allow"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "mysecurity"
  }
}

resource "aws_instance" "testinstance" {
  ami             = data.aws_ami.os_image.id
  instance_type   = var.instance_type 
  key_name        = aws_key_pair.deployer.key_name
  security_groups = [aws_security_group.allow_user_to_connect.name]
  # user_data = file("${path.module}/install_tools.sh")
  tags = {
    Name = "Jenkins-Automate"
  }
  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }
  
}

resource "local_file" "ansible_inventory" {
  content = <<EOT
  [jenkins]
  ${aws_instance.testinstance.public_ip}
  [jenkins:vars]
  ansible_user=ubuntu
  ansible_ssh_private_key_file=terra-key
  EOT
  filename = "${path.module}/inventory.ini"
  
}

resource "null_resource" "provision_ansible" {
  depends_on = [aws_instance.testinstance, local_file.ansible_inventory]

  provisioner "local-exec" {
    command = <<EOT
      echo "waiting for ec2 to get launched"
      sleep 60
      ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i inventory.ini setup_tools.yml
    EOT
  }
}
