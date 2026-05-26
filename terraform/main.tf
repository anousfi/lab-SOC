provider "aws" {
  region = var.region
  profile = "terraform-user"
}
#---------------------ADMINISTRATION----------------------------------------------------
resource "aws_instance" "administration" {
  ami           = var.ami # Ubuntu (Ubuntu 24.04 LTS)
  instance_type = var.instance_type1
  availability_zone = "eu-west-3a"
  subnet_id     = aws_subnet.private.id
  associate_public_ip_address = true
  key_name = aws_key_pair.deployer.key_name

  vpc_security_group_ids = [aws_security_group.elk-sg.id]

  user_data = <<-EOF
              #!/bin/bash
              apt update -y
              EOF

  tags = merge(
    var.common_tags,
    {
      Name = "Administration"
      Role = "Administration"
    }
  )
}

#----------------------WEBSERVER---------------------------------------------------------  
resource "aws_instance" "webserver" {
  ami           = var.ami # Ubuntu (Ubuntu 24.04 LTS)
  instance_type = var.instance_type1
  availability_zone = var.availability_zone
  subnet_id     = aws_subnet.private.id
  associate_public_ip_address = false
  key_name = aws_key_pair.deployer.key_name

  vpc_security_group_ids = [aws_security_group.administration.id]

  user_data = <<-EOF
              #!/bin/bash
              apt update -y
              EOF


  tags = merge(
    var.common_tags,
    {
      Name = "webserver"
      Role = "webserver"
    }
  )
}

#--------------ELASTICSEARCH-------------------------------------------------
resource "aws_instance" "elasticsearch" {
  ami           = var.ami # Ubuntu (Ubuntu 24.04 LTS)
  instance_type = var.instance_type2
  availability_zone = var.availability_zone
  subnet_id     = aws_subnet.private.id
  associate_public_ip_address = false
  key_name = aws_key_pair.deployer.key_name

  vpc_security_group_ids = [aws_security_group.elastic-sg.id]

  user_data = <<-EOF
              #!/bin/bash
              apt update -y
              EOF


  tags = merge(
    var.common_tags,
    {
      Name = "elastic"
      Role = "elasticSearch"
    }
  )
}
#------------------KIBANA----------------------------------------------------
resource "aws_instance" "kibana" {
  ami           = var.ami # Ubuntu (Ubuntu 24.04 LTS)
  instance_type = var.instance_type1
  availability_zone = var.availability_zone
  subnet_id     = aws_subnet.private.id
  associate_public_ip_address = false
  key_name = aws_key_pair.deployer.key_name

  vpc_security_group_ids = [aws_security_group.kibana-sg.id]

  user_data = <<-EOF
              #!/bin/bash
              apt update -y
              EOF


  tags = merge(
    var.common_tags,
    {
      Name = "kibana"
      Role = "kibana"
    }
  )
}



#---------------------------VPC--------------------------------------------
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

#--------------------public network-----------------------------------------

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true
}

#----------------------Security Group ELK ----------------------------------
resource "aws_security_group" "elastic-sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  ingress {
    from_port   = 9200
    to_port     = 9200
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "kibana-sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  ingress {
    from_port   = 5601
    to_port     = 5601
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#-----------------Security Group Administration ---------------
resource "aws_security_group" "administration" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["mon_adresse_publique"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["mon_adresse_publique"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#--------------Key pair --------------------------
resource "aws_key_pair" "deployer" {
  key_name   = "aws-hadoop-key"
  public_key = file("../../aws-hadoop.pub")
}