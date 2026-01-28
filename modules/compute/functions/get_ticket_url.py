import boto3
import os
import json
from botocore.exceptions import ClientError

s3_client = boto3.client('s3')
BUCKET_NAME = os.environ['TICKETS_BUCKET']

def handler(event, context):
    # Extraer el reservationId de la query string (?reservationId=xxx)
    params = event.get('queryStringParameters', {})
    reservation_id = params.get('reservationId')
    
    if not reservation_id:
        return {
            'statusCode': 400,
            'headers': {'Access-Control-Allow-Origin': '*'},
            'body': json.dumps({'error': 'Falta reservationId'})
        }

    # El path del archivo en S3 debe coincidir con lo que genera tu pdf_generator.py
    # Si pdf_generator los guarda en la raíz, quita "tickets/"
    object_key = f"{reservation_id}.pdf" 

    try:
        # Generar URL firmada válida por 1 hora
        url = s3_client.generate_presigned_url(
            'get_object',
            Params={
                'Bucket': BUCKET_NAME,
                'Key': object_key,
                'ResponseContentDisposition': f'attachment; filename="ticket-{reservation_id}.pdf"'
            },
            ExpiresIn=3600 
        )
        
        return {
            'statusCode': 200,
            'headers': {
                'Access-Control-Allow-Origin': '*',
                'Content-Type': 'application/json'
            },
            'body': json.dumps({'downloadUrl': url})
        }

    except Exception as e:
        return {
            'statusCode': 500,
            'headers': {'Access-Control-Allow-Origin': '*'},
            'body': json.dumps({'error': str(e)})
        }