#!/bin/bash
# Updating YUM. Installing HTTPD.
yum update -y
yum install -y httpd.x86_64

# Starting and enabling HTTPD
systemctl enable --now httpd.service

# Setting homepage index.html file.
cat <<EOF >> /var/www/html/index.html
<html>
    <style>
    
    .center {
        display: block;
        margin-left: auto;
        margin-right: auto;
        width: 50%;
    }
    </style>
    <title>Pluralsight Prep</title>
    <body>
        <span style="padding-top: 200px;"></span>
        # <img src="<INSERT_YOUR_S3_OBJECT_URL_HERE" style="max-width: 400px; display: block; margin-left: auto; margin-right: auto; width: 50%;"/>
        <span style="padding-top: 100px;"></span>
        <p></p>
        <h1> <center>Hello from $(hostname -f)!</center></h1>
    </body>
<html>
EOF

# Restarting HTTPD service.
systemctl restart httpd.service