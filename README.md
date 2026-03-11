LED CONTROLS APP 


# Brubaker LED Controls

We are very big fans of the WS2812B Individually Addressable LEDs in our home. So much so, that we have many strips strung up all throughout. We control our strips using ESP-01 microcontrollers, and having grown tired of going around and plugging-in/unplugging several strips regularly, I decided to develop an app to allow ourselves + guests to control the LED animations/turn them off conveniently. This app interfaces with a basic flask server hosted on our network which, in-turn, sends out the animation calls to all of the little ESPs. It is toad themed for a touch of personal flair. 

# Dependancies

This app is very simple in that it is no more than a collection of buttons correlating to different API calls, which are then interpreted by our server to prompt our LED strip. It relies on the central server for operation, so if intending for re-use, you will need to make slight modifications to integrate your network. The ESP-01 is effectively over-clocked to be able to handle our 300 LED strips, so most any microcontroller should be suitable depending on the complexity of your patterns. 
