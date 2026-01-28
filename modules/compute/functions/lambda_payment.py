import json
import os
import boto3

dynamodb = boto3.resource('dynamodb')
sfn = boto3.client('stepfunctions')
table = dynamodb.Table(os.environ['RESERVATIONS_TABLE'])

def handler(event, context):
    try:
        body = json.loads(event.get('body', '{}'))
        reservation_id = body.get('reservationId')
        
        if not reservation_id:
            return {"statusCode": 400, "body": json.dumps({"message": "Falta reservationId"})}

        print(f"Procesando pago para la reserva: {reservation_id}")

        # 1. BUSCAR EL TOKEN EN DYNAMODB (Recuperamos lo que guardó 'save_token.py')
        reserva = table.get_item(Key={'ReservationID': reservation_id})
        item = reserva.get('Item')

        if not item:
            return {"statusCode": 404, "body": json.dumps({"message": "Reserva no encontrada"})}
        
        # Obtenemos el token guardado internamente
        task_token = item.get('taskToken')

        # 2. ACTUALIZAR ESTADO A CONFIRMED
        table.update_item(
            Key={'ReservationID': reservation_id},
            UpdateExpression="SET #s = :val",
            ExpressionAttributeNames={'#s': 'status'},
            ExpressionAttributeValues={':val': 'CONFIRMED'}
        )

        # 3. DESPERTAR STEP FUNCTION AUTOMÁTICAMENTE
        if task_token:
            print(f"Enviando señal de éxito a Step Functions para {reservation_id}")
            try:
                sfn.send_task_success(
                    taskToken=task_token,
                    output=json.dumps({"status": "CONFIRMED", "reservationId": reservation_id})
                )
            except sfn.exceptions.TaskDoesNotExist:
                # Esto pasa si el usuario pagó después de los 30 segundos (el token ya expiró)
                print("Error: El token ya no es válido (posible expiración de 30s)")
                return {"statusCode": 408, "body": json.dumps({"message": "El tiempo de pago expiró"})}
        else:
            print("Aviso: No se encontró taskToken en la base de datos.")

        return {
            "statusCode": 200,
            "body": json.dumps({
                "message": "Pago procesado y flujo de orquestación liberado",
                "reservationId": reservation_id
            })
        }
    except Exception as e:
        print(f"Error: {str(e)}")
        return {"statusCode": 500, "body": json.dumps({"error": str(e)})}