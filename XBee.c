String initCommandMode() {
  delay(guard);
  return sendAndWait(INIT_SEQUENCE);
}

String sendAndWait(String message) {
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

String execCommand(String command) {
  command += "\r\n";
  String result = sendAndWait(command);
  delay(10);
  return result;
}
