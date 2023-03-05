import webserver # import webserver class
import string
import mqtt
import json
import persist

#settings
var color_button_off = 0x00FF00
var color_button_on = 0xff0000
var lights_dim_timeout = 20 #seconds
var lights_timeout = 40 #seconds
#settings end

#TODO
# DONE Use Persist Module
# MQTT Discovery for settings 
# Use Lights dim timeout
# Use Lights Timeout

var leds_left = Leds(4, 16);
var leds_right = Leds(2, 4);

var ha_discovery_sent = false
var mqtt_connected = false

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

def persist_save()
  persist.color_button_off = color_button_off
  persist.color_button_on = color_button_on
  persist.lights_timeout = lights_timeout

  var power_list = tasmota.get_power()
  if (size(power_list) > 3)
    persist.state_power_1 = power_list.pop(0)
    persist.state_power_2 = power_list.pop(0)
    persist.state_power_3 = power_list.pop(0)
    persist.state_power_4 = power_list.pop(0)
  end

  print(persist.state_power_1)
  print(persist.state_power_2)
  print(persist.state_power_3)
  print(persist.state_power_4)
  persist.save() # save to _persist.json
end

def button_click(index)
  print("Button #",index+1," Clicked")
  
  var power_list = tasmota.get_power()                                            # get a list of booleans with status of each relay
  var power_state = (size(power_list) > index) ? power_list.pop(index) : false            # avoid exception if less relays than buttons  
  if power_state == true
    tasmota.set_power(index, false);
  else
    tasmota.set_power(index, true);
  end
end

def update_status_leds(bResetCounter)

  persist_save()

  leds_left.set_pixel_color( 1, 0x000000);
  leds_left.set_pixel_color( 2, 0x000000);
  var power_list = tasmota.get_power()                                        # get a list of booleans with status of each relay
  if size(power_list) > 3
    power_list.pop(0)? leds_left.set_pixel_color( 0, 0xFF0000) : leds_left.set_pixel_color( 0, 0x00FF00)
    power_list.pop(0)? leds_right.set_pixel_color( 0, 0xFF0000) : leds_right.set_pixel_color( 0, 0x00FF00)
    power_list.pop(0)? leds_right.set_pixel_color( 1, 0xFF0000) : leds_right.set_pixel_color( 1, 0x00FF00)
    power_list.pop(0)? leds_left.set_pixel_color( 3, 0xFF0000) : leds_left.set_pixel_color( 3, 0x00FF00)
  end
  leds_left.show()
  leds_right.show()
end

def send_ha_discovery_message()
  var payload_json = tasmota.cmd("mqtthost")
  var mqtthost = payload_json.find("MqttHost")
  if( size(mqtthost) == 0)
    return
  end
    
  print("Sending HA Discovery Message...")
  mqtt_connected = true

  payload_json = tasmota.cmd("Status")
  var status_json = payload_json.find("Status")
  var name = status_json.find("DeviceName")
  var friendly_names = status_json.find("FriendlyName")
  var unique_id = status_json.find("Topic")

  var discovery_msg_map = {'platform':'mqtt'}
  if( friendly_names[0] != nil )
    discovery_msg_map.setitem('name', friendly_names[0])
  else
    discovery_msg_map.setitem('name', name  + "_1" )
  end
  discovery_msg_map.setitem('device_class','switch')
  discovery_msg_map.setitem('unique_id',unique_id + "_1")
  discovery_msg_map.setitem('command_topic','cmnd/'+unique_id+'/POWER1')
  discovery_msg_map.setitem('state_topic','stat/'+unique_id+'/POWER1')
  discovery_msg_map.setitem('availability_topic', 'tele/'+unique_id+'/LWT')
  discovery_msg_map.setitem('payload_available', 'Online')
  discovery_msg_map.setitem('payload_not_available', 'Offline')
  discovery_msg_map.setitem('payload_off', 'OFF')
  discovery_msg_map.setitem('payload_on', 'ON')
    
  mqtt.publish('homeassistant/switch/' + unique_id + "_1" + '/config', json.dump(discovery_msg_map,['format']), true )
  
  if( friendly_names[1] != nil )
    discovery_msg_map.setitem('name', friendly_names[1])
  else
    discovery_msg_map.setitem('name', name  + "_2" )
  end
  discovery_msg_map.setitem('unique_id',unique_id + "_2")
  discovery_msg_map.setitem('command_topic','cmnd/'+unique_id+'/POWER2')
  discovery_msg_map.setitem('state_topic','stat/'+unique_id+'/POWER2')
  mqtt.publish('homeassistant/switch/' + unique_id + "_2" + '/config', json.dump(discovery_msg_map,['format']), true )

  if( friendly_names[2] != nil )
    discovery_msg_map.setitem('name', friendly_names[2])
  else
    discovery_msg_map.setitem('name', name  + "_3" )
  end
  discovery_msg_map.setitem('unique_id',unique_id + "_3")
  discovery_msg_map.setitem('command_topic','cmnd/'+unique_id+'/POWER3')
  discovery_msg_map.setitem('state_topic','stat/'+unique_id+'/POWER3')
  mqtt.publish('homeassistant/switch/' + unique_id + "_3" + '/config', json.dump(discovery_msg_map,['format']), true )

  if( friendly_names[3] != nil )
    discovery_msg_map.setitem('name', friendly_names[3])
  else
    discovery_msg_map.setitem('name', name  + "_4" )
  end
  discovery_msg_map.setitem('unique_id',unique_id + "_4")
  discovery_msg_map.setitem('command_topic','cmnd/'+unique_id+'/POWER4')
  discovery_msg_map.setitem('state_topic','stat/'+unique_id+'/POWER4')
  mqtt.publish('homeassistant/switch/' + unique_id + "_4" + '/config', json.dump(discovery_msg_map,['format']), true )
  ha_discovery_sent = true
