#!/bin/sh

IPT=/sbin/iptables
# NAT interface
NIF=enp0s9
# NAT IP address
NIP='10.0.98.100'

# Host-only interface
HIF=enp0s3
# Host-only IP addres
HIP='192.168.60.100'

# DNS nameserver 
NS='10.0.98.3'

SS = '10.0.98.2'
PS = '192.168.60.111'

## Reset the firewall to an empty, but friendly state

# Flush all chains in FILTER table
$IPT -t filter -F
# Delete any user-defined chains in FILTER table
$IPT -t filter -X
# Flush all chains in NAT table
$IPT -t nat -F
# Delete any user-defined chains in NAT table
$IPT -t nat -X
# Flush all chains in MANGLE table
$IPT -t mangle -F
# Delete any user-defined chains in MANGLE table
$IPT -t mangle -X
# Flush all chains in RAW table
$IPT -t raw -F
# Delete any user-defined chains in RAW table
$IPT -t mangle -X

#The command for changing default firewall policy to DROP
$IPT -t filter -P INPUT DROP
$IPT -t filter -P OUTPUT DROP
$IPT -t filter -P FORWARD DROP


#$IPT -A INPUT -p tcp --dport 80 -j DROP  #The command for blocking host from viewing HTTP

#The command for enabling traffic from loopback interface
$IPT -A INPUT -i lo -j ACCEPT
$IPT -A OUTPUT -o lo -j ACCEPT

#The command for allowing Server A to ping the other interfaces
$IPT -A INPUT -p icmp --icmp-type 0 -j ACCEPT
$IPT -A OUTPUT -p icmp --icmp-type 8 -j ACCEPT 

#The command for allowing Server A to ping all hosts
$IPT -A INPUT -p tcp -s $NS --sport 53 -j ACCEPT      #For tcp
$IPT -A OUTPUT -p tcp -d $NS --dport 53 -j ACCEPT     #For tcp

$IPT -A INPUT -p udp -s $NS --sport 53 -j ACCEPT      #For udp
$IPT -A OUTPUT -p udp -d $NS --dport 53 -j ACCEPT     #For udp


#The command for enabling stateful firewall
$IPT -t filter -A INPUT -p tcp -m multiport --sports 80,443 -m conntrack --ctstate ESTABLISHED -j ACCEPT
$IPT -t filter -A INPUT -p tcp -m multiport --dports 80,443 -m conntrack --ctstate NEW, ESTABLISHED -j ACCEPT

$IPT -t filter -A OUTPUT -p tcp -m multiport --dports 80,443 -m conntrack --ctstate NEW, ESTABLISHED -j ACCEPT
$IPT -t filter -A OUTPUT -p tcp -m multiport --sports 80,443 -m conntrack --ctstate ESTABLISHED -j ACCEPT


#The command for enabling SSH from apache2 server for web browser on host OS
$IPT -A OUTPUT -p tcp -s $SS --dport 22 -j ACCEPT
$IPT -A INPUT -p tcp -d $SS --sport 22 -j ACCEPT

#The command for enabling HTTPs but not HTTP from apache2 server for web browser on host OS
$IPT -I INPUT -p tcp -d 10.0.98.100 --dport 80 -j DROP


#The command for pinging Server A from Client A
$IPT -A INPUT -p icmp --icmp-type 8 -s $PS -j ACCEPT
$IPT -A OUTPUT -p icmp --icmp-type 0 -d $PS -j ACCEPT

#The command for enabling SSH from Client A to Server A
$IPT -A OUTPUT -p tcp -d $PS --sport 22 -m conntrack --ctstate ESTABLISHED -j ACCEPT
$IPT -A INPUT -p tcp -s $PS --dport 22 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT

#The command for enabling IP forwarding on Server A
sysctl -w net.ipv4.ip_forward=1
sysctl -p

#The command for changing iptables to forward packets
$IPT -t filter -A FORWARD -i $HIF -j ACCEPT
$IPT -t filter -A FORWARD -i $NIF -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

#The command for enabling SNAT on Server A
$IPT -t nat -A POSTROUTING -j SNAT -o $NIF --to $NIP


# Create logging chains
$IPT -t filter -N input_log
$IPT -t filter -N output_log
$IPT -t filter -N forward_log

# Set some logging targets for DROPPED packets
$IPT -t filter -A input_log -j LOG --log-level notice --log-prefix "input drop: " 
$IPT -t filter -A output_log -j LOG --log-level notice --log-prefix "output drop: " 
$IPT -t filter -A forward_log -j LOG --log-level notice --log-prefix "forward drop: " 
echo "Added logging"

# Return from the logging chain to the built-in chain
$IPT -t filter -A input_log -j RETURN
$IPT -t filter -A output_log -j RETURN
$IPT -t filter -A forward_log -j RETURN



# These rules must be inserted at the end of the built-in
# chain to log packets that will be dropped by the default drop policy
$IPT -t filter -A INPUT -j input_log
$IPT -t filter -A OUTPUT -j output_log
$IPT -t filter -A FORWARD -j forward_log
