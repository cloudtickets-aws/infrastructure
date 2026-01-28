import json
import os
import boto3

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['RESERVATIONS_TABLE'])

def handler(event, context):
    reservation_id = event.get('reservationId')
    task_token = event.get('taskToken')
    
    print(f"Guardando Token para reserva: {reservation_id}")

    try:
        table.update_item(
            Key={'ReservationID': reservation_id},
            UpdateExpression="SET taskToken = :t",
            ExpressionAttributeValues={':t': task_token}
        )
        return {
            "status": "TOKEN_SAVED",
            "reservationId": reservation_id
        }
    except Exception as e:
        print(f"Error: {str(e)}")
        raise e