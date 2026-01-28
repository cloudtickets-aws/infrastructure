import json
import os
import boto3

s3 = boto3.client('s3')
events = boto3.client('events')

def handler(event, context):
    for record in event['Records']:
        body = json.loads(record['body'])
        # Extraemos el detail del evento de EventBridge que viene dentro de SQS
        detail = body.get('detail', {})
        res_id = detail.get('reservationId')
        
        # 1. Generación de contenido (Simulada)
        pdf_content = f"TICKET OFICIAL - Reserva: {res_id}\nEstado: CONFIRMADO"
        file_name = f"ticket-{res_id}.pdf"
        
        # 2. Subir a S3 con el MIME Type correcto para PDF [cite: 21]
        s3.put_object(
            Bucket=os.environ['TICKETS_BUCKET'],
            Key=file_name,
            Body=pdf_content,
            ContentType='application/pdf' 
        )
        
        # 3. PUBLICAR EVENTO: Notificar que el PDF existe [cite: 22]
        events.put_events(
            Entries=[{
                'Source': 'com.cloudtickets.pdfgenerator',
                'DetailType': 'pdf.generated',
                'Detail': json.dumps({
                    "reservationId": res_id,
                    "pdfKey": file_name,
                    "status": "READY"
                }),
                'EventBusName': os.environ['EVENT_BUS_NAME']
            }]
        )
        
        print(f"PDF generado y evento publicado para: {res_id}")
        
    return {"status": "SUCCESS"}