end

class MyButtonMethods : Driver

  #- create a method for adding a button to the main menu -#
  def web_add_main_button()
    webserver.content_send("<details style='width:100%'><summary>More Settings for EZIE Device<span class=\"icon\">...</span></summary><p>"..
    "<table style='width:100%'>" ..
    "<script>function call_la(arg,t){ var value=t.value; value = value.substring(1); var vint=parseInt(value, 16); 	la('&'+arg+'='+vint); }</script>"..
    "<tr><td><div><label for=\"bar_color\">Switch OFF color:</label><input type=\"color\" id=\"bar_color\" name=\"bar_color\" value=\"#c20000\" onchange='call_la(\"m_color_off\",this)'></div></td></tr>"..
    "<tr><td><div><label for=\"normal_color\">Switch ON color:</label><input type=\"color\" id=\"normal_color\" name=\"normal_color\" value=\"#00FF00\" onchange='call_la(\"m_color_on\",this)'></div></td></tr>"..
    "<tr><td><div><label for=\"lights_timeout\">Lights Timeout in seconds:</label><input type=\"range\" id=\"lights_timeout\" name=\"lights_timeout\" min=\"5\" max=\"100\" value=\"50\" step=\"5\" class=\"slider\" onchange='la(\"&m_timeout=\"+this.value);' oninput='this.nextElementSibling.value = this.value'><output>50</output></div></td></tr>"..
    "<tr></tr>".. 
    "</table>"..
    "</p></details>")
  end

  #- As we can add only one sensor method we will have to combine them besides all other sensor readings in one method -#
  def web_sensor()
  
    if webserver.has_arg("m_timeout")
        var timeout = webserver.arg("m_timeout")
        print ( "Light Timeout Received:"+timeout)
        lights_timeout = int(timeout)
        persist_save()
    end

    if webserver.has_arg("m_color_off")
        var color = webserver.arg("m_color_off")
        print ( "Color Argument Received:"+color)
        color_button_off = int(color)
        update_status_leds(true)
        persist_save()
    end
    
    if webserver.has_arg("m_color_on")
        var color = webserver.arg("m_color_on")
        print ( "Color Argument Received:"+color)
        color_button_on = int(color)
        update_status_leds(true)
        persist_save()
    end    
  end
  
  def every_second()
    update_status_leds(false)
    if ha_discovery_sent == false && mqtt_connected == true
      send_ha_discovery_message()
    end
  end
end

def on_system_boot()
  persist_load()
  update_status_leds(true)
end

var d1 = MyButtonMethods()
tasmota.add_driver(d1)

tasmota.add_rule("button1#action=single", def (value) button_click(0) end )
tasmota.add_rule("button2#action=single", def (value) button_click(1) end )
tasmota.add_rule("button3#action=single", def (value) button_click(2) end )
tasmota.add_rule("button4#action=single", def (value) button_click(3) end )

tasmota.add_rule("System#Init", on_system_boot )

tasmota.add_rule("Power1#state", update_status_leds)
tasmota.add_rule("Power2#state", update_status_leds)
tasmota.add_rule("Power3#state", update_status_leds)
tasmota.add_rule("Power4#state", update_status_leds)

tasmota.add_rule("Mqtt#Connected", send_ha_discovery_message )

update_status_leds(true)
print("4_RLY_SWITCH")

