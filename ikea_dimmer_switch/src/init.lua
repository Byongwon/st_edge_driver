-- IKEA Dimmer Switch ver.0.0.1
-- Copyright 2021 Abraham Kwon (hospital82)
-- Reference from iquix
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

local capabilities = require "st.capabilities"
local ZigbeeDriver = require "st.zigbee"
local defaults = require "st.zigbee.defaults"
local device_management = require "st.zigbee.device_management"
local clusters = require "st.zigbee.zcl.clusters"

local compPush = {"button1", "button2"}
local compHold = {"button2", "button1"}

local pushed_handler = function(driver, device, zb_rx)
	local rx = zb_rx.body.zcl_header
	local button = string.format("%s", rx.cmd.value)
	local buttonComp = string.format("%s", rx.cmd.value +1)

	local ev = capabilities.button.button.pushed()
	ev.state_change = true
	device.profile.components[compPush[tonumber(buttonComp)]]:emit_event(ev)
	device:emit_event(ev)
end

local hold_handler = function(driver, device, zb_rx)
	local rx = zb_rx.body.zcl_body
	local button = string.format("%s", rx.move_mode.value)
	local buttonComp = string.format("%s", rx.move_mode.value +1)

	local ev = capabilities.button.button.held()
	ev.state_change = true
	device.profile.components[compHold[tonumber(buttonComp)]]:emit_event(ev)
	device:emit_event(ev)
end

local device_added = function(driver, device)
	device:emit_event(capabilities.button.supportedButtonValues({"pushed", "held"}))
	device:emit_event(capabilities.button.button.pushed())
	for i,v in ipairs(compPush) do
		device.profile.components[v]:emit_event(capabilities.button.supportedButtonValues({"pushed", "held"}))
		device.profile.components[v]:emit_event(capabilities.button.button.pushed())
	end
end

local do_configure = function(self, device)
	device:configure()
	device:send(device_management.build_bind_request(device, 0xFC00, device.driver.environment_info.hub_zigbee_eui))
	device:send(clusters.PowerConfiguration.attributes.BatteryPercentageRemaining:read(device))
end

local ikea_dimmer_driver = {
	supported_capabilities = {
	  capabilities.button,
	  capabilities.battery,
	},
	zigbee_handlers = {
		cluster = {
			[0x0006] = {
				[0x01] = pushed_handler,
				[0x00] = pushed_handler
			},
			[0x0008] = {
				[0x01] = hold_handler,
				[0x05] = hold_handler
				}
			}
		},
	lifecycle_handlers = {
		added = device_added,
		doConfigure = do_configure
	},
  }

  defaults.register_for_default_handlers(ikea_dimmer_driver, ikea_dimmer_driver.supported_capabilities)
  local zigbee_driver = ZigbeeDriver("ikea_dimmer_switch", ikea_dimmer_driver)
  zigbee_driver:run()