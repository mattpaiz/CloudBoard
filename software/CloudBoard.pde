#include <SPI.h>
#include <Ethernet.h>
#include <string.h>

#define NUM_LOCATIONS 5
#define LOCATION_ELEVATOR   "a00U0000002GfN0IAK"
#define LOCATION_KITCHEN    "a00U0000002Gf9CIAS"
#define LOCATION_CONFERENCE "a00U0000002GfRBIA0"
#define LOCATION_CUBES      "a00U0000002GfR6IAK"
#define LOCATION_LOBBY      "a00U0000001gvbVIAQ"

#define USE_HEROKU

String all_locations[] = {LOCATION_ELEVATOR, LOCATION_KITCHEN, LOCATION_CONFERENCE, LOCATION_CUBES, LOCATION_LOBBY};

#define MIN_DELAY 1
#define REFRESH_DELAY 750
#define TIME_OUT 2000
#define GUARD 500
#define INIT_SEQUENCE "+++"

#define MESH_SIZE 3

#define SENSOR_TEMP 0
#define SENSOR_LIGHT 1
#define SENSOR_MOTION 2
#define SENSOR_ID SENSOR_LIGHT

String all_labels[] = {"location", "T", "L", "M"};

#define LED_PORT 2
#define DIGITAL_IN 5
#define DIGITAL_OUT 9

#define SERVER_ADDRESS "0"
#define DEBUG_COMMAND "/~matt/debug.php"

#ifdef USE_HEROKU
  #define SYNC_COMMAND "/sensor"
  byte sync_server[] = { 50,17,208,142 };
#else
  #define SYNC_COMMAND "/~matt/index.php"
  byte sync_server[] = { 192,168,1,34 };
#endif


byte mac[] = {  0xDE, 0xAD, 0xBE, 0xEF, 0xFE, 0xED };
byte ip[] = { 192,168,1,13 };


byte debug_server[] = { 192,168,1,34 };

unsigned int count = 0;

String sensor_values[MESH_SIZE + 1];

String my_address;
Client sync_client(sync_server, 80);
Client debug_client(debug_server, 80);

String initCommandMode() {
  delay(GUARD);
  return sendAndWait(INIT_SEQUENCE);
}

String sendAndWait(String command) {
  String result = "";
  Serial.print(command);
  Serial.flush();
  int count = 0;
  while(!Serial.available()) {
    if(count++ > TIME_OUT) return "TIMEOUT";
    delay(MIN_DELAY);
  }
  while(Serial.available()) { 
    result += ((char) Serial.read());
    delay(MIN_DELAY);
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
    content += all_labels[i] + "=" + values[i];
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
#ifdef USE_HEROKU
    client.println("Host: cloudboard.herokuapp.com");
#else
    client.println("Host: " + String(thehost));
#endif  
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
  
  pinMode(LED_PORT, OUTPUT);
  pinMode(DIGITAL_OUT, OUTPUT);
  pinMode(DIGITAL_IN, INPUT);
  
  int has_connection = sync_client.connect();
  debug_client.connect();
  
  clear_debug();
  initCommandMode();
  debug_command("ATMY");
  debug_command("ATSH");

  if(has_connection) {
    debug_command("ATMY0000");
    my_address = SERVER_ADDRESS;
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
  int index = atoi(buffer);
  sensor_values[index+ 1] = value;
  
  if(index == SENSOR_MOTION) {
    if(value.equals("1"))
      digitalWrite(DIGITAL_OUT, HIGH);
    else
      digitalWrite(DIGITAL_OUT, LOW);
  }
}

void loop()
{
  
  String xbee_buffer = "";
  char ch;
  
  if(!my_address.equals(SERVER_ADDRESS)) { 
    switch(count % MESH_SIZE) {
      case SENSOR_LIGHT:
        Serial.println(String(SENSOR_LIGHT) + ":" + String(analogRead(A0)));
        break;
      case SENSOR_MOTION:
        Serial.println(String(SENSOR_MOTION) + ":" + String(digitalRead(DIGITAL_IN)));
        break;
      case SENSOR_TEMP:
        Serial.println(String(SENSOR_TEMP) + ":" + String(analogRead(A1)));
        break;     
    }
    Serial.flush();
  } else {
     sensor_values[0] = all_locations[count %  NUM_LOCATIONS];
     syncln(sensor_values, MESH_SIZE + 1);
  }
  
  while(Serial.available()) {
    if((ch = Serial.read()) != '\n') if(ch != '\r') xbee_buffer += ch;
    else {
      process_data(xbee_buffer);
      xbee_buffer = "";   
    }
  }
  
  if(count++ % 2)
    digitalWrite(LED_PORT, HIGH);
  else
    digitalWrite(LED_PORT, LOW);
    
  delay(REFRESH_DELAY);
}
