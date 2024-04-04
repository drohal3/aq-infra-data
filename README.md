# Infrastructure for air quality data ingestion, storing and serving

## Preconditions
Logged in AWS CLI

## Useful commands
```bash
terraform fmt
```
```bash
terraform init
```
```bash
terraform plan
```
```bash
terraform apply
```
```bash
terraform destroy
```

## Example data
...to be published to aq/measurement topic.
```JSON
{
  "time": "2024-01-30 10:00:05",
  "device": "test_1",
  "humidity": 25.8,
  "temperature": 21.5
}
```