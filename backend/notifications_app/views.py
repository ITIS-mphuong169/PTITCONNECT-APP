from rest_framework import permissions, status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.generics import get_object_or_404
from rest_framework.response import Response

from core.demo_auth import resolve_demo_user

from .models import Notification
from .serializers import NotificationSerializer
from .realtime import notify_user


@api_view(["GET", "POST"])
@permission_classes([permissions.AllowAny])
def notifications_api(request):
    me = resolve_demo_user(request)
    if request.method == "GET":
        qs = Notification.objects.filter(user=me)[:100]
        return Response(NotificationSerializer(qs, many=True).data)
    title = (request.data.get("title") or "").strip()
    content = (request.data.get("content") or "").strip()
    if not title or not content:
        return Response({"detail": "title and content required"}, status=status.HTTP_400_BAD_REQUEST)
    n = Notification.objects.create(
        user=me,
        title=title,
        content=content,
        notification_type=(request.data.get("notification_type") or "system").strip() or "system",
        target_username=(request.data.get("target_username") or "").strip(),
        conversation_id=request.data.get("conversation_id") or None,
        post_id=request.data.get("post_id") or None,
        group_id=request.data.get("group_id") or None,
    )
    return Response(NotificationSerializer(n).data, status=status.HTTP_201_CREATED)


@api_view(["POST"])
@permission_classes([permissions.AllowAny])
def notification_read_api(request, pk):
    me = resolve_demo_user(request)
    n = get_object_or_404(Notification, pk=pk, user=me)
    n.is_read = True
    n.save(update_fields=["is_read"])
    data = NotificationSerializer(n).data
    notify_user(me.username, {"type": "notification_read", "data": data})
    return Response(data)


@api_view(["POST"])
@permission_classes([permissions.AllowAny])
def notifications_read_all_api(request):
    me = resolve_demo_user(request)
    Notification.objects.filter(user=me, is_read=False).update(is_read=True)
    notify_user(me.username, {"type": "notification_read_all"})
    return Response({"ok": True})


@api_view(["DELETE"])
@permission_classes([permissions.AllowAny])
def notification_delete_api(request, pk):
    me = resolve_demo_user(request)
    n = get_object_or_404(Notification, pk=pk, user=me)
    nid = n.id
    n.delete()
    notify_user(me.username, {"type": "notification_deleted", "id": nid})
    return Response(status=status.HTTP_204_NO_CONTENT)
