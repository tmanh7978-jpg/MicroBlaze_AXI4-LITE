# 2026-10-31T00:48:36.378833800
import vitis

client = vitis.create_client()
client.set_workspace(path="vitis")

platform = client.get_component(name="microblaze_led_platform")
status = platform.update_hw(hw_design = "$COMPONENT_LOCATION/../../soc/Microblaze_Controller_wrapper.xsa")

status = platform.build()

status = platform.update_hw(hw_design = "$COMPONENT_LOCATION/../../soc/Microblaze_Controller_wrapper.xsa")

status = platform.update_hw(hw_design = "$COMPONENT_LOCATION/../../soc/Microblaze_Controller_wrapper.xsa")

status = platform.build()

comp = client.get_component(name="microblaze_led_test")
comp.build()

vitis.dispose()

