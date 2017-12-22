/***************************************************************
 * This code reproducesthe an input Digital input on a digital output pin
 * after a fixeddelay.
 ****************************************************************/

//Global variables

volatile int DelayedPulseOutput_pin=47; 
volatile int Stim_DelayPulse_pin=39;

volatile int state=LOW;

void setup()
{
  
  pinMode(Stim_DelayPulse_pin,INPUT);        //input pin
  pinMode(DelayedPulseOutput_pin,OUTPUT);    //outputpin
  digitalWrite(DelayedPulseOutput_pin,LOW);
  
  digitalWrite(digitalPinToInterrupt(Stim_DelayPulse_pin),LOW);
  attachInterrupt(digitalPinToInterrupt(Stim_DelayPulse_pin), DelayFramePulse, CHANGE);

}

void loop()
{
 digitalWrite(DelayedPulseOutput_pin, state);
}


void DelayFramePulse()
{
  state=digitalRead(Stim_DelayPulse_pin);
  //delayMicroseconds(9000);//for 60Hz exposures
  delayMicroseconds(2000);//for 60Hz exposures
  //delayMicroseconds(10000); //1- for 30Hz exposures
  //delayMicroseconds(8000);  //2- for 30Hz exposures
}



