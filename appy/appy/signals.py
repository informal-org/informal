from allauth.account.signals import user_logged_in, user_signed_up, email_confirmed
from django.dispatch import receiver

from arevelcore.amplitude import AmplitudeLogger

amp = AmplitudeLogger()

@receiver(user_signed_up)
def log_signup(request, user):
    amp.log_event(amp.create_event(request, "signup account", {}, user=user))


@receiver(user_logged_in)
def log_login(request, user):
    amp.log_event(amp.create_event(request, "login account", {}, user=user))


@receiver(email_confirmed)
def log_login(request, user):
    amp.log_event(amp.create_event(request, "account email confirmed", {}, user=user))

