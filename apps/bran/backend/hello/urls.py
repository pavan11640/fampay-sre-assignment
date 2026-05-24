from django.urls import re_path

from hello.views import UserList

app_name = "hello"

urlpatterns = [
    re_path(r".*", UserList.as_view(), name="get-users"),
]
