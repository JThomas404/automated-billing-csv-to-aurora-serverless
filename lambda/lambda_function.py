import json  # For working with JSON data
import boto3  # AWS SDK for interacting with AWS services
import pymysql  # Required if using MySQL directly (not used here but may be kept for future use)
import csv  # To read CSV data
import os  # To interact with environment variables
import logging  # For logging purposes
import io  # For handling in-memory data streams

# Currency conversion rates to USD
currency_conversion_to_usd = {
    'USD': 1,
    'CAD': 0.79,
    'MXN': 0.05
}

# Aurora database and Secrets Manager resource details
database_name = 'boto3_rds_instance'
secrets_store_arn = 'arn:aws:secretsmanager:us-east-1:533267010082:secret:aurora_billing_db_secret-tw5Ix6'
db_cluster_arn = 'arn:aws:rds:us-east-1:533267010082:cluster:aurora-billing-cluster'

# Boto3 client for S3
s3_client = boto3.client('s3')

# Boto3 client for executing SQL statements on Aurora Serverless
rds_client = boto3.client('rds-data')

# Set up logging configuration
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Function to process each CSV row and insert it into the database
def process_record(record):
    # Unpack the CSV row into individual fields
    id, company_name, country, city, product_line, item, bill_date, currency, bill_amount = record

    # Convert the billing amount to float
    bill_amount = float(bill_amount)

    # Get the exchange rate for the currency
    rate = currency_conversion_to_usd.get(currency)

    # If the currency is unsupported, log and skip the record
    if not rate:
        logger.info(f"No rate found for currency: {currency}")
        return

    # Calculate the bill amount in USD
    usd_amount = bill_amount * rate

    # SQL statement to insert the billing record into the billing_data table
    sql_statement = """
        INSERT IGNORE INTO billing_data
        (id, company_name, country, city, product_line, item, bill_date, currency, bill_amount, bill_amount_usd)
        VALUES (:id, :company_name, :country, :city, :product_line, :item, :bill_date, :currency, :bill_amount, :usd_amount)
    """

    # Parameters to bind to the SQL statement
    sql_parameters = [
        {'name': 'id', 'value': {'stringValue': id}},
        {'name': 'company_name', 'value': {'stringValue': company_name}},
        {'name': 'country', 'value': {'stringValue': country}},
        {'name': 'city', 'value': {'stringValue': city}},
        {'name': 'product_line', 'value': {'stringValue': product_line}},
        {'name': 'item', 'value': {'stringValue': item}},
        {'name': 'bill_date', 'value': {'stringValue': bill_date}},
        {'name': 'currency', 'value': {'stringValue': currency}},
        {'name': 'bill_amount', 'value': {'doubleValue': bill_amount}},
        {'name': 'usd_amount', 'value': {'doubleValue': usd_amount}},
    ]

    # Execute the SQL statement
    response = execute_statement(sql_statement, sql_parameters)

    # Log the response from RDS Data API
    logger.info(f"SQL execution response: {response}")

# Function to execute a SQL statement using the RDS Data API
def execute_statement(sql, sql_parameters):
    try:
        # Call the RDS Data API with the given SQL and parameters
        return rds_client.execute_statement(
            secretArn=secrets_store_arn,
            database=database_name,
            resourceArn=db_cluster_arn,
            sql=sql,
            parameters=sql_parameters
        )
    except Exception as e:
        # Log any errors during the execution
        logger.error(f"ERROR: Could not connect to Aurora Serverless MySQL instance: {e}")
        return None

# Main Lambda handler function
def lambda_handler(event, context):
    # Log the received event for debugging
    logger.info(f"Received event: {json.dumps(event)}")

    try:
        # Extract the bucket name from the S3 event
        bucket_name = event['Records'][0]['s3']['bucket']['name']

        # Extract the file key (object name) from the S3 event
        s3_file = event['Records'][0]['s3']['object']['key']

        # Get the file object from S3
        response = s3_client.get_object(Bucket=bucket_name, Key=s3_file)

        # Read and decode the file content
        data = response['Body'].read().decode('utf-8')

        # Parse the CSV data
        csv_reader = csv.reader(io.StringIO(data))

        # Skip the header row
        next(csv_reader)

        # Process each record in the CSV file
        for record in csv_reader:
            process_record(record)

        # Log successful execution
        logger.info("Lambda execution finished successfully.")

    except Exception as e:
        # Log any unexpected errors during Lambda execution
        logger.error(f"ERROR: Unexpected error: {e}")
