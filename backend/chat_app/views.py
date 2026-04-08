from django.db.models import Q
from django.contrib.auth.models import User
from rest_framework import permissions, status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.generics import get_object_or_404
from rest_framework.response import Response

from core.demo_auth import resolve_demo_user

from .models import Conversation, Message
from .serializers import ConversationSerializer, MessageSerializer


def _get_or_create_conversation(user_a, user_b):
    if user_a.id == user_b.id:
        return None
    conv = (
        Conversation.objects.filter(
            Q(user1=user_a, user2=user_b) | Q(user1=user_b, user2=user_a)
        )
        .first()
    )
    if conv:
        return conv
    return Conversation.objects.create(user1=user_a, user2=user_b)


@api_view(["GET"])
@permission_classes([permissions.AllowAny])
def conversations_api(request):
    me = resolve_demo_user(request)
    qs = Conversation.objects.filter(Q(user1=me) | Q(user2=me)).order_by("-created_at")
    return Response(
        ConversationSerializer(qs[:100], many=True, context={"request": request, "user": me}).data
    )


@api_view(["POST"])
@permission_classes([permissions.AllowAny])
def conversation_open_api(request):
    me = resolve_demo_user(request)
    peer_username = (request.data.get("peer_username") or "").strip()
    if not peer_username:
        return Response({"detail": "peer_username required"}, status=status.HTTP_400_BAD_REQUEST)
    peer = User.objects.filter(username=peer_username).first()
    if peer is None:
        return Response({"detail": "user not found"}, status=status.HTTP_404_NOT_FOUND)
    conv = _get_or_create_conversation(me, peer)
    if not conv:
        return Response({"detail": "invalid peer"}, status=status.HTTP_400_BAD_REQUEST)
    return Response(
        ConversationSerializer(conv, context={"request": request, "user": me}).data,
        status=status.HTTP_201_CREATED,
    )


@api_view(["GET", "POST"])
@permission_classes([permissions.AllowAny])
def messages_api(request, pk):
    me = resolve_demo_user(request)
    conv = get_object_or_404(Conversation, pk=pk)
    if conv.user1_id != me.id and conv.user2_id != me.id:
        return Response({"detail": "forbidden"}, status=status.HTTP_403_FORBIDDEN)

    if request.method == "GET":
        msgs = conv.messages.all()
        return Response(MessageSerializer(msgs, many=True).data)

    content = (request.data.get("content") or "").strip()
    if not content:
        return Response({"detail": "content required"}, status=status.HTTP_400_BAD_REQUEST)
    msg = Message.objects.create(conversation=conv, sender=me, content=content)
    return Response(MessageSerializer(msg).data, status=status.HTTP_201_CREATED)
