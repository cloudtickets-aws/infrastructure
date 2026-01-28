import json
import os
import boto3
from fpdf import FPDF  # Esto ahora funciona gracias a la Layer

s3 = boto3.client('s3')
events = boto3.client('events')

def handler(event, context):
    for record in event['Records']:
        try:
            body = json.loads(record['body'])
            detail = body.get('detail', {})
            res_id = detail.get('reservationId', 'Desconocido')
            
            file_name = f"ticket-{res_id}.pdf"
            local_path = f"/tmp/{file_name}"

            # 1. Generación de PDF Real usando fpdf2
            pdf = FPDF()
            pdf.add_page()
            pdf.set_font("Arial", 'B', 16)
            pdf.cell(40, 10, f"Ticket de Reserva: {res_id}")
            pdf.ln(10)
            pdf.set_font("Arial", size=12)
            pdf.cell(40, 10, "Estado: CONFIRMADO")
            
            # Guardar el PDF binario en la carpeta temporal de Lambda
            pdf.output(local_path)
            
            # 2. Subir a S3 como binario real
            with open(local_path, "rb") as f:
                s3.put_object(
                    Bucket=os.environ['TICKETS_BUCKET'],
                    Key=file_name,
                    Body=f,
                    ContentType='application/pdf'
                )
            
            # 3. PUBLICAR EVENTO
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
            print(f"PDF REAL generado y subido para: {res_id}")

        except Exception as e:
            print(f"Error procesando PDF: {str(e)}")
            raise e
            
    return {"status": "SUCCESS"}