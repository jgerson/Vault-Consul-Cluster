#Main VPC for the configuration

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name            = "VaultCluster VPC - ${var.environment_name}"
  cidr            = "10.0.0.0/16"
  azs             = ["${var.avail_zones}"]
  private_subnets = ["10.0.${var.cluster == "Secondary" ? 3 : 0}.0/24", "10.0.${var.cluster == "Secondary" ? 4 : 1}.0/24", "10.0.${var.cluster == "Secondary" ? 5 : 2}.0/24"]
  public_subnets  = ["10.0.${var.cluster == "Secondary" ? 103 : 100}.0/24", "10.0.${var.cluster == "Secondary" ? 104 : 101}.0/24", "10.0.${var.cluster == "Secondary" ? 105 : 102}.0/24"]

  enable_nat_gateway                 = true
  enable_vpn_gateway                 = false
  enable_dns_hostnames               = true
  propagate_public_route_tables_vgw  = true
  propagate_private_route_tables_vgw = true
  single_nat_gateway                 = true

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

resource "aws_elb" "vault_elb" {
  name            = "${var.environment_name}"
  subnets         = ["${module.vpc.public_subnets}"]
  security_groups = ["${module.vault_service.this_security_group_id}"]

  listener {
    instance_port     = 8200
    instance_protocol = "http"
    lb_port           = 8200
    lb_protocol       = "http"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "TCP:8200"
    interval            = 30
  }

  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400

  tags {
    Name = "${var.environment_name}"
  }
}

data "aws_route53_zone" "selected" {
  name = "spacelyspacesprockets.info."
}

resource "aws_route53_record" "www" {
  zone_id = "${data.aws_route53_zone.selected.zone_id}"
  name    = "vaultcluster-${var.environment_name}.spacelyspacesprockets.info"
  type    = "CNAME"
  ttl     = "300"
  records = ["${aws_elb.vault_elb.dns_name}"]
}