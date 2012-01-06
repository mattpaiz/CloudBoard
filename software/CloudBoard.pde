#include <SPI.h>
#include <Ethernet.h>
#include <string.h>

#define MIN_DELAY 1
#define TIME_OUT 2000
#define GUARD 500

#define MESH_SIZE 3

#define SENSOR_TEMP 0
#define SENSOR_LIGHT 1
#define SENSOR_MOTION 2

#define SENSOR_ID SENSOR_LIGHT

#define DEBUG_COMMAND "/~matt/debug.php"
#define SYNC_COMMAND "/~matt/index.php"

byte mac[] = {  0xDE, 0xAD, 0xBE, 0xEF, 0xFE, 0xED };
byte ip[] = { 192,168,1,13 };
byte sync_server[] = { 192,168,1,34 };
byte debug_server[] = { 192,168,1,34 };

String sensor_values[MESH_SIZE];

String my_address;
Client sync_client(sync_server, 80);
Client debug_client(debug_server, 80);

String initCommandMode() {
  delay(GUARD);
  return sendAndWait("+++");
}

String sendAndWait(String command) {
  String result = "";
  Serial.print(command);
  Serial.flush();
  int count = 0;
  while(!Serial.available()) {
    if(count++ > TIME_OUT) return "TIMEOUT";
    delay(1);
  }
  while(Serial.available()) { 
    result += ((char) Serial.read());
    delay(1);
  }
  return result;
}

String exec(String command) {
  return sendAndWait(command + "\r\n");
}

int post_message(Client client, String values[], int num, String location, byte host[]) {
  String content;
  
  for(int i = 0; i < num; i++) {
    if(i > 0) content += "&";
    content += "sensor" + String(i) + "=" + values[i];
  }
  
  char thehost[20];
  char thesize[10];
  char ch;
  
  sprintf(thehost, "%d.%d.%d.%d", host[0], host[1], host[2], host[3]);
  sprintf(thesize, "%d", content.length());
  
  String result = "";
  int count = 0;

  client.stop();
  if(client.connect()) {
    client.println("POST " + location + " HTTP/1.1");
    client.println("Host: " + String(thehost));
    client.println("Content-Length: " + String(thesize)); 
    client.println("Content-Type: application/x-www-form-urlencoded\n");
    client.println(content);
    client.println();
    client.flush();
  
    while(client.connected()) {
      
      if (client.available()) {
        ch = client.read();
      } else if(count++ > TIME_OUT) return -1;
     
      delay(MIN_DELAY);
    }
  } else {
    return 1;
  }
  

  return 0;
}

void clear_debug() {
    String blank[] = {""};
    debugln(blank, 1);
}


void syncln(String values[], int num) {
  post_message(sync_client, values, num, SYNC_COMMAND, sync_server);
}
void debugln(String values[], int num) {
  post_message(debug_client, values, num, DEBUG_COMMAND, debug_server);
}

void debug1ln(String value) {
  String values[] = {value};
  post_message(debug_client, values, 1, DEBUG_COMMAND, debug_server);
}

void debug_command(String command) {
  String values[] = {command, exec(command)};
  debugln(values, 2);
}


void setup() {
  Ethernet.begin(mac, ip);
  Serial.begin(9600);
  delay(1000);
  
  pinMode(2, OUTPUT);
  pinMode(9, OUTPUT);
  
  int has_connection = sync_client.connect();
  debug_client.connect();
  
  clear_debug();
  initCommandMode();
  debug_command("ATMY");
  debug_command("ATSH");

  if(has_connection) {
    debug_command("ATMY0000");
    my_address = "0";
    for(int i = 0; i < MESH_SIZE; i++) sensor_values[i] = "0";
  } else {
    debug_command("ATMYFFFF");
    debug_command("ATDH0000");
    debug_command("ATDL0000");
    my_address = exec("ATSH").trim() + "." + exec("ATSL").trim();
  }
  
  debug_command("ATWR");
  debug_command("ATCN");
}

void process_data(String data) {
  char buffer[10];
  String id = "";
  String value = "";
  char ch;
  int left = 1;

  for(int i = 0; i < data.length(); i++) {  
     ch = data.charAt(i);
     if(left) {
       if(ch != ':') id += ch;
       else left = 0;
     } else {
       if(ch != '\n')
       value += ch;
     }
  }
  id.toCharArray(buffer, 10);
  sensor_values[atoi(buffer)] = value;
}

void loop()
{
  
  String xbee_buffer = "";
  char ch;
  
  if(!my_address.equals("0")) {
    Serial.println(String(SENSOR_ID) + ":" + String(analogRead(A0)));
    Serial.flush();
  } else {
     syncln(sensor_values, MESH_SIZE);
  }
  
  while(Serial.available()) {
    if((ch = Serial.read()) != '\n') if(ch != '\r') xbee_buffer += ch;
    else {
      process_data(xbee_buffer);
      xbee_buffer = "";   
    }
  }
  
  delay(1000);
}


