import webserver # import webserver class
import string
import mqtt
import json
import persist

#settings
var color_fan_speed_bar = 0xc20000
var color_button_normal = 0x00FF00
var color_button_pressed = 0xff0000
var time_button_pressed_indication = 2 # multiplied by 100 nanoseconds
var lights_dim_timeout = 20 #seconds
var lights_timeout = 40 #seconds
var timeout_counter = 40
#settings end

#local variables
var set_speed = 0;


var leds_left = Leds(4, 16);
var leds_right = Leds(2, 4);

var ha_discovery_sent = false
var mqtt_connected = false

var press_indication_counter = 0;


def persist_load()

  if(persist.has('set_speed'))
    set_speed = persist.set_speed
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
    timeout_counter = lights_timeout
  end
end

def persist_save()
  persist.set_speed = set_speed
  persist.color_fan_speed_bar = color_fan_speed_bar
  persist.color_button_normal = color_button_normal
  persist.color_button_pressed = color_button_pressed
  persist.lights_timeout = lights_timeout
  persist.save() # save to _persist.json
end


def reset_button_press_indicator_counter()
  press_indication_counter = time_button_pressed_indication;
end

def turn_off_lights_after_timeout()
end

def button_press_indicator(index)
  if index == -1
    if press_indication_counter == 0
      if( timeout_counter <= 0 )
        leds_right.clear()
        leds_right.show()
        return;
      end
      leds_right.set_pixel_color( 0, color_button_normal)
      leds_right.set_pixel_color( 1, color_button_normal)
    end
  elif index == 1
    leds_right.set_pixel_color( 0, color_button_pressed)
  elif index == 2
    leds_right.set_pixel_color( 1, color_button_pressed)
  end

  leds_right.show()
end

def update_status_leds(bResetTimer)

  if( bResetTimer )
    timeout_counter = lights_timeout
  end
  
  if( timeout_counter <= 0 )
    leds_left.clear()
    leds_left.show()
    return;
  end
  
  timeout_counter-=1

  leds_left.set_pixel_color( 0, 0x000000)
  leds_left.set_pixel_color( 1, 0x000000)
  leds_left.set_pixel_color( 2, 0x000000)
  leds_left.set_pixel_color( 3, 0x000000)
  
  for i:0..(set_speed-1)
    leds_left.set_pixel_color( i, color_fan_speed_bar)
  end
  leds_left.show()
end
#OUT1:GPIO15
#OUT2:GPIO17
#OUT3:GPIO18
#OUT4:GPIO19

#FAN Module
#OUT1:Direct
#OUT2:2.2 uF
#OUT3:3.3 uF

var out1 = 15
var out2 = 17
var out3 = 18
var out4 = 19

var bUpdate_fan_relay = false

def update_fan_relays()
  persist_save()

  if set_speed == 3
    print("GPIO ON: 17, 18")
    gpio.digital_write(out1, gpio.LOW)
    gpio.digital_write(out2, gpio.HIGH)
    gpio.digital_write(out3, gpio.HIGH)
  elif set_speed == 2
    print("GPIO ON: 18")
    gpio.digital_write(out1, gpio.LOW)
    gpio.digital_write(out2, gpio.LOW)
    gpio.digital_write(out3, gpio.HIGH)
  elif set_speed == 1
    print("GPIO ON: 17")
    gpio.digital_write(out1, gpio.LOW)
    gpio.digital_write(out2, gpio.HIGH)
    gpio.digital_write(out3, gpio.LOW)
  elif set_speed == 4
    print("GPIO ON: 15")
    gpio.digital_write(out1, gpio.HIGH)
    gpio.digital_write(out2, gpio.LOW)
    gpio.digital_write(out3, gpio.LOW)
  elif set_speed == 0
    print("GPIO ON: 17")
    gpio.digital_write(out1, gpio.LOW)
    gpio.digital_write(out3, gpio.LOW)
    gpio.digital_write(out2, gpio.LOW)
  end
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
  var unique_id = status_json.find("Topic")

  var discovery_msg_map = {'platform':'mqtt'}
  discovery_msg_map.setitem('name', name)
  discovery_msg_map.setitem('device_class','fan')
  discovery_msg_map.setitem('unique_id',unique_id)
  discovery_msg_map.setitem('command_topic','cmnd/'+unique_id+'/FanSpeed')
  discovery_msg_map.setitem('state_topic','stat/'+unique_id+'/RESULT')
  discovery_msg_map.setitem('state_value_template', "{% if value_json.FanSpeed == 0 -%}0{%- elif value_json.FanSpeed != 0 -%}1{%- endif %}")
  discovery_msg_map.setitem('availability_topic', 'tele/'+unique_id+'/LWT')
  discovery_msg_map.setitem('payload_available', 'Online')
  discovery_msg_map.setitem('payload_not_available', 'Offline')
  discovery_msg_map.setitem('payload_off', '0')
  discovery_msg_map.setitem('payload_on', '1')
  discovery_msg_map.setitem('preset_modes', ['off', 'low','medium','high','full'])
  discovery_msg_map.setitem('preset_mode_command_topic', 'cmnd/'+unique_id+'/FanSpeed')
  discovery_msg_map.setitem('preset_mode_command_template', "{% if value == 'low' %} 1 {% elif value == 'medium' %} 2 {% elif value == 'high' %} 3 {% elif value == 'full' %} 4 {% else %} 0 {% endif %}")
  discovery_msg_map.setitem('preset_mode_state_topic', 'stat/'+unique_id+'/RESULT')
  discovery_msg_map.setitem('preset_mode_value_template', "{% if value_json.FanSpeed == 1 %} low {% elif value_json.FanSpeed == 2 %} medium {% elif value_json.FanSpeed == 3 %} high {% elif value_json.FanSpeed == 4 %} full {% elif value_json.FanSpeed == 0 %} off {% endif %}")
  discovery_msg_map.setitem('percentage_command_topic', 'cmnd/'+unique_id+'/FanSpeed')
  discovery_msg_map.setitem('percentage_state_topic', 'stat/'+unique_id+'/RESULT')
  discovery_msg_map.setitem('percentage_value_template', "{{ value_json.FanSpeed }}")
  discovery_msg_map.setitem('speed_range_min', 1 )
  discovery_msg_map.setitem('speed_range_max', 4 )
    
  print(discovery_msg_map)
  mqtt.publish('homeassistant/fan/' + unique_id + '/' + unique_id + '/config', json.dump(discovery_msg_map,['format']), true )
  ha_discovery_sent = true
