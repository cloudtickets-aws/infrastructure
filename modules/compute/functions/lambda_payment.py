import json
import os
import boto3
import time # Importamos time para las pausas

dynamodb = boto3.resource('dynamodb')
sfn = boto3.client('stepfunctions')
table = dynamodb.Table(os.environ['RESERVATIONS_TABLE'])

def handler(event, context):
    try:
        body = json.loads(event.get('body', '{}'))
        reservation_id = body.get('reservationId')
        
        if not reservation_id:
            return {
                "statusCode": 400, 
                "headers": {"Access-Control-Allow-Origin": "*"},
                "body": json.dumps({"message": "Falta reservationId"})
            }

        print(f"Procesando pago para la reserva: {reservation_id}")

        # -----------------------------------------------------------
        # 1. BUSCAR EL TOKEN EN DYNAMODB CON REINTENTOS
        # -----------------------------------------------------------
        task_token = None
        # Reintentaremos 5 veces, con 1 segundo de espera entre cada una
        for intento in range(5):
            reserva = table.get_item(Key={'ReservationID': reservation_id})
            item = reserva.get('Item')
            
            if item:
                task_token = item.get('taskToken')
                if task_token:
                    print(f"Token encontrado en el intento {intento + 1}")
                    break
            
            print(f"Intento {intento + 1}: Token no encontrado aún, esperando 1 segundo...")
            time.sleep(1)

        if not item:
            return {
                "statusCode": 404, 
                "headers": {"Access-Control-Allow-Origin": "*"},
                "body": json.dumps({"message": "Reserva no encontrada"})
            }
        
        # -----------------------------------------------------------
        # 2. ACTUALIZAR ESTADO A CONFIRMED
        # -----------------------------------------------------------
        table.update_item(
            Key={'ReservationID': reservation_id},
            UpdateExpression="SET #s = :val",
            ExpressionAttributeNames={'#s': 'status'},
            ExpressionAttributeValues={':val': 'CONFIRMED'}
        )

        # -----------------------------------------------------------
        # 3. DESPERTAR STEP FUNCTION AUTOMÁTICAMENTE
        # -----------------------------------------------------------
        if task_token:
            print(f"Enviando señal de éxito a Step Functions para {reservation_id}")
            try:
                sfn.send_task_success(
                    taskToken=task_token,
                    output=json.dumps({"status": "CONFIRMED", "reservationId": reservation_id})
                )
            except sfn.exceptions.TaskDoesNotExist:
                print("Error: El token ya no es válido (posible expiración de 30s)")
                return {
                    "statusCode": 408, 
                    "headers": {"Access-Control-Allow-Origin": "*"},
                    "body": json.dumps({"message": "El tiempo de pago expiró en la orquestación"})
                }
        else:
            print("Aviso: No se encontró taskToken tras todos los reintentos.")

        return {
            "statusCode": 200,
            "headers": {
                "Access-Control-Allow-Origin": "*",
                "Content-Type": "application/json"
            },
            "body": json.dumps({
                "message": "Pago procesado y flujo de orquestación liberado",
                "reservationId": reservation_id
            })
        }
    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            "statusCode": 500, 
            "headers": {"Access-Control-Allow-Origin": "*"},
            "body": json.dumps({"error": str(e)})
        }