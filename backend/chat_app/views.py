from django.db.models import Max, Q
from django.contrib.auth.models import User
from rest_framework import permissions, status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.generics import get_object_or_404
from rest_framework.response import Response

from core.demo_auth import resolve_demo_user
from notifications_app.services import create_notification
from notifications_app.realtime import notify_conversation, notify_user
from users.models import FriendRequest

from .models import Conversation, Message
from .serializers import ConversationSerializer, MessageSerializer


def _are_friends(user_a, user_b):
    return FriendRequest.objects.filter(status="accepted").filter(
        Q(from_user=user_a, to_user=user_b) | Q(from_user=user_b, to_user=user_a)
    ).exists()


def _get_or_create_conversation(user_a, user_b):
    if user_a.id == user_b.id:
        return None
    conv = Conversation.objects.filter(Q(user1=user_a, user2=user_b) | Q(user1=user_b, user2=user_a)).first()
    if conv:
        return conv
    return Conversation.objects.create(user1=user_a, user2=user_b)


@api_view(["GET"])
@permission_classes([permissions.AllowAny])
def conversations_api(request):
    me = resolve_demo_user(request)
    q = (request.query_params.get("q") or "").strip()
    qs = Conversation.objects.filter(Q(user1=me) | Q(user2=me)).annotate(latest=Max("messages__created_at")).order_by("-latest", "-updated_at")
    if q:
        qs = qs.filter(
            Q(user1__profile__full_name__icontains=q)
            | Q(user2__profile__full_name__icontains=q)
            | Q(user1__profile__student_id__icontains=q)
            | Q(user2__profile__student_id__icontains=q)
            | Q(user1__username__icontains=q)
            | Q(user2__username__icontains=q)
            | Q(messages__content__icontains=q)
        ).distinct()
    return Response(
        ConversationSerializer(
            qs[:100],
            many=True,
            context={"request": request, "user": me, "search_query": q},
        ).data
    )


@api_view(["POST"])
@permission_classes([permissions.AllowAny])
def conversation_open_api(request):
    me = resolve_demo_user(request)
    peer_username = (request.data.get("peer_username") or request.data.get("target_username") or "").strip().lower()
    if not peer_username:
        return Response({"detail": "peer_username required"}, status=status.HTTP_400_BAD_REQUEST)
    peer = User.objects.filter(username=peer_username).first()
    if peer is None:
        return Response({"detail": "user not found"}, status=status.HTTP_404_NOT_FOUND)
    if not _are_friends(me, peer):
        return Response({"detail": "only friends can chat"}, status=status.HTTP_400_BAD_REQUEST)
    conv = _get_or_create_conversation(me, peer)
    if not conv:
        return Response({"detail": "invalid peer"}, status=status.HTTP_400_BAD_REQUEST)
    return Response(ConversationSerializer(conv, context={"request": request, "user": me}).data, status=status.HTTP_201_CREATED)


@api_view(["GET", "POST"])
@permission_classes([permissions.AllowAny])
def messages_api(request, pk):
    me = resolve_demo_user(request)
    conv = get_object_or_404(Conversation, pk=pk)
    if conv.user1_id != me.id and conv.user2_id != me.id:
        return Response({"detail": "forbidden"}, status=status.HTTP_403_FORBIDDEN)

    if request.method == "GET":
        conv.messages.exclude(sender=me).filter(is_read=False).update(is_read=True)
        q = (request.query_params.get("q") or "").strip()
        msgs = conv.messages.all()
        if q:
            msgs = msgs.filter(content__icontains=q)
        return Response(MessageSerializer(msgs, many=True).data)

    peer = conv.user2 if conv.user1_id == me.id else conv.user1
    if not _are_friends(me, peer):
        return Response({"detail": "only friends can chat"}, status=status.HTTP_400_BAD_REQUEST)
    content = (request.data.get("content") or "").strip()
    if not content:
        return Response({"detail": "content required"}, status=status.HTTP_400_BAD_REQUEST)
    msg = Message.objects.create(conversation=conv, sender=me, content=content)
    conv.save(update_fields=["updated_at"])
    payload = MessageSerializer(msg).data
    notify_conversation(conv.id, {"type": "message", "data": payload})
    notify_user(me.username, {"type": "conversation_refresh", "conversation_id": conv.id})
    notify_user(peer.username, {"type": "conversation_refresh", "conversation_id": conv.id})
    create_notification(
        user=peer,
        title="Tin nhắn mới",
        content=f"{me.username}: {content[:80]}",
        notification_type="message",
        target_username=me.username,
        conversation_id=conv.id,
    )
    return Response(MessageSerializer(msg).data, status=status.HTTP_201_CREATED)


@api_view(["DELETE"])
@permission_classes([permissions.AllowAny])
def conversation_delete_api(request, pk):
    me = resolve_demo_user(request)
    conv = get_object_or_404(Conversation, pk=pk)
    if conv.user1_id != me.id and conv.user2_id != me.id:
        return Response({"detail": "forbidden"}, status=status.HTTP_403_FORBIDDEN)
    conv.delete()
    return Response(status=status.HTTP_204_NO_CONTENT)
