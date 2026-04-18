import json
from channels.generic.websocket import AsyncWebsocketConsumer

class CoreConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        self.username = self.scope['url_route']['kwargs']['username']

        self.user_group = f"user_{self.username}"

        await self.channel_layer.group_add(
            self.user_group,
            self.channel_name
        )

        await self.accept()

        # presence online
        await self.channel_layer.group_send(
            self.user_group,
            {
                "type": "send_event",
                "payload": {
                    "type": "presence",
                    "status": "online"
                }
            }
        )

    async def disconnect(self, close_code):
        await self.channel_layer.group_discard(
            self.user_group,
            self.channel_name
        )

    async def receive(self, text_data):
        data = json.loads(text_data)
        event_type = data.get("type")

        # ================= CHAT =================
        if event_type == "message":
            to_user = data.get("to")

            await self.channel_layer.group_send(
                f"user_{to_user}",
                {
                    "type": "send_event",
                    "payload": data
                }
            )

        # ================= CALL SIGNAL =================
        elif event_type == "call_signal":
            to_user = data.get("to")

            await self.channel_layer.group_send(
                f"user_{to_user}",
                {
                    "type": "send_event",
                    "payload": data
                }
            )

        # ================= TYPING =================
        elif event_type == "typing":
            to_user = data.get("to")

            await self.channel_layer.group_send(
                f"user_{to_user}",
                {
                    "type": "send_event",
                    "payload": data
                }
            )

    async def send_event(self, event):
        await self.send(text_data=json.dumps(event["payload"]))