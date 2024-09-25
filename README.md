# Dual-homed-instance
Multiple network interfaces for an Amazon EC2 instances

## Attaching multiple network interfaces to an instance is useful when you need the following:

- A management network.

- Network and security appliances.

- Dual-homed instances with workloads in different subnets or VPCs.

- A low-budget, high-availability solution.

# Infrastructure

## VPC
Created a Virtual Private Cloud with:

- Internet Gateway

- Two subnets 
    - Public subnet 
    - Private management subnet

- Two Network Interface
    - Public network interface hosted inside the public subnet with a security group which allows http traffic from the wider internet
    - Private network interface with a security group that only allows ssh traffic from instances inside the management subnet

- An elasttic ip
    - The elastic ip is attached to the public network interface to give the interface a public ip.

- Amazon EC2 instance
    - The instance hosts the Apache server serving our web page. The web page is connected through the public network interface through http (port 80)
