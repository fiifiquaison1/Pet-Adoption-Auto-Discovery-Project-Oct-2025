# Nexus Module - Output Values
# Output values for the Nexus module

output "nexus_ip" {
  description = "Public IP address of the Nexus server"
  value       = aws_instance.nexus-server.public_ip
}