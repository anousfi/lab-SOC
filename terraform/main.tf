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
  iam_instance_profile = aws_iam_instance_profile.ansible_manager_profile.name

  user_data = <<-EOF
              #!/bin/bash
              set -euxo pipefail
              apt update -y
              apt install -y python3-pip python3-venv pipx

              #Ansible
              PIPX_HOME=/opt/pipx PIPX_BIN_DIR=/usr/local/bin pipx install --include-deps ansible
              PIPX_HOME=/opt/pipx PIPX_BIN_DIR=/usr/local/bin pipx inject ansible boto3 botocore hvac

              #Vault
              wget -O - https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
              echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list
              apt update -y
              apt install -y vault

              #SSM plugin
              curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" -o /tmp/session-manager-plugin.deb
              dpkg -i /tmp/session-manager-plugin.deb
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
  iam_instance_profile = aws_iam_instance_profile.ansible_worker_profile.name
  vpc_security_group_ids = [aws_security_group.webserver_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              apt update -y
              apt install -y python3-pip python3-venv 
              python3 -m venv /opt/ansible-venv
              /opt/ansible-venv/bin/pip install --upgrade pip
              /opt/ansible-venv/bin/pip install hvac
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
  iam_instance_profile = aws_iam_instance_profile.ansible_worker_profile.name
  vpc_security_group_ids = [aws_security_group.elastic_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              apt update -y
              apt install -y python3-pip python3-venv
              python3 -m venv /opt/ansible-venv
              /opt/ansible-venv/bin/pip install --upgrade pip
              /opt/ansible-venv/bin/pip install hvac
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
  iam_instance_profile = aws_iam_instance_profile.ansible_worker_profile.name
  vpc_security_group_ids = [aws_security_group.kibana_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              apt update -y
              apt install -y python3-pip python3-venv
              python3 -m venv /opt/ansible-venv
              /opt/ansible-venv/bin/pip install --upgrade pip
              /opt/ansible-venv/bin/pip install hvac
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
    Name = "elastic_sg"
  }
}

#----------------------Security Group Kibana ----------------------------------

resource "aws_security_group" "kibana_sg" {
  vpc_id = aws_vpc.main.id


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
    Name = "kibana_sg"
  }
}

#-----------------Security Group Administration ---------------
resource "aws_security_group" "administration_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["public address"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["public address"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "administration_sg"
  }
}

#-----------------Security Webserver ---------------
resource "aws_security_group" "webserver_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["public address"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "webserver_sg"
  }
}

#-------------STS role------------------------------------
resource "aws_iam_role" "ansible_manager_role" {
  name = "ansible-manager-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role" "ansible_worker_role" {
  name = "ansible-worker-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

#------------policy on S3 bucket -------------------------------
resource "aws_iam_policy" "s3_full_access" {
  name_prefix        = "s3-bucket_full_access"
  description = "Full access to a specific S3 bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowAllOnSpecificBucket"
        Effect = "Allow"
        Action = "s3:*"
        Resource = [
          "arn:aws:s3:::aws-s3-soc-lab-253490786526-eu-west-3-an",
          "arn:aws:s3:::aws-s3-soc-lab-253490786526-eu-west-3-an/*"
        ]
      }
    ]
  })
}

resource "aws_iam_policy" "s3_get_commands" {
  name_prefix        = "s3-bucket-get-commands"
  description = "restricted access to a specific S3 bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowAllOnSpecificBucket"
        Effect = "Allow"
        Action = "s3:GetObject"
        Resource = [
          "arn:aws:s3:::aws-s3-soc-lab-253490786526-eu-west-3-an",
          "arn:aws:s3:::aws-s3-soc-lab-253490786526-eu-west-3-an/*"
        ]
      }
    ]
  })
}


#-------------policy role SSM-----------------------------------
resource "aws_iam_role_policy_attachment" "ansible_ssm_attach_to_worker" {
  role       = aws_iam_role.ansible_worker_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ansible_ssm_attach_to_manager" {
  role       = aws_iam_role.ansible_manager_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMFullAccess"
}


#--------------policy role S3------------------------------------
resource "aws_iam_role_policy_attachment" "s3_rights_to_manager" {
  role       = aws_iam_role.ansible_manager_role.name
  policy_arn = aws_iam_policy.s3_full_access.arn
}

resource "aws_iam_role_policy_attachment" "s3_rights_to_worker" {
  role       = aws_iam_role.ansible_worker_role.name
  policy_arn = aws_iam_policy.s3_get_commands.arn
}

#--------------policy role EC2 Retrieve-------------------------
resource "aws_iam_role_policy_attachment" "ec2_read" {
  role       = aws_iam_role.ansible_manager_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
}

#---------------Instance Profile--------------------------------
resource "aws_iam_instance_profile" "ansible_manager_profile" {
  name = "ansible-manager-profile"
  role = aws_iam_role.ansible_manager_role.name
}

resource "aws_iam_instance_profile" "ansible_worker_profile" {
  name = "ansible-worker-profile"
  role = aws_iam_role.ansible_worker_role.name
}


#--------------Key pair --------------------------
resource "aws_key_pair" "deployer" {
  key_name   = "aws-hadoop-key"
  public_key = file("../../aws-hadoop.pub")
}