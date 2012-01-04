#ifndef __XBEE_H__
#define __XBEE_H__

#define INIT_SEQUENCE "+++"
#define TIME_OUT
#define MIN_DELAY 1

/* Places XBee into Command Mode */
String initCommandMode();

/* Sends Message and Waits for Response */
String sendAndWait(String message);

/* Sends Message to XBee */  
String execCommand(String command);

#endif