end

class MyButtonMethods : Driver

  def myOtherFunction(myValue)
    #- do something -#
  end

  #- create a method for adding a button to the main menu -#
  def web_add_main_button()
    webserver.content_send("<table style='width:100%'>" ..
    "<tr>"..
     "<td style='width:20%'><button onclick='la(\"&m_speed_0=1\");'>0</button></td>"..
     "<td style='width:20%'><button onclick='la(\"&m_speed_1=1\");'>1</button></td>"..
     "<td style='width:20%'><button onclick='la(\"&m_speed_2=1\");'>2</button></td>"..
     "<td style='width:20%'><button onclick='la(\"&m_speed_3=1\");'>3</button></td>"..
     "<td style='width:20%'><button onclick='la(\"&m_speed_4=1\");'>4</button></td>"..
    "</tr>"..
    "<tr></tr>".. 
    "</table>"..
    "<details style='width:100%'><summary>More Settings for EZIE Device<span class=\"icon\">...</span></summary><p>"..
    "<table style='width:100%'>" ..
    "<script>function call_la(arg,t){ var value=t.value; value = value.substring(1); var vint=parseInt(value, 16); 	la('&'+arg+'='+vint); }</script>"..
    "<tr><td><div><label for=\"bar_color\">Speed Indicator Color:</label><input type=\"color\" id=\"bar_color\" name=\"bar_color\" value=\"#c20000\" onchange='call_la(\"m_color_bar\",this)'></div></td></tr>"..
    "<tr><td><div><label for=\"normal_color\">Button Color:</label><input type=\"color\" id=\"normal_color\" name=\"normal_color\" value=\"#00FF00\" onchange='call_la(\"m_color_normal\",this)'></div></td></tr>"..
    "<tr><td><div><label for=\"pressed_color\">Button Pressed Color:</label><input type=\"color\" id=\"pressed_color\" name=\"pressed_color\" value=\"#FF0000\" onchange='call_la(\"m_color_pressed\",this)'></div></td></tr>"..
    "<tr><td><div><label for=\"lights_timeout\">Lights Timeout in seconds:</label><input type=\"range\" id=\"lights_timeout\" name=\"lights_timeout\" min=\"0\" max=\"100\" value=\"50\" step=\"5\" class=\"slider\" onchange='la(\"&m_timeout=\"+this.value);' oninput='this.nextElementSibling.value = this.value'><output>50</output></div></td></tr>"..
    "<tr></tr>".. 
    "</table>"..
    "</p></details>")
  end

  #- create a method for adding a button to the configuration menu-#
  def web_add_button()
    #- the onclick function "la" takes the function name and the respective value you want to send as an argument -#
    webserver.content_send("<p></p><button onclick='la(\"&m_toggle_conf=1\");'>Toggle Conf</button>")
  end

  #- As we can add only one sensor method we will have to combine them besides all other sensor readings in one method -#
  def web_sensor()
  
    if webserver.has_arg("m_timeout")
        var timeout = webserver.arg("m_timeout")
        print ( "Light Timeout Received:"+timeout)
        lights_timeout = int(timeout)
        if lights_timeout == 0
            lights_timeout = 86400
            timeout_counter = lights_timeout
        end
        persist_save()
    end

    if webserver.has_arg("m_color_bar")
        var color = webserver.arg("m_color_bar")
        print ( "Color Argument Received:"+color)
        color_fan_speed_bar = int(color)
        update_status_leds(true)
        persist_save()
    end
    
    if webserver.has_arg("m_color_normal")
        var color = webserver.arg("m_color_normal")
        print ( "Color Argument Received:"+color)
        color_button_normal = int(color)
        update_status_leds(true)
        persist_save()
    end
    
    if webserver.has_arg("m_color_pressed")
        var color = webserver.arg("m_color_pressed")
        print ( "Color Argument Received:"+color)
        color_button_pressed = int(color)
        update_status_leds(true)
        persist_save()
    end
   
    if webserver.has_arg("m_speed_0")
      print("Speed 0 pressed")
      print ( webserver.arg("m_speed_0"))
      tasmota.cmd("fanspeed 0")
    end

    if webserver.has_arg("m_speed_1")
      print("Speed 1 pressed")
      print ( webserver.arg("m_speed_1"))
      tasmota.cmd("fanspeed 1")
    end

    if webserver.has_arg("m_speed_2")
      print("Speed 2 pressed")
      print ( webserver.arg("m_speed_2"))
      tasmota.cmd("fanspeed 2")
    end

    if webserver.has_arg("m_speed_3")
      print("Speed 3 pressed")
      print ( webserver.arg("m_speed_3"))
      tasmota.cmd("fanspeed 3")
    end

    if webserver.has_arg("m_speed_4")
      print("Speed 4 pressed")
      print ( webserver.arg("m_speed_4"))
      tasmota.cmd("fanspeed 4")
    end
    
    if webserver.has_arg("m_toggle_conf") # takes a string as argument name and returns a boolean

      # we can even call another function and use the value as a parameter
      var myValue = int(webserver.arg("m_toggle_conf")) # takes a string or integer(index of arguments) to get the value of the argument
      self.myOtherFunction(myValue)
    end

  end

  def every_second()
    update_status_leds(false)
    if ha_discovery_sent == false && mqtt_connected == true
      send_ha_discovery_message()
    end
    
    if bUpdate_fan_relay == true
      update_fan_relays()
      bUpdate_fan_relay = false
    end
    
  end

  def every_100ms()
    button_press_indicator(-1)
    if press_indication_counter > 0
      press_indication_counter = press_indication_counter - 1
    end
  end
  
