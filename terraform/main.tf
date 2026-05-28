provider "aws" {
  region = var.region
  profile = "terraform-user"
}
#---------------------ADMINISTRATION----------------------------------------------------
resource "aws_instance" "administration" {
  ami           = var.ami # Ubuntu (Ubuntu 24.04 LTS)
  instance_type = var.instance_type1
  availability_zone = "eu-west-3a"
  subnet_id = aws_subnet.public.id
  associate_public_ip_address = true
  key_name = aws_key_pair.deployer.key_name

  vpc_security_group_ids = [aws_security_group.administration_sg.id]

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
  subnet_id     = aws_subnet.public.id
  associate_public_ip_address = true
  key_name = aws_key_pair.deployer.key_name

  vpc_security_group_ids = [aws_security_group.webserver_sg.id]

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

#-----------------public network route -------------------------------------------

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

#-----------------public route association ---------------------------------------

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

#------------------private network-------------------------------------------------

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = var.availability_zone

  map_public_ip_on_launch = false

  tags = {
    Name = "private-subnet"
  }
}

#--------------------elastic ip--------------------------------------------------------

resource "aws_eip" "nat" {
  domain = "vpc"
}

#--------------------nat gateway------------------------------------------------------

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id

  tags = {
    Name = "nat-gateway"
  }
}

#----------------------route table-----------------------------------------------------

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "private-rt"
  }
}

#---------------------route table association ----------------------------------------

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

#-------------------- Internet gateway -----------------------------------------------

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

#----------------------Security Group Elastic Search ----------------------------------
resource "aws_security_group" "elastic_sg"{
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16","mon adresse publique"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
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

  tags = {
    Name = "elastic-sg"
  }
}

#----------------------Security Group Kibana ----------------------------------

resource "aws_security_group" "kibana_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16","mon adresse publique"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
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

  tags = {
    Name = "kibana-sg"
  }
}

#-----------------Security Group Administration ---------------
resource "aws_security_group" "administration_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["mon adresse publique"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["mon adresse publique"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "administration-sg"
  }
}

#-----------------Security Webserver ---------------
resource "aws_security_group" "webserver_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["mon adresse publique"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["mon adresse publique"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "webserver-sg"
  }
}

#--------------Key pair --------------------------
resource "aws_key_pair" "deployer" {
  key_name   = "aws-hadoop-key"
  public_key = file("../../aws-hadoop.pub")
}