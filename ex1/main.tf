# create a provider
provider "aws" {
  region = "us-east-1"
  access_key = "AKIAZVR5BB2AF5XGU7HF"
  secret_key = "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"
}



#create vpc
resource "aws_vpc" "luxembourg_office_network" {
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "LuxOfficeNetwork"
  }
}


#create internet gateway
resource "aws_internet_gateway" "company_public_gateway" {
  vpc_id = aws_vpc.luxembourg_office_network.id

  tags = {
    Name = "CompanyPublicGateway"
  }
}
#create custom route table
#this helps to allow traffic from our subnet to the internet
resource "aws_route_table" "company_route_table" {
  vpc_id = aws_vpc.example.id

  route = [
      #send all traffic from this subnet to the internet gateway
    {
      cidr_block = "10.0.1.0/24"
      gateway_id = aws_internet_gateway.company_public_gateway.id
    },
      #send all IPV6 traffic to the internet gateway
    {
      ipv6_cidr_block        = "::/0"
      egress_only_gateway_id = aws_internet_gateway.company_public_gateway.id
    }
  ]

  tags = {
    Name = "example"
  }
}

#create a subnet
resource "aws_subnet" "luxembourg_office_subnet_pcs" {
  vpc_id     = aws_vpc.luxembourg_office_network.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a" 

  tags = {
    Name = "LuxOfficeSubNetPCS"
  }
}


#associate subnet with route table
# associates a subnet with a route table
resource "aws_route_table_association" "luxofficesubnet_routetable_association" {
  subnet_id      = aws_subnet.luxembourg_office_subnet_pcs.id
  route_table_id = aws_route_table.company_route_table.id
}

#create security group and allow only ports 22, 443, 80
resource "aws_security_group" "allow_web_traffic" {
  name        = "allow_web_traffic"
  description = "Allow web traffic for ssh http and tls"
  vpc_id      = aws_vpc.luxembourg_office_network.id
 
  #specifies a range of ports to be allowed and in this case Tcp 443:447
  # allows all ip addresses to access into this port since it is a web server
  # any internet address can access into this port

  ingress = [
    {
      description      = "HTTPS Traffic"
      from_port        = 443
      to_port          = 443
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    },
    {
      description      = "HTTP Traffic"
      from_port        = 80
      to_port          = 80
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    },
    {
      description      = "SSH Traffic"
      from_port        = 22
      to_port          = 22
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
  ]
  
  #allow all ports in the egress direction for any protocol -1
  egress = [
    {
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
  ]

  tags = {
    Name = "AllowWeb-HTTPSHTTPSSH"
  }
}

#create a network interface with an ip in the subnet that was previously created

resource "aws_network_interface" "luxoffice_webserver_nic" {
  subnet_id       = aws_subnet.luxembourg_office_subnet_pcs.id
  private_ips     = ["10.0.12.11"]
  security_groups = [aws_security_group.allow_web_traffic.id]
}
#assign an elastic ip to the network interface
#eip relies on the creation of the internet gateway
#eip must be assigned on a device in a subnet or vpc that has an internet gateway 


resource "aws_eip" "webserver_nic_elastic_ip" {
  vpc                       = true
  network_interface         = aws_network_interface.luxoffice_webserver_nic.id
  associate_with_private_ip = "10.0.12.11"
  depends_on = [aws_internet_gateway.company_public_gateway]
}

#create an ubuntu server on an aws instance and install enable apache2 on this server
# create a resource within the provider
#if possible always pass in an availability zone
resource "aws_instance" "web_server_1" {
  ami           = "ami-0747bdcabd34c712a"
  instance_type = "t2.micro"
  availability_zone = "us-east-1a" 
  key_name = "rootkey"
  network_interface = {
    device_index = 0
    network_interface_id = aws_network_interface.luxoffice_webserver_nic.id
  }
  #Tell terraform on the deployment of this server to run commands to install Apache on this server
  #Update ubuntu OS
  #Install apache
  #Start apache service
  #You can install other packages here by command line
  #end with EOF
  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install apache2 -y
              sudo systemctl start apache2
              sudo bash -c 'echo This is a web server > /var/www/html/index.html'
              EOF

  tags = {
    Name = "Webserver1"
  }
}