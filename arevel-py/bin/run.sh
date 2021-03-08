#!/bin/bash
export ENVIRONMENT=DEV
source .aaenv/bin/activate
python appy/manage.py runserver