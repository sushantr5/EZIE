import webserver # import webserver class
import string
import mqtt
import json
import persist

#settings
var color_button_off = 0x00FF00
var color_button_on = 0xff0000
var color_fan_speed_bar = 0xc20000
var lights_timeout = 40 #seconds
var lights_dim_percentage = 50 #percentage
#settings end

var leds_left = Leds(4, 16);
var leds_right = Leds(2, 4);

def persist_load()
  if(persist.has('color_button_off'))
    color_button_off = persist.color_button_off
  end
  
  if(persist.has('color_button_on'))
    color_button_on = persist.color_button_on
  end

  if(persist.has('lights_timeout'))
    lights_timeout = persist.lights_timeout
  end
  
  if(persist.has('lights_dim_percentage'))
    lights_dim_percentage = persist.lights_dim_percentage
  end

  var power_list = tasmota.get_power()
  if (size(power_list) > 3)
    if(persist.has('state_power_1'))
      tasmota.set_power(0, persist.state_power_1)
    end
    if(persist.has('state_power_2'))
      tasmota.set_power(1, persist.state_power_2)
    end
    if(persist.has('state_power_3'))
      tasmota.set_power(2, persist.state_power_3)
    end
    if(persist.has('state_power_4'))
      tasmota.set_power(3, persist.state_power_4)
    end
  end
end

persist_load()
var ez_cfgtr = ezie_ws2812_configurator(color_button_on, color_button_off, color_fan_speed_bar, lights_timeout, lights_dim_percentage)
var ha_discovery = ezie_home_assistant_discovery(1)

def persist_save()
  tasmota.log(string.format("persist_save"), 4)
  
  persist.color_button_off = color_button_off
  persist.color_button_on = color_button_on
  persist.lights_timeout = lights_timeout
  persist.lights_dim_percentage = lights_dim_percentage

  var power_list = tasmota.get_power()
  if (size(power_list) > 3)
    persist.state_power_1 = power_list.pop(0)
    persist.state_power_2 = power_list.pop(0)
    persist.state_power_3 = power_list.pop(0)
    persist.state_power_4 = power_list.pop(0)
  end

  persist.save() # save to _persist.json
end

def lights_timeout_function()
  tasmota.log(string.format("lights_timeout_function"), 4)
  leds_left.clear()
  leds_right.clear()
  
  if ( lights_dim_percentage != 0 )
    var r = ((color_button_on >> 16) & 0xff)
    var g = ((color_button_on >> 8) & 0xff)
    var b = ((color_button_on) & 0xff)
  
    var factor = 100.0/lights_dim_percentage
  
    var dimmed_rgb = int(string.replace(format("#%02X%02X%02X", r/factor, g/factor, b/factor), "#", "0x"))
  
    var power_list = tasmota.get_power()                                        # get a list of booleans with status of each relay
    if size(power_list) > 3
      power_list.pop(0)? leds_left.set_pixel_color( 0, dimmed_rgb ) : leds_left.set_pixel_color( 0, 0x000000 )
      power_list.pop(0)? leds_right.set_pixel_color( 0, dimmed_rgb ) : leds_right.set_pixel_color( 0, 0x000000 )
      power_list.pop(0)? leds_right.set_pixel_color( 1, dimmed_rgb ) : leds_right.set_pixel_color( 1, 0x000000 )
      power_list.pop(0)? leds_left.set_pixel_color( 3, dimmed_rgb ) : leds_left.set_pixel_color( 3, 0x000000 )
    end
  end
  
  leds_right.show()
  leds_left.show()
end

def touch_indication_function()
  tasmota.log(string.format("touch_indication_function"), 4)
end

def button_click(index)
  tasmota.log(string.format("Button #%d clicked",index+1),4)
  tasmota.remove_timer('touch_indication')
  
  var power_list = tasmota.get_power()                                            # get a list of booleans with status of each relay
  var power_state = (size(power_list) > index) ? power_list.pop(index) : false            # avoid exception if less relays than buttons  
  if power_state == true
    tasmota.set_power(index, false);
  else
    tasmota.set_power(index, true);
  end
  tasmota.set_timer(200, touch_indication_function, 'touch_indication')
end

def update_status_leds()
  tasmota.log("update_status_leds")
  tasmota.remove_timer('lights_timeout')

  leds_left.set_pixel_color( 1, 0x000000);
  leds_left.set_pixel_color( 2, 0x000000);
  var power_list = tasmota.get_power()                                        # get a list of booleans with status of each relay
  if size(power_list) > 3
    power_list.pop(0)? leds_left.set_pixel_color( 0, color_button_on ) : leds_left.set_pixel_color( 0, color_button_off )
    power_list.pop(0)? leds_right.set_pixel_color( 0, color_button_on ) : leds_right.set_pixel_color( 0, color_button_off )
    power_list.pop(0)? leds_right.set_pixel_color( 1, color_button_on ) : leds_right.set_pixel_color( 1, color_button_off )
    power_list.pop(0)? leds_left.set_pixel_color( 3, color_button_on ) : leds_left.set_pixel_color( 3, color_button_off )
  end
  leds_left.show()
  leds_right.show()
  
  tasmota.set_timer(lights_timeout * 1000, lights_timeout_function, 'lights_timeout')
end

def on_system_boot()
  persist_load()
  update_status_leds()
end

def ws2812_settings_changed()
  tasmota.log(string.format("ws2812_settings_changed"), 4)
  color_button_on = ez_cfgtr.get_ACTION_or_ON_state_color()
  color_button_off = ez_cfgtr.get_NORMAL_or_OFF_state_color()
  lights_timeout = ez_cfgtr.get_LIGHTS_timeout()
  lights_dim_percentage = ez_cfgtr.get_LIGHTS_dim_percentage() 
  persist_save()
  update_status_leds()
end

tasmota.add_rule("button1#Action=SINGLE", def (value) button_click(0) end )
tasmota.add_rule("button2#Action=SINGLE", def (value) button_click(1) end )
tasmota.add_rule("button3#Action=SINGLE", def (value) button_click(2) end )
tasmota.add_rule("button4#Action=SINGLE", def (value) button_click(3) end )
tasmota.add_rule("System#Init", on_system_boot )

tasmota.add_rule("EZIE#WS2812_Updated==1", ws2812_settings_changed )

tasmota.add_rule("Power1#state", update_status_leds)
tasmota.add_rule("Power2#state", update_status_leds)
tasmota.add_rule("Power3#state", update_status_leds)
tasmota.add_rule("Power4#state", update_status_leds)

update_status_leds()

print("4_RLY_SWITCH")

