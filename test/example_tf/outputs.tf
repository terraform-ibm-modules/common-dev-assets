## Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = ibm_is_vpc.vpc.id
}

output "vpc_crn" {
  description = "CRN of the VPC"
  value       = ibm_is_vpc.vpc.crn
}
