import json
import boto3

def handler(event, context):
    for record in event['Records']:
        body = json.loads(record['body'])
        detail_type = body.get('detail-type')
        detail = body.get('detail', {})
        res_id = detail.get('reservationId')

        # Diferenciamos la lógica según el tipo de evento 
        if detail_type == "pdf.generated":
            subject = "✅ ¡Tu ticket está listo!"
            message = f"Hola, tu reserva {res_id} ha sido confirmada. Puedes descargar tu PDF."
        elif detail_type == "reservation.expired":
            subject = "⏱️ Tu reserva ha expirado"
            message = f"Lo sentimos, el tiempo para pagar la reserva {res_id} se agotó."
        else:
            subject = "Actualización de tu reserva"
            message = f"Tu reserva {res_id} ha cambiado de estado."

        # Simulación de envío de email (Aquí iría boto3.client('ses').send_email) [cite: 26]
        print(f"ENVIANDO EMAIL: {subject}")
        print(f"CONTENIDO: {message}")
        
    return {"status": "NOTIFICATIONS_PROCESSED"}