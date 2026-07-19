import 'dart:async';

bool isPowerAlertShownBefore = false;

bool isPowerTrailingBtnShownBefore = false;

Timer? relay1Timer;
Timer? relay2Timer;
int relay1TimerDuration = 10;
int relay2TimerDuration = 10;

//String formattedConnectionTime = "";
DateTime connectionTime = DateTime.now();