end

def fanspeed(cmd, idx, payload, payload_json)
  bUpdate_fan_relay = false
  print("---payload---")
  print(payload)
  print("---payload json---")
  print(payload_json)

  print("---types---")
  print(type(payload))
  print(type(payload_json))

  # parse payload ==> fanspeed { "Speed":"4"} OR fanspeed { "Speed":4}
  if payload_json != nil && type(payload_json) == "string" && payload_json.find("Speed") != nil
    print("json condition true and speed is found.")
    set_speed = int(payload_json.find("Speed"))
  elif payload != nil
    if payload == "-"
      print("decrease speed")
      set_speed = set_speed - 1;
    elif payload == "+"
      print("increase speed")
      set_speed = set_speed + 1;
    else
      print("set speed")
      set_speed = int(payload);
    end
  end

  if set_speed < 0
    set_speed = 0
  end

  if set_speed > 4
    set_speed = 4
  end 

  print("---speed---")
  print(set_speed)
  
  update_status_leds(true)
  bUpdate_fan_relay = true
  update_status_leds(true)
  
  
  var msg = string.format("{ \"FanSpeed\":%d }",set_speed);
  print(msg)
  tasmota.resp_cmnd(msg)
end

tasmota.add_cmd('FanSpeed', fanspeed)
var d1 = MyButtonMethods()
tasmota.add_driver(d1)

def button_click(index)
  print("Button #",index+1," Clicked")

  if index == 2
    reset_button_press_indicator_counter()
    button_press_indicator(2)
    tasmota.cmd("fanspeed +")
  end

  if index == 1
    reset_button_press_indicator_counter()
    button_press_indicator(1)
    tasmota.cmd("fanspeed -")
  end

end

def on_system_boot()
  persist_load()
  update_status_leds(true)
  update_fan_relays()
end


tasmota.add_rule("button1#action=single", def (value) button_click(0) end )
tasmota.add_rule("button2#action=single", def (value) button_click(1) end )
tasmota.add_rule("button3#action=single", def (value) button_click(2) end )
tasmota.add_rule("button4#action=single", def (value) button_click(3) end )
tasmota.add_rule("System#Init", on_system_boot )
tasmota.add_rule("Mqtt#Connected", send_ha_discovery_message )
gpio.pin_mode(out1, gpio.OUTPUT)
gpio.pin_mode(out2, gpio.OUTPUT)
gpio.pin_mode(out3, gpio.OUTPUT)
gpio.digital_write(out1, gpio.LOW)
gpio.digital_write(out2, gpio.LOW)
gpio.digital_write(out3, gpio.LOW)

print("4_SPEED_FAN")
