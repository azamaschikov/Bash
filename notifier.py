#!/usr/bin/env python

import os
import sys
import requests

def send_message(text):
    bot_id = 'your_bot_id'
    chat_id = 'your_chat_id'

    response = requests.post('https://api.telegram.org/bot' + bot_id + '/sendMessage', data={'chat_id':chat_id, 'text':text})
    response = response.json()

if sys.argv[1] == '--cpu':
    send_message('CPU is exceeded')

if sys.argv[1] == '--memory':
    send_message('RAM is exceeded')

if sys.argv[1] == '--io-disk':
    send_message('IO-disks is exceeded')
