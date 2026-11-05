output "application_url" {
  description = "The URL to access the application."
  value       = "http://${module.compute.alb_dns_name}"
}