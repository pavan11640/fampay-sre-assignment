from rest_framework import pagination


class CursorPagination(pagination.CursorPagination):
    ordering = "-id"
