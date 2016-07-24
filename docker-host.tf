/* App servers */
resource "aws_instance" "docker-host" {
  count = 0
  ami = "${lookup(var.amis, var.aws_region)}"
  instance_type = "t2.small"
  subnet_id = "${aws_subnet.public.id}"
  vpc_security_group_ids = ["${aws_security_group.app.id}"]
  key_name = "${aws_key_pair.sshkey.key_name}"
  source_dest_check = false
  associate_public_ip_address = true
  tags = {
    Name = "docker-host-${count.index}"
  }
  connection {
    user = "ubuntu"
    key_file = "~/.ssh/id_rsa"
  }
  provisioner "file" {
    source = "install-docker.sh"
    destination = "/tmp/install-docker.sh"
  }

  provisioner "remote-exec" {
     inline = [ "bash /tmp/install-docker.sh" ]
  }
  provisioner "file" {
    source = "install-rancher-agent.sh"
    destination = "/tmp/install-rancher-agent.sh"
  }

  provisioner "remote-exec" {
     inline = [ "bash /tmp/install-rancher-agent.sh ${var.rancher_domain} ${var.rancher_access_key} ${var.rancher_secret_key}" ]
  }
}

output "docker-host" {
  value = "${join(",", aws_instance.docker-host.*.public_ip)}"
}

resource "aws_elb" "app" {
  name = "app-elb"
  subnets = [ "${aws_subnet.public.id}" ]
  security_groups = ["${aws_security_group.app.id}"]
  listener {
    instance_port = 80
    instance_protocol = "http"
    lb_port = 80
    lb_protocol = "http"
  }
  instances = ["${aws_instance.docker-host.*.id}"]
}

output "elb.name" {
  value = "${aws_elb.app.dns_name}"
}

resource "aws_security_group" "app" {
  name = "applicataion"
  description = "Security group for our app"
  vpc_id = "${aws_vpc.default.id}"

  ingress {
    from_port   = "22"
    to_port     = "22"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = "80"
    to_port     = "80"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = "8983"
    to_port     = "8983"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = "22"
    to_port     = "22"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = "443"
    to_port     = "443"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = "80"
    to_port     = "80"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    self        = true
  }

  egress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    self        = true
  }

  tags { 
    Name = "application" 
  }
}

