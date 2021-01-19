data "aws_vpc" "tf_vpc" {
    default = true
}

/*
data "aws_iam_policy" "ec2_service_policy" {
  arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}
*/

resource "aws_key_pair" "tf_key" {
  key_name = "tf_key"
  public_key = file("~/.ssh/tf_key.pub")
}

resource "aws_iam_role" "tf_ec2_service_role" {
  name = "tf_ec2_service_role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "tf_ec2_profile" {
  name = "tf_ec2_profile"
  role = aws_iam_role.tf_ec2_service_role.name
}


resource "aws_iam_role_policy" "tf_ec2_policy" {
  name = "tf_ec2_policy"
  role = aws_iam_role.tf_ec2_service_role.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:*"
      ],
      "Effect": "Allow",
      "Resource": "*"
    },
    {
      "Action": [
        "ec2:*"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}


/*
resource "aws_iam_role_policy_attachment" "tf_ec2_service_role_policy_attach" {
   role       = aws_iam_role.tf_ec2_service_role.name
   policy_arn = data.aws_iam_policy.ec2_service_policy.arn
}
*/

resource "aws_security_group" "tf_sg_pub" {
    name = "tf_sg_pub"
    tags = {
      "Name" = "tf_sg_pub"
    }
    ingress = [ {
      cidr_blocks = [ "0.0.0.0/0" ]
      description = "ssh"
      from_port = 22
      to_port = 22
      ipv6_cidr_blocks = [ ]
      prefix_list_ids = [ ]
      protocol = "tcp"
      security_groups = [ ]
      self = false
    },
    {
      cidr_blocks = [ var.your_ip_addr, data.aws_vpc.tf_vpc.cidr_block ]
      description = "oracle"
      from_port = 1521
      to_port = 1521
      ipv6_cidr_blocks = [ ]
      prefix_list_ids = [ "pl-e1a54088" ]
      protocol = "tcp"
      security_groups = [ ]
      self = false
    },
    {
      cidr_blocks = [ var.your_ip_addr, data.aws_vpc.tf_vpc.cidr_block ]
      description = "postgres"
      from_port = 5432
      to_port = 5432
      ipv6_cidr_blocks = [ ]
      prefix_list_ids = [ "pl-e1a54088" ]
      protocol = "tcp"
      security_groups = [ ]
      self = false
    } ]
    egress = [ {
      cidr_blocks = [ "0.0.0.0/0" ]
      description = ""
      from_port = 0
      to_port = 0
      ipv6_cidr_blocks = [ ]
      prefix_list_ids = [ ]
      protocol = "-1"
      security_groups = [ ]
      self = false
    }]   
}


#
# Output Section
#
output "tf_key" {
    value = aws_key_pair.tf_key.key_pair_id
}

output "tf_sg_pub" {
    value = aws_security_group.tf_sg_pub.id 
}