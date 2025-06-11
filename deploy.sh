#!/bin/bash
echo "Zipping updated Lambda code..."
cd lambda
zip -r ../terraform/lambda_function.zip . > /dev/null
cd ../terraform
echo "Applying Terraform..."
terraform apply
