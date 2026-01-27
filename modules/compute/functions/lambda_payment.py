import json
import os
import boto3

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['RESERVATIONS_TABLE'])

def handler(event, context):
    try:
        # En una API HTTP, el cuerpo suele venir como string en 'body'
        body = json.loads(event.get('body', '{}'))
        reservation_id = body.get('reservationId')
        
        if not reservation_id:
            return {"statusCode": 400, "body": json.dumps({"message": "Falta reservationId"})}

        print(f"Procesando pago para la reserva: {reservation_id}")

        # Simulamos que el pago fue exitoso actualizando el status
        table.update_item(
            Key={'ReservationID': reservation_id},
            UpdateExpression="SET #s = :val",
            ExpressionAttributeNames={'#s': 'status'},
            ExpressionAttributeValues={':val': 'CONFIRMED'}
        )

        return {
            "statusCode": 200,
            "body": json.dumps({
                "message": "Pago procesado exitosamente",
                "reservationId": reservation_id,
                "status": "CONFIRMED"
            })
        }
    except Exception as e:
        print(f"Error: {str(e)}")
        return {"statusCode": 500, "body": json.dumps({"error": str(e)})}