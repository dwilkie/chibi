# ChatBox

## Configuring Nuntium with Android

Under channels, add an AO Rule with the following Regexp:
Condition: To regexp

    sms://855(\d+)

Action: To =

    sms://0${to.1}

