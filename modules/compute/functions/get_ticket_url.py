import boto3
import os
import json
from botocore.exceptions import ClientError

s3_client = boto3.client('s3')
# Asegúrate de que esta variable de entorno sea: cloudticket-tickets-dev
BUCKET_NAME = os.environ.get('TICKETS_BUCKET', 'cloudticket-tickets-dev')

def handler(event, context):
    # 1. Extraer el nombre completo del archivo enviado desde el frontend
    # El frontend envía algo como: ticket-res-0129-001626.pdf
    params = event.get('queryStringParameters', {})
    file_key = params.get('reservationId')
    
    if not file_key:
        return {
            'statusCode': 400,
            'headers': {
                'Access-Control-Allow-Origin': '*',
                'Content-Type': 'application/json'
            },
            'body': json.dumps({'error': 'Falta el nombre del archivo (reservationId)'})
        }

    # Como el frontend ya construye el nombre "ticket-res-XXXX.pdf",
    # lo usamos directamente como la llave (Key) de S3 sin añadirle nada.
    object_key = file_key 

    try:
        # 2. Generar URL firmada válida por 1 hora
        # Usamos ResponseContentDisposition para que al descargar el archivo
        # el navegador lo reconozca como un PDF con el nombre correcto.
        url = s3_client.generate_presigned_url(
            'get_object',
            Params={
                'Bucket': BUCKET_NAME,
                'Key': object_key,
                'ResponseContentDisposition': f'attachment; filename="{object_key}"'
            },
            ExpiresIn=3600 
        )
        
        return {
            'statusCode': 200,
            'headers': {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type',
                'Access-Control-Allow-Methods': 'OPTIONS,GET',
                'Content-Type': 'application/json'
            },
            'body': json.dumps({'downloadUrl': url})
        }

    except ClientError as e:
        print(f"Error de S3: {e}")
        return {
            'statusCode': 404,
            'headers': {'Access-Control-Allow-Origin': '*'},
            'body': json.dumps({'error': 'El ticket no fue encontrado en el servidor'})
        }
    except Exception as e:
        print(f"Error inesperado: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {'Access-Control-Allow-Origin': '*'},
            'body': json.dumps({'error': 'Error interno al generar el enlace de descarga'})
        }