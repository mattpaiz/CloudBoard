
#include <SPI.h>
#include <Ethernet.h>

#define ERROR_STATE 0
#define CONNECTED_STATE 1

#define FORWARD_LOCAL 0
#define FORWARD_REMOTE 1

byte mac[] = {  0xDE, 0xAD, 0xBE, 0xEF, 0xFE, 0xED };
byte ip[] = { 192,168,2,177 };
byte server[] = { 192,168,2,34 }; //Debugging Server (LAN)

int guard = 1000;
int debug_on = 0;

int connection_state = 0;
int server_address = 0;

String my_address;
Client debugServer(server, 3674);

void debugln(String message) {
  debug(message + "\r\n");
}
void debug(String message) {
  if(debug_on) debugServer.print(message);
}

String startCommandMode() {
  if(debug_on) debug("INIT: ");
  delay(guard);
  return messageAndResponse("+++");
}
String messageAndResponse(String command) {
  String result = "";
  Serial.print(command);
  Serial.flush();
  int count = 0;
  while(!Serial.available()) {
    if(count++ > 2000) return "TIMEOUT";
    delay(1);
  }
  while(Serial.available()) { 
    result += ((char) Serial.read());
    delay(1);
  }
  return result;
}

String runCommand(String command) {
  if(debug_on) debug(command + ": ");
  command += "\r\n";
  String result = messageAndResponse(command);
  delay(10);
  return result;
}

String sendToServer(String command) {
  
}

void setup() {
  // start the Ethernet connection:
  Ethernet.begin(mac, ip);
  // start the serial library:
  Serial.begin(9600);
  delay(1000);
  pinMode(2, OUTPUT);
  pinMode(9, OUTPUT);
  // give the Ethernet shield a second to initialize:
  debug_on = debugServer.connect();

  debugln(startCommandMode());
  guard = 500;
  debugln(runCommand("ATMY"));
  debugln(runCommand("ATID1010"));

  //if (debug_on) {
  if(1) {
    debugln(runCommand("ATMY0000"));
    debugln(runCommand("ATDH13A200"));
    debugln(runCommand("ATDL40647B63"));
    my_address = "0000";
  } else {
    debugln(runCommand("ATMYFFFF"));
    debugln(runCommand("ATDH0000"));
    debugln(runCommand("ATDL0000"));
    my_address = runCommand("ATSH").trim() + "." + runCommand("ATSL").trim();
  }
  
  debugln(runCommand("ATWR"));
  debugln(runCommand("ATCN"));
  
  connection_state = CONNECTED_STATE;
}

int loopCount = 0;

String getUntil(String message, char terminator, int *index) {
  String result = "";
  
  char ch;
  
  for(; *index < message.length(); (*index)++) {
    ch = message.charAt(*index);
    if(ch == terminator) break;
    result += ch;
  }
  
  (*index)++;
  
  return result;
}

void process_sync(String message) {
  
  int index = 0;
  String port = getUntil(message, ' ', &index);
  String value = getUntil(message, '\n', &index);
  
  char buffer[10];
  port.toCharArray(buffer, 10);
  if(value.equals("low"))
    digitalWrite(atoi(buffer), LOW);
  else
    digitalWrite(atoi(buffer), HIGH);
}

void process(String message, int forward) {
  
  int index = 0;
  String address = getUntil(message, '(', &index);
  String type = getUntil(message, ')', &index);
  getUntil(message,' ', &index);
  String value = getUntil(message, '\n', &index);
  
  if(!address.equals("0000") & address.length() < 12) return;
  String high, low;
  
  if(address.equals(my_address)) {  
      process_sync(value);
  } else { 
    switch(forward) {
      case FORWARD_LOCAL:
        
        index = 0;
        high = getUntil(address, '.', &index);
        Serial.println(address + "," + type + "," + value);
        break;
      case FORWARD_REMOTE:
        if(value.length() > 3) digitalWrite(9, HIGH);
        else digitalWrite(9, LOW);
        
        debugln(address + "," + type + "," + value);
        break;
    }
  }
}

void checkRemote() {
  String message;
  char c;
  
  while(debugServer.available() > 0) {
    if((c = debugServer.read()) != '\n')
      message += c;
    else {
      process(message, FORWARD_LOCAL);
      message = "";
    }
  }
}

void checkLocal() {
  String message = "";
  char c;
  while(Serial.available() > 0) {
    if((c = Serial.read()) != '\n') 
      message += c;
    else {
      process(message, FORWARD_REMOTE);
      message = "";
    } 
  }
}

void loop()
{
  switch(connection_state) {
    case CONNECTED_STATE:
      digitalWrite(2, HIGH);
      if(!my_address.equals("0000")) Serial.println(my_address + "(SYNC): " + String(analogRead(A0)));
      else checkRemote();
      checkLocal();
      break;
    case ERROR_STATE:
      debugServer.stop();
      if(loopCount % 2)
        digitalWrite(2, HIGH);
      else
        digitalWrite(2, LOW);
      break;
  }
  loopCount++;
  delay(500);
}

