/***************************************************************
 * This code allows one to toggle and strobe  TTL logic driven 
 * illumination sources using anArduino microcontroller 
 * (up to a maximum of 9) in any order.
 ****************************************************************/

/***************************************************************
 * Select the strobe TTL logic used by your illumination source. 
 * Here, the macro LED_ON corresponds to the TTL signal level used 
 * to turn the illumination source on while LED_OFF corresponds
 * to the TTL signal level used to turn the illumination source off.
 * These values are used to set the logic state of Arduino digital
 * output pins
 ****************************************************************/
#define LED_ON HIGH
#define LED_OFF LOW

//Define how many sources will be strobed
#define LENGTH_LED_ARRAY 2

//Global variables
volatile int incoming_value;
volatile int value;
int *LED_order = NULL;
volatile int LED_array[] = {DAC0,DAC1};//{52,51};//{8,10,12,6}; //these pins have LEDs attached to them.
//volatile int Exposure_Output_pin=4; //this pin outputs the exposure signal read from the camera.

volatile int Stim_Delay_pin=38;
//volatile int Stim_Delay_state=0;

volatile int ledToggleIndex = 0;
volatile int numberOfElements = 0;
volatile int nextLED=0;
volatile int start_delay=1;

//volatile int DelayedPulseOutput_pin=47; 
//volatile int Stim_DelayPulse_pin=39;
//volatile int Stim_DelayPulse_state=0;

volatile int state=0;


volatile int Bcontrol_pin=31;
volatile int Gatestate=LOW;


void setup()
{
  SerialUSB.begin(9600);
  for (int i=0; i<1; i++)
  {
    pinMode(LED_array[i],OUTPUT);
    //digitalWrite(LED_array[i],LED_OFF);
      analogWrite(LED_array[i],0);
  }
  pinMode(Stim_Delay_pin,INPUT);
//  pinMode(Exposure_Output_pin,OUTPUT);
//  digitalWrite(Exposure_Output_pin,LED_OFF); 
  
//  pinMode(Stim_DelayPulse_pin,INPUT);
//  pinMode(DelayedPulseOutput_pin,OUTPUT);
//  digitalWrite(DelayedPulseOutput_pin,LOW);

 //gating functionality
 pinMode(Bcontrol_pin,INPUT);        //input pin
 digitalWrite(digitalPinToInterrupt(Bcontrol_pin),LOW);
 
}

void loop()
{
  while (SerialUSB.available()>0)
  {
    incoming_value = SerialUSB.read();
    switch (incoming_value)
    {
    case 99: // c
      detachInterrupt(digitalPinToInterrupt(Stim_Delay_pin));
//      detachInterrupt(digitalPinToInterrupt(Stim_DelayPulse_pin));
      turn_off_all_LEDs();
      if (NULL != LED_order)
      {
        free(LED_order);
        LED_order = NULL;
      }
      SerialUSB.print("Interrupts disabled"); 
      break;

    case 116:  // t
      // Turn off all LEDs first
      //SerialUSB.println("Toggle all LEDs OFF");
      turn_off_all_LEDs();

      delay(10);
      //SerialUSB.println("Toggle next LED ON");
      ledToggleIndex = SerialUSB.read() - 49;
      //SerialUSB.println(LED_array[ledToggleIndex], DEC);
      //digitalWrite(LED_array[ledToggleIndex], LED_ON);
      analogWrite(LED_array[ledToggleIndex], 255);
      SerialUSB.print(ledToggleIndex+1,DEC);   
      break;

    case 120: // x
      SerialUSB.println("Toggle all LEDs OFF");
      turn_off_all_LEDs();
      break;

    case 115: // s
      delay(10);
      // read number of available bytes
      numberOfElements = SerialUSB.available();

      // allocate array using malloc and initalize all elements to 0
      LED_order = (int *) malloc(numberOfElements * sizeof(int));
      for (int counter = 0; counter < numberOfElements; counter++)   {
        LED_order[counter] = 0;
      }

      // Read in strobe order
      for (int counter = 0; counter < numberOfElements; counter++)   {
        LED_order[counter] = SerialUSB.read() - 49;
      }

      SerialUSB.println("LED_order is:");
      for (int counter = 0; counter < numberOfElements; counter++)   {
        SerialUSB.println(LED_order[counter], DEC);
      }

      SerialUSB.println("Pin order");
      for (int counter = 0; counter < numberOfElements; counter++)   {
        SerialUSB.println(LED_array[LED_order[counter]], DEC);
      }

      nextLED=0;
      //digitalWrite(Exposure_Output_pin,LED_OFF);
      digitalWrite(digitalPinToInterrupt(Stim_Delay_pin),LOW);
     // digitalWrite(digitalPinToInterrupt(Stim_DelayPulse_pin),LOW);
      start_delay=1;
      ////attachInterrupt(digitalPinToInterrupt(Stim_Delay_pin), strobe_on_LEDs, RISING);
      ////attachInterrupt(digitalPinToInterrupt(Stim_Delay_pin_off), strobe_off_LEDs, FALLING);

     // attachInterrupt(digitalPinToInterrupt(Stim_DelayPulse_pin), DelayFramePulse, CHANGE);
      attachInterrupt(digitalPinToInterrupt(Stim_Delay_pin), strobe_on_LEDs, CHANGE);
      
      
      //attachInterrupt(0, strobe_on_LEDs, RISING);
      //attachInterrupt(1, strobe_off_LEDs, FALLING);
      SerialUSB.print("Interrupts enabled");
      break;  

//    case 114: //r
//      //digitalWrite(Stim_Delay_pin, LOW);
//      SerialUSB.print("Stim Trigger Reset");  
//      break;
//
//    case 82: //R
//      //digitalWrite(Stim_Delay_pin, HIGH);
//      SerialUSB.print("Stim Trigger Reset");  
//      break;

    case 97: //a
      SerialUSB.print("State reset");
      nextLED=0;
      break;

    case 102: //f
      SerialUSB.flush();
      SerialUSB.println("Flush");
      break;

//    case 77: //M (legacy from Matt's code to check comm status)
//      SerialUSB.println("I'm ready to get the data");
//      break;
//
//    case 100: //d -- Stim Delay read
//      Stim_Delay_state=digitalRead(Stim_Delay_pin);
//      if (Stim_Delay_state==1)
//      {
//        SerialUSB.print("Ready");
//      }
//      else
//      {
//        SerialUSB.print("Wait");
//      }
//      break;
    }
  }
}


