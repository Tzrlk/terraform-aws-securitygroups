
resource "aws_security_group" "Group" {
	for_each = toset([ "Albs", "Apps", "Data" ])
}

module "NetSec" {
	source  = "../.."

	SecurityGroupIds = {
		Albs = aws_security_group.Group["Albs"].id # Public-facing load balancers.
		Apps = aws_security_group.Group["Apps"].id # Protected apps
		Data = aws_security_group.Group["Data"].id # Private database
	}

	CidrBlocks = {
		Anywhere = "0.0.0.0/0" # A.k.a The internet. Always included, but can be overridden.
		AdminVm  = "123.123.123.123/32" # An extremely bad example, don't actually do this.
	}

	PortRanges = {
		Dns    = { Proto = "udp", Min = 53,   Max = 53 }
		Http   = { Proto = "tcp", Min = 80,   Max = 80 }
		Https  = { Proto = "tcp", Min = 443,  Max = 443 }
		Https2 = { Proto = "tcp", Min = 8443, Max = 8443 }
		Jdbc   = { Proto = "tcp", Min = 5432, Max = 5432 }
		Ssh    = { Proto = "tcp", Min = 22,   Max = 22 }
	}

	Rules = {
		Anywhere = {
			Albs = [ "Http", "Https" ] # The internet can access albs via https or http (which redirects to https).
		}
		Albs = {
			Apps = [ "Https2" ] # Albs can access apps via unreserved https.
		}
		Apps = {
			Anywhere = [ "Https" ] # Apps can access the internet via https.
			Apps     = [ "Https2", "Dns" ] # Apps can access each other via https and dns.
			Data     = [ "Jdbc", "Dns" ] # Apps can access the database via JDBC.
		}
		AdminVm = {
			Apps = [ "Https2", "Ssh" ] # The admin VM can access apps via unreserved https or ssh.
			Data = [ "Https",  "Ssh", "Jdbc" ] # The admin VM can access the database by https, ssh, and jdbc.
		}
		Data = {} # Databases don't initiate any connections.
	}

}

# Output all the security rules generated by the module and attached to the
# "Alb" security group.
output "NetSecAlbRules" {
	value = [ for Rule in module.NetSec.Rules["Albs"] : Rule["Id"] ]
}

