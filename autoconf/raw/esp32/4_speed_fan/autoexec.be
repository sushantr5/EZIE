import webserver # import webserver class
import string
import mqtt
    
import json
import persist

#settings
var color_fan_speed_bar = 0xc20000
var color_button_normal = 0x00FF00
var color_button_pressed = 0xff0000
var lights_timeout = 40 #seconds
#settings end


var ez_fan = ezie_fan()

var fan_speed = 0;


var leds_left = Leds(4, 16);
var leds_right = Leds(2, 4);

var ha_discovery_sent = false
var mqtt_connected = false

var press_indication_counter = 0;


def persist_load()

  if(persist.has('fan_speed'))
    fan_speed = persist.fan_speed
  end
  
  if(persist.has('color_fan_speed_bar'))
    color_fan_speed_bar = persist.color_fan_speed_bar
  end
  
  if(persist.has('color_button_normal'))
    color_button_normal = persist.color_button_normal
  end
  
  if(persist.has('color_button_pressed'))
    color_button_pressed = persist.color_button_pressed
  end
  
  if(persist.has('lights_timeout'))
    lights_timeout = persist.lights_timeout
  end
end

persist_load()
var ez_cfgtr = ezie_ws2812_configurator(color_button_pressed, color_button_normal, color_fan_speed_bar, lights_timeout)

def persist_save()
  persist.fan_speed = fan_speed
  persist.color_fan_speed_bar = color_fan_speed_bar
  persist.color_button_normal = color_button_normal
  persist.color_button_pressed = color_button_pressed
  persist.lights_timeout = lights_timeout
  persist.save() # save to _persist.json
end

def button_press_indicator(index)
  if index == -1
    leds_right.set_pixel_color( 0, color_button_normal)
    leds_right.set_pixel_color( 1, color_button_normal)
  elif index == 1
    leds_right.set_pixel_color( 0, color_button_pressed)
  elif index == 2
    leds_right.set_pixel_color( 1, color_button_pressed)
  end

  leds_right.show()
end

def lights_timeout_function()
  tasmota.log(string.format("lights_timeout_function"), 4)
  leds_left.clear()
  leds_right.clear()
  leds_right.show()
  leds_left.show()
end

def touch_indication_function()
  tasmota.log(string.format("touch_indication_function"), 4)
  button_press_indicator(-1)
end

def update_status_leds()
  tasmota.log(string.format("update_status_leds"), 4)
  tasmota.remove_timer('lights_timeout')
  
  leds_left.set_pixel_color( 0, 0x000000)
  leds_left.set_pixel_color( 1, 0x000000)
  leds_left.set_pixel_color( 2, 0x000000)
  leds_left.set_pixel_color( 3, 0x000000)
  
  for i:0..(fan_speed-1)
    leds_left.set_pixel_color( i, color_fan_speed_bar)
  end
  leds_left.show()
  
  tasmota.set_timer(lights_timeout * 1000, lights_timeout_function, 'lights_timeout')
end

def button_click(index)
  tasmota.log(string.format("Button #%d clicked",index+1),4)
  
  tasmota.remove_timer('touch_indication')

  if index == 2
    button_press_indicator(2)
    tasmota.cmd("fanspeed +")
  end

  if index == 1
    button_press_indicator(1)
    tasmota.cmd("fanspeed -")
  end
  
  tasmota.set_timer(200, touch_indication_function, 'touch_indication')
  
end

def on_system_boot()
  persist_load()
  tasmota.cmd(string.format("fanspeed %d", fan_speed))
  update_status_leds()
end

def fan_speed_changed(value)
  tasmota.log(string.format("fan_speed_changed"), 4)
  if( value != fan_speed )
     tasmota.log(string.format("Existing Value:%d, New Value:%d",fan_speed,value), 4)
    fan_speed = value;
    persist_save()
    update_status_leds()
  end
end

def ws2812_settings_changed()
  tasmota.log(string.format("ws2812_settings_changed"), 4)
  color_button_pressed = ez_cfgtr.get_ACTION_or_ON_state_color()
  color_button_normal = ez_cfgtr.get_NORMAL_or_OFF_state_color()
  color_fan_speed_bar = ez_cfgtr.get_SPEED_indicator_bar_color()
  lights_timeout = ez_cfgtr.get_LIGHTS_timeout()
  persist_save()
  update_status_leds()
end

tasmota.add_rule("button1#Action=SINGLE", def (value) button_click(0) end )
tasmota.add_rule("button2#Action=SINGLE", def (value) button_click(1) end )
tasmota.add_rule("button3#Action=SINGLE", def (value) button_click(2) end )
tasmota.add_rule("button4#Action=SINGLE", def (value) button_click(3) end )
tasmota.add_rule("System#Init", on_system_boot )
tasmota.add_rule("EZIE#FanSpeed_Updated==0", def (value) fan_speed_changed(value) end )
tasmota.add_rule("EZIE#FanSpeed_Updated==1", def (value) fan_speed_changed(value) end )
tasmota.add_rule("EZIE#FanSpeed_Updated==2", def (value) fan_speed_changed(value) end )
tasmota.add_rule("EZIE#FanSpeed_Updated==3", def (value) fan_speed_changed(value) end )
tasmota.add_rule("EZIE#FanSpeed_Updated==4", def (value) fan_speed_changed(value) end )

tasmota.add_rule("EZIE#WS2812_Updated==1", ws2812_settings_changed )

print("4_SPEED_FAN")
