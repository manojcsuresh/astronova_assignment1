resource "aws_eip" "nlb_eip" {
  domain = "vpc"
}

resource "aws_lb" "astronova_nlb" {
  name               = "astronova-nlb"
  internal           = false
  load_balancer_type = "network"

  subnet_mapping {
    subnet_id     = data.aws_subnets.default.ids[0]
    allocation_id = aws_eip.nlb_eip.id
  }

  tags = {
    Name        = "astronova-nlb"
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_lb_target_group" "http" {
  name     = "astronova-http-tg"
  port     = 30080
  protocol = "TCP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    protocol = "TCP"
    port     = "traffic-port"
  }
}

resource "aws_lb_target_group" "https" {
  name     = "astronova-https-tg"
  port     = 30443
  protocol = "TCP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    protocol = "TCP"
    port     = "traffic-port"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.astronova_nlb.arn
  port              = 80
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.http.arn
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.astronova_nlb.arn
  port              = 443
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.https.arn
  }
}

resource "aws_lb_target_group_attachment" "worker_http" {
  count            = 2
  target_group_arn = aws_lb_target_group.http.arn
  target_id        = aws_instance.k8s_nodes[count.index + 1].id
  port             = 30080
}

resource "aws_lb_target_group_attachment" "worker_https" {
  count            = 2
  target_group_arn = aws_lb_target_group.https.arn
  target_id        = aws_instance.k8s_nodes[count.index + 1].id
  port             = 30443
}