void strobe_on_LEDs()
{
  if (start_delay==1){
    interrupts();
    delayMicroseconds(0); //5000 originally
    start_delay=0;
  }
  //SerialUSB.println(LED_array[LED_order[nextLED]]);



  Gatestate=digitalRead(Bcontrol_pin);
  //if the gate is LOW, skip turning ONthe LEDs
  if (Gatestate) 
  {value=0;} 
  else
  {value=255;}


  
  //digitalWrite(LED_array[LED_order[nextLED]], LED_ON);
  analogWrite(LED_array[LED_order[nextLED]], value);
  //digitalWrite(Exposure_Output_pin,LED_ON);

  // delayMicroseconds(500);
  //delayMicroseconds(9000); // do not exceed value 16383// both 30Hz and 60Hz
  delayMicroseconds(16000); //use also this one for 30Hz
  delayMicroseconds(2000); //use also this one for 30Hz
  //strobe_off_LEDs;
  //digitalWrite(LED_array[LED_order[nextLED]], LED_OFF);
      analogWrite(LED_array[LED_order[nextLED]], 0);
  //digitalWrite(Exposure_Output_pin,LED_OFF);
   if (nextLED < (numberOfElements - 2)) // hack: going to end-1 as matlab is sending an empty element
  {
    nextLED++;
  }
  else if (nextLED == (numberOfElements - 2))
  {
    nextLED = 0;
  }
}

//void DelayFramePulse()
//{
//  state=digitalRead(Stim_DelayPulse_pin);
//  delayMicroseconds(10000);
//  delayMicroseconds(7000);
//  digitalWrite(DelayedPulseOutput_pin,state);
//}

void strobe_off_LEDs()
{
  //digitalWrite(LED_array[LED_order[nextLED]], LED_OFF);
       analogWrite(LED_array[LED_order[nextLED]], 0);
  //digitalWrite(Exposure_Output_pin,LED_OFF);
  if (nextLED < (numberOfElements - 2)) // hack: going to end-1 as matlab is sending an empty element
  {
    nextLED++;
  }
  else if (nextLED == (numberOfElements - 2))
  {
    nextLED = 0;
  }
}

void turn_off_all_LEDs()
{
  for (int i=0; i < LENGTH_LED_ARRAY; i++)
  {
    //digitalWrite(LED_array[i], LED_OFF);
    analogWrite(LED_array[i], 0);    
  }
  //digitalWrite(Exposure_Output_pin,LED_OFF);
}


