provider "aws" {
	region = "us-west-2"
}

data "aws_vpc" "default" {
	default = true
}

data "aws_subnet_ids" "all" {
	vpc_id = "${data.aws_vpc.default.id}"
}

data "aws_ami" "amazon-linux-2" {
	most_recent = true
	owners = ["amazon"]
	filter {
		name = "name"
		values = [
			"amzn2-ami-hvm-*-x86_64-gp2",
		]
	}

	filter {
		name = "owner-alias"
		values = [ "amazon"]
	}
	filter {
		name = "state"
		values = [ "available" ]
	}
}

module "security_group" {
	source = "terraform-aws-modules/security-group/aws"
	version = "2.17.0"
	
	name = "clouddev"
	description = "security group for cloud dev box"
	vpc_id = "${data.aws_vpc.default.id}"
	ingress_cidr_blocks = ["0.0.0.0/0"]
	ingress_rules       = ["http-80-tcp", "https-443-tcp", "ssh-tcp", "all-icmp"]
	egress_rules        = ["all-all"]
	ingress_with_cidr_blocks = [
		{
			from_port = 60000
			to_port = 61000
			protocol = "udp"
			description = "mosh"
			cidr_blocks = "0.0.0.0/0"
		},
	]
}

resource "aws_eip" "this" {
	vpc = true
	instance = "${module.ec2.id[0]}"
}

resource "aws_iam_role" "attach-ebs-role" {
	name = "attach-ebs-role"
	assume_role_policy = "${file("assume-role-policy.json")}"
}

resource "aws_iam_policy" "policy" {
	name = "attach-ebs-policy"
	description = "enable ebs volumes to be attached"
	policy = "${file("policy-ebs-attach.json")}"
}

resource "aws_iam_policy_attachment" "policy-attach" {
	name = "policy-attachment"
	roles = ["${aws_iam_role.attach-ebs-role.name}"]
	policy_arn = "${aws_iam_policy.policy.arn}"
}

resource "aws_iam_instance_profile" "clouddev_profile" {
	name = "clouddev_profile"
	role = "${aws_iam_role.attach-ebs-role.name}"
}

module "ec2" {
	source = "terraform-aws-modules/ec2-instance/aws"
	instance_count = 1
	name = "clouddev"
	ami = "${data.aws_ami.amazon-linux-2.id}"
	# $13/mo if you run full time on small vs $6 micro
	instance_type = "t3a.small" 
	iam_instance_profile = "${aws_iam_instance_profile.clouddev_profile.name}"
	user_data = "${file("user_data.sh")}"
	subnet_id                   = "${element(data.aws_subnet_ids.all.ids, 0)}"
  	vpc_security_group_ids      = ["${module.security_group.this_security_group_id}"]
  	associate_public_ip_address = true

  	root_block_device = [{
    	volume_type = "gp2"
    	volume_size = 10
  	}]
}

resource "aws_ebs_volume" "workspace" {
	count = 1
	# availability_zone = "${module.ec2.availability_zone[count.index]}"
	# This seems janky to hardcode but making it dependent on ec2 forces recreation
	# Perhaps can introspect from the subnet
	availability_zone = "us-west-2a"
	size = 20
	type = "gp2"
	tags = {
		Name = "WorkspaceVol"
	}
}
