"""
ASGI config for core project.

It exposes the ASGI callable as a module-level variable named ``application``.

For more information on this file, see
https://docs.djangoproject.com/en/5.1/howto/deployment/asgi/
"""

import os

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "core.settings")

from channels.routing import ProtocolTypeRouter, URLRouter
from django.core.asgi import get_asgi_application
from django.urls import path
from chat_app.consumers import ChatConsumer
from notifications_app.consumers import NotificationConsumer, PresenceConsumer

django_asgi_app = get_asgi_application()

application = ProtocolTypeRouter({
    "http": django_asgi_app,
    "websocket": URLRouter([
        path("ws/chat/<int:conversation_id>/", ChatConsumer.as_asgi()),
        path("ws/notifications/<str:username>/", NotificationConsumer.as_asgi()),
        path("ws/presence/<str:username>/", PresenceConsumer.as_asgi()),
    ]),
})
