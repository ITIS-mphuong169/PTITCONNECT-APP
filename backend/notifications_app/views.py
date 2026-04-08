from rest_framework import permissions, status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.generics import get_object_or_404
from rest_framework.response import Response

from core.demo_auth import resolve_demo_user

from .models import Notification
from .serializers import NotificationSerializer


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
    n = Notification.objects.create(user=me, title=title, content=content)
    return Response(NotificationSerializer(n).data, status=status.HTTP_201_CREATED)


@api_view(["POST"])
@permission_classes([permissions.AllowAny])
def notification_read_api(request, pk):
    me = resolve_demo_user(request)
    n = get_object_or_404(Notification, pk=pk, user=me)
    n.is_read = True
    n.save()
    return Response(NotificationSerializer(n).data)


@api_view(["POST"])
@permission_classes([permissions.AllowAny])
def notifications_read_all_api(request):
    me = resolve_demo_user(request)
    Notification.objects.filter(user=me, is_read=False).update(is_read=True)
    return Response({"ok": True})
