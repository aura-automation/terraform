
variable "ami-name"{
	type = "map"
	default = {
		"compute-ami" = "ami-c39604b0"
		"nat-ami" = "ami-6975eb1e"
		}
}

resource "aws_instance" "jb2-vpc-private" {
  ami           = "${var.ami-name.compute-ami}"
  instance_type = "t2.micro"
  key_name = "FIL-UrbanPatternsKeys"
  iam_instance_profile = "${aws_iam_instance_profile.test_profile.id}"
  user_data = <<EOF
#!/bin/bash
sudo yum -y install mysql mysql-server
sudo /sbin/service mysqld start
mysqladmin -u root password passw0rd
aws s3 cp s3://jk2-app/sql/create_database.sql /tmp
mysql -u root -ppassw0rd < /tmp/create_database.sql 

echo "Sync war files "

aws s3 sync s3://jk2-app/war /tmp

echo "Install liberty server"
sudo java  -jar /tmp/wlp-developers-runtime-8.5.5.3.jar  --acceptLicense /opt/was/liberty
sudo yum -y install java-1.8.0-openjdk-devel
sudo echo jdbc.hostname=localhost>>/tmp/war/WEB-INF/classes/JKEDB.properties
sudo jar cmf /tmp/war/META-INF/MANIFEST.MF /tmp/JKE.war -C /tmp/war .
sudo mkdir -p /opt/was/liberty/wlp/usr/servers/defaultServer/dropins

sudo cp /tmp/JKE.war /opt/was/liberty/wlp/usr/servers/defaultServer/dropins

sudo echo "<server description=\"new server\">
      <featureManager>
      	 <feature>jsp-2.2</feature>
      </featureManager>

       <httpEndpoint id=\"defaultHttpEndpoint\"                  
       		host=\"*\"                  
       		httpPort=\"9080\"                 
       		httpsPort=\"9443\" />
       	</server>" > /opt/was/liberty/wlp/usr/servers/defaultServer/server.xml


sudo /opt/was/liberty/wlp/bin/server stop
sudo /opt/was/liberty/wlp/bin/server start

EOF

  tags{
  	name = "JB"
  }
}


resource "aws_iam_instance_profile" "test_profile" {
    name = "test_profile"
    roles = ["${aws_iam_role.role.name}"]
}

resource "aws_iam_role" "role" {
    name = "test_role"
    path = "/"
    assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {"AWS": "*"},
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
}

resource "aws_iam_policy_attachment" "test-attach" {
    name = "test-attachment"
    roles = ["${aws_iam_role.role.name}"]
    policy_arn = "${aws_iam_policy.policy.arn}"
}

resource "aws_iam_policy" "policy" {
    name = "test_policy"
    path = "/"
    policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:*"            ],
            "Resource": [
                "arn:aws:s3:::jk2-app/sql/*",
                "arn:aws:s3:::jk2-app/war/*"

            ]
        }
    ]
}
EOF
}