from django.http import HttpRequest, HttpResponse
from django.shortcuts import render


def index(request: HttpRequest) -> HttpResponse:
    return render(request, "hello/index.html")


def health_check(request: HttpRequest) -> HttpResponse:
    return HttpResponse("OK")
