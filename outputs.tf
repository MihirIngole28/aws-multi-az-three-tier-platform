output "application_url" {
  description = "The URL to access the application."
  value       = "http://${aws_lb.main.dns_name}"
}