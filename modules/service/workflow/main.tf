module "frontend" {

  source      = "../s3"
  bucket_name = var.bucket_name

}

module "frontend_cloudfront" {
  depends_on     = [module.frontend]
  source         = "../cloudfront"
  bucket_name_id = module.frontend.bucket_name

}

module "vpc_subnet_module" {
  source = "terraform-aws-modules/vpc/aws"

  name            = var.vpc_subnet_module.name
  cidr            = var.vpc_subnet_module.cidr_block
  azs             = var.vpc_subnet_module.azs
  public_subnets  = var.vpc_subnet_module.public_subnets
  private_subnets = var.vpc_subnet_module.private_subnets

  enable_nat_gateway = var.vpc_subnet_module.enable_nat_gateway

}

module "bastion_host" {
  source     = "../bastion_host"
  depends_on = [module.vpc_subnet_module]
  subnet_id  = module.vpc_subnet_module.private_subnets[1]
}

module "asg" {
  source     = "../asg"
  depends_on = [module.vpc_subnet_module]
  subnet_ids = module.vpc_subnet_module.private_subnets
  vpc_id     = module.vpc_subnet_module.vpc_id

  cidr_block = module.vpc_subnet_module.vpc_cidr_block
  target_group_arn = module.ecs_ec2_alb.target_group_arns[0]
}



module "ecs_ec2_alb" {
  source = "terraform-aws-modules/alb/aws"
  version = "~> 6.0"

  name    = "ecs-ec2-alb"
  vpc_id  = module.vpc_subnet_module.vpc_id
  subnets = module.vpc_subnet_module.public_subnets
  load_balancer_type = "application"


  target_groups = [
    {
      backend_protocol = "HTTPS"
      backend_port     = 443
      target_type      = "instance"
    }
  ]


    https_listeners = [
    {
      port               = 443
      protocol           = "HTTPS"
      certificate_arn    = "arn:aws:iam::123456789012:server-certificate/test_cert-123456789012"
      target_group_index = 0
    }
  ]

  http_tcp_listeners = [
    {
      port        = 80
      protocol    = "HTTP"
      action_type = "redirect"
      redirect = {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  ]

}


module "rds" {
  source = "../rds"
  depends_on = [module.vpc_subnet_module]
  subnet_ids = [module.vpc_subnet_module.private_subnets[0], module.vpc_subnet_module.private_subnets[1]]
}

























