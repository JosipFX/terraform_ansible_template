resource "aws_security_group" "terraform-instance" {
  name = "terraform-instance-security-group"

// ssh access
	ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  // website access
  ingress {
    from_port        = 8080
    to_port            = 8080
    protocol        = "tcp"
    cidr_blocks        = ["0.0.0.0/0"]
  }

	// outbound connections
	egress {
		from_port = 0
		to_port = 0
		protocol = "-1"
		cidr_blocks = ["0.0.0.0/0"]
	}
}

data "aws_subnet_ids" "default" {
    vpc_id = data.aws_vpc.default.id
}

data "aws_vpc" "default" {
    default = true
}

# login access for the EC2 instances
resource "aws_key_pair" "terraform-key" {
  key_name   = "terra_ans"
  public_key = file("~/.ssh/terra_ans.pub")
}

# ec2 instances
resource "aws_instance" "lb-instance" {
  count         = var.instance_count 
  ami           = var.ami
  instance_type = var.instance_type
  key_name      = aws_key_pair.terraform-key.key_name

	root_block_device {
    volume_size = var.volume_size
    volume_type = var.volume_type
  }

  tags = {
    Name  = "Terraform-${count.index + 1}"
		Group = "LB" // needed for ansible
  }

	vpc_security_group_ids = [
    aws_security_group.terraform-instance.id
  ]

	depends_on = [aws_security_group.terraform-instance]
}

# security group for loadbalancer
resource "aws_security_group" "alb" {
	name = "terraform-alb-security-group"

	# Allow incoming HTTP
	ingress {
		from_port = 80
		to_port = 80
		protocol = "tcp"
		cidr_blocks = ["0.0.0.0/0"]
	}

	# Allow incoming HTTPS
	ingress {
		from_port = 443
		to_port = 443
		protocol = "tcp"
		cidr_blocks = ["0.0.0.0/0"]
	}

	# Allow outgoing traffic
	egress {
		from_port = 0
		to_port = 0
		protocol = "-1"
		cidr_blocks = ["0.0.0.0/0"]
	}
}

# loadbalancer
resource "aws_lb" "alb" {
    name = "terraform-alb" // name of the LB. Must be unique within the AWS account.
    load_balancer_type = "application" // other types would be gateway or network
    subnets = data.aws_subnet_ids.default.ids // the LB is attached to subnets listed here
    security_groups = [aws_security_group.alb.id]
}

# listener, used to redirect http traffic to https
resource "aws_lb_listener" "http" {
    load_balancer_arn = aws_lb.alb.arn 
    port = 80
    protocol = "HTTP"

    # by default redirect all http traffic to https
		default_action {
			type = "redirect"

			redirect {
				port        = "443"
				protocol    = "HTTPS"
				status_code = "HTTP_301"
			}
		}
}

# listener
resource "aws_lb_listener" "https" {
    load_balancer_arn = aws_lb.alb.arn
    port = 443
    protocol = "HTTPS"
    certificate_arn = "arn:aws:acm:us-east-1:849573070971:certificate/399edf93-02a0-42f6-993f-ee16daa65634" // certificate for josip.io, created in ACM (cert manager)

    # page 404
    // currently happens never, since the listener rules has no paths defined 
    default_action {
        type = "fixed-response"
        fixed_response {
          content_type = "text/plain"
          message_body = "404: Fehler"
          status_code = 404
        }
    }
}

resource "aws_lb_listener_rule" "listener_rule_http" {
    listener_arn    = aws_lb_listener.http.arn
    priority        = 100
    
    condition {
      path_pattern {
        values = ["*"] // define here the correct/reachable paths
      }
    }
    
    action {
        type = "forward"
        target_group_arn = aws_lb_target_group.lb-target-group.arn
    }
}

resource "aws_lb_listener_rule" "listener_rule_https" {
    listener_arn    = aws_lb_listener.https.arn
    priority        = 100
    
    condition {
      path_pattern {
        values = ["*"] // define here the correct/reachable paths
      }
    }
    
    action {
        type = "forward"
        target_group_arn = aws_lb_target_group.lb-target-group.arn
    }
}

# checks if instances are still up, if one fails to pass health check, traffic will not be forwarded to it
resource "aws_lb_target_group" "lb-target-group" {
    name = "terraform-aws-lb-target-group"
    port = 8080
    protocol = "HTTP"
    vpc_id = data.aws_vpc.default.id

    health_check {
        path                = "/"
        protocol            = "HTTP"
        matcher             = "200"
        interval            = 15
        timeout             = 3
        healthy_threshold   = 2
        unhealthy_threshold = 2
    }
}

# assign all instances to lb-target-group target group 
resource "aws_alb_target_group_attachment" "lb_target_group" {
  count = length(aws_instance.lb-instance) 
  target_group_arn = aws_lb_target_group.lb-target-group.arn
  target_id = aws_instance.lb-instance[count.index].id
}