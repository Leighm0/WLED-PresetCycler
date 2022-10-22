# WLED Preset Cycler

Control4 Driver for WLED Controller Preset Cycling and Brightness/On/Off Control

### Quick Start:
		
#### WLED Controller Setup:
1. Config > WIFI Setup:
	- Set Static IP Address
2. Config > Sync Interfaces:
	- Set UDP Port (if you have multiple WLED, increment by 1 per WLED controller to not use same UDP port)
	- Tick "Send notifications on direct change"
	- Tick "Send notifications twice" (Optional, but can help incase the first UDP broadcast doesnt come through)
	- Untick Receive -> Brightness, Color, Effects and everything else in WLED Broadcast section.
3. Main Page:
	- Configure your Presets starting with ID '1' (10 is the max for now in this driver).
	- Add an additional Preset and set it as ID '99' and set it up with a default "ON" mode settings (i.e. All White)
	- NOTE: Preset '99' will be used for the C4 Lightv2 Proxy (under Lighting in UI) for On / Brightness without using the Preset Button UI.
	  
#### Composer Driver Properties:
1. Enter the WLED IP address
2. Set UDP Multicast Port (if different)
3. Set the total presets you setup in WLED Controller Setup Step 3 (Maximum: 10)
4. Under Room Navigators:
	- In "Lights": You should see the WLED Driver, this is for Brightness/On/Off control.
	- In "Comfort, Listen, Security or Watch": Unhide the "WLED Presets" for the Preset Cycler UI button.
5. Refresh Navigators

### Release Notes:

- Version 1: Initial Release
- Version 2: New Icons for Preset Cycling
- Version 3: Icon for Driver and LUA/XML cleanup
- Version 4: Added Custom Preset programming action for selecting WLED Presets outside of the 1-10 UI Button Cycle range.
- Version 5: Added reduced ALS support (Full ALS support may be added in the future)
