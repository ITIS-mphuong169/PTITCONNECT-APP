import json
from channels.generic.websocket import AsyncWebsocketConsumer


class ChatConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        self.conversation_id = self.scope['url_route']['kwargs']['conversation_id']
        self.group_name = f"chat_{self.conversation_id}"
        await self.channel_layer.group_add(self.group_name, self.channel_name)
        await self.accept()
        await self.send(text_data=json.dumps({"type": "connected", "scope": "chat", "conversation_id": self.conversation_id}))

    async def disconnect(self, close_code):
        await self.channel_layer.group_discard(self.group_name, self.channel_name)

    async def receive(self, text_data=None, bytes_data=None):
        try:
            data = json.loads(text_data or '{}')
        except Exception:
            data = {}
        if data.get('type') == 'typing':
            await self.channel_layer.group_send(self.group_name, {
                'type': 'push.event',
                'payload': {
                    'type': 'typing',
                    'conversation_id': self.conversation_id,
                    'username': data.get('username', ''),
                }
            })

    async def push_event(self, event):
        await self.send(text_data=json.dumps(event['payload']))
