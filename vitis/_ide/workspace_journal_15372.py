# 2026-10-27T02:00:18.171975400
import vitis

client = vitis.create_client()
client.set_workspace(path="D:/vitis")

advanced_options = client.create_advanced_options_dict(dt_overlay="0")

platform = client.create_platform_component(name = "microblaze_led_platform",hw_design = "D:\soc\Microblaze_Controller_wrapper.xsa",os = "standalone",cpu = "microblaze_0",domain_name = "standalone_microblaze_0",generate_dtb = False,advanced_options = advanced_options,compiler = "gcc")

platform = client.get_component(name="microblaze_led_platform")
status = platform.build()

comp = client.create_app_component(name="microblaze_led_test",platform = "$COMPONENT_LOCATION/../microblaze_led_platform/export/microblaze_led_platform/microblaze_led_platform.xpfm",domain = "standalone_microblaze_0")

comp = client.get_component(name="microblaze_led_test")
comp.build()

comp.build()

vitis.dispose()

vitis.dispose()

