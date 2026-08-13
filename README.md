# [Playstation](https://en.wikipedia.org/wiki/PlayStation_(console)) for [MiSTer Platform](https://github.com/MiSTer-devel/Main_MiSTer/wiki)

## Hardware Requirements
SDRAM of any size is required.

## Features
* Savestates
* Option for core pause when OSD is open
* Optional manual Memory Card file loading (.MCD)
* CUE+BIN and CHD format support
* Multiple Disc Game support with automatic Lid open/close toggle
* Fast Boot (Skips BIOS)
* Dithering On/Off Toggle
* Bob or Weave Deinterlacing
* Texture Filtering
* 24 Bit rendering
* Widescreen modes
* Screen rotation by 180°
* 8 Mbyte mode(from dev units, mostly for homebrew) 
* Inputs: DualShock, Digital, Analog, Mouse, NeGcon, Wheel, Justifier and Guncon support.
* Native Input support through SNAC
* Old GPU (CXD8514Q)

## Bios
Rename your playstation bios file (e.g. `scph-1001.bin`/`ps-22a.bin` ) and place it in the `./games/PSX/` folder.

```
boot.rom  => US BIOS
boot1.rom => JP BIOS
boot2.rom => EU BIOS
```

You can also place a cd_bios.rom in the same directory as the CD or 1 directory above, to have it uses together with that CD. This can be used for games that depend on a special BIOS beyond usual US,EU,JP.

If you get a black screen with "ED" overlay in upper left corner, either your BIOS files are corrupt or missing or you have no SDRAM module installed.

## Region

Region settings (e.g. Clock, BIOS, CD check) are selected automatically when loading a CD. You can force a different Region in OSD.

## Memory Card

Games that are in their own folder will create it's own memory card in media/fat/saves/psx as <folder name>.sav 

One card can be mounted for each controller slot. Cards are in raw .mcd format. An empty formatted .mcd file is available for [download here](https://github.com/MiSTer-devel/PSX_MiSTer/raw/main/memcard/empty.mcd).

You need to save them either manually in the OSD or turn on autosave. Saving or loading a card will pause the core for a short time.

## CUE+BIN and CHD files

For proper operation, CUE/BIN and CHD game files should be placed in separate folders, with one folder per game. This allows the core to automatically create a dedicated virtual memory card for each game, preventing save data from being shared between different titles.

Additionally, when a new game is selected, the core automatically resets itself, ensuring the game starts correctly without requiring a manual restart.

## Multiple Disc Games

To swap discs while the game is running, all disc files for the game must be placed in the same folder. When a disc change is required, the core will automatically simulate opening and closing the disc lid. Example folder structure of a multi-disc game:

```
/media/fat/games/PSX/Final Fantasy VII (USA)/Final Fantasy VII (USA) (Disc 1).chd
/media/fat/games/PSX/Final Fantasy VII (USA)/Final Fantasy VII (USA) (Disc 2).chd
/media/fat/games/PSX/Final Fantasy VII (USA)/Final Fantasy VII (USA) (Disc 3).chd
```

## Video output

Core can output through HDMI and Analog out.

HDMI also offers a debugging framebuffer mode with support of full VRAM as 1024x512 pixel image(debug only)

Analog out from Direct Video is full 24Bit Color, but from Analog Board will only deliver 18 Bits of color.
You can activate the 24 Bit dithering option to remove color banding in FMVs without decreasing the image quality in 16 bit color ingame.
Do not use with HDMI or you get artifacts!

Fixed Hblank as well as Fixed Vblank can help delivering correct aspect rations and keeping the screen in sync with e.g. shaking animations.
Both also offer crop options for games that depend on CRT viewports to hide artifacts at the edge of the image.

Sync 480i for HDMI will make 480i content run with 240p timings, making it easier for HDMI devices to keep the sync when switching between both modes in games. 
Do not use with VGA/Analog out or you get artifacts!

## Libcrypt

Some games are secured with Libcrypt and will not work if it's not circumvented.

You can provide a .sbi file to do that.
If there is a .sbi file next to a .cue with the same name, it is loaded automatically when mounting the CD image.

## Unsafe options

The core offers various options to improve gameplay for some games, but those options cannot be considered stable through all games.
If you use one or more of these options, the core will warn you every time you start a game.

- 480i to 480p hack: 
Allows to render some games with full 480p resolution, removing interlacing artifacts. Only works for some full 3D 480i titles.

- Turbo: 
Increases CPU, DMA, Memory and GTE performance by ~10%(Low), ~20%(Medium) or 50%(High). Cheats cannot be used while Turbo is on and are disabled automatically.

- Pause when CD slow: 
CD data must be returned in a fixed time frame, otherwise the core will pause until the data has arrived. Disabling this will remove these pauses, but also risk that the game hangs up due to CD data being late.

- PAL 60Hz Hack:
Runs PAL games with 60Hz. PAL Games will often run faster with this hack on. Screen height is limited to 256 lines in this mode, so some games might be cropped.

- CD Fast Seek:
CD will seek the next sector in the minimal possible time. Decreases loading time of games, but some games depend on the long loading times and will crash.

- CD Speed:
Allows to run the CD drive with fixed higher speed to decrease loading times, but some games depend on the long loading times and will crash.
CD will automatically speed down to original speed for FMVs or CD audio playback and back to increased speed in loading areas.
The higher speed rates are more unstable and require proper storage to be usable with bin/cue files reaching higher performance than chd.

- Limit Max CD Speed:
Will hold back any new CD data until the game has processed the last data. 
Mostly useful to prevent CD data overrun when using higher speed modes, leading to overall faster loading times due to less read retries.

- RAM:
8 Mbyte option from development consoles. Only use for homebrew that requires it, otherwise there is a high chance of crashing games.

## Error messages

If there is a recognized problem, an overlay is displayed, showing which error has occured.
You can hide these messages with an OSD option, by default they are on.

List of Errors:
- E2     - CPU exception(only relevant if game shows issues)
- E3..E6 - GPU hangs (e.g. corrupt display list)
- E7     - CPU2VRAM with mask-AND enabled
- E8     - DMA chopping enabled
- E9     - GPU FIFO overflow
- EA     - SPU timeout
- EB     - DMA and CPU interlock error 
- EC     - DMA FIFO overflow
- ED     - CPU Data/Bus request timeout -> will also appear if the BIOS is not found or corrupt or no SDRAM module is installed
- EF     - BusWidth for SPU was set to 8 Bit (but should be 16 bit)

## Debug Options

The debug menu is intended for use by developers only. They don't really serve any purpose for regular users so it's best to leave them at their default setting as a lot of undesirable behavior could occur.

## Pad Options
The following pad types are emulated by the core and can be independently assigned to each port:
- DualShock:
  Switch Digital/Analog mode with mouse/touchpad click or L3+R3+Up/Down or mapable button 
- Digital  
  (ID 0x41) Ten button digital pad.
- Analog  
  (ID 0x73) Twinstick pad.  
- Mouse  
  (ID 0x12) Two button mouse.
- Off  
  Pad unplugged from port.
- GunCon  
  (ID 0x62) GunCon compatible lightgun.
- Justifier  
- NeGcon  
  (ID 0x23) NeGcon compatible racing pad.  
  Primarily developed for dual analog stick usage with the following mapping (genuine NeGcons  
   may work if usb adapters map steering to Left Analog and I/II to Right Analog):
   - Steering -> Left Analog (you can also use a paddle controller for this axis)
   - Circle -> Circle
   - Triangle -> Triangle
   - I -> Right Analog Up, Cross (100% pressed), R2 (100% pressed)
   - II -> Right Analog Down, Rectangle (100% pressed), L2 (100% pressed)
   - L -> L1 (100% pressed)
   - R -> R1
   
SNAC can be selected for each port and will support gamepads and memory cards on the corresponding slot.
When SNAC is enabled for a slot, the emulated gamepad/memory for this slot is disconnected.

## Link Cable

Two systems can be linked over SIO1 for the games that support it. Set one console to
`Link Cable -> Type A` and the other to `Type B`, so that TXD/RXD, DTR/DSR and RTS/CTS meet the
right way round. Both consoles need the same core and the same link settings.

The link runs on the SNAC port in the stock build. A second Quartus revision, `PSX_LinkCable`, adds
a six pin port on the expansion connector and a few extra options:

```
quartus_sh --flow compile PSX.qpf             stock core, link over SNAC
quartus_sh --flow compile PSX_LinkCable.qpf   adds the 6 pin port and the link options
```

The stock revision is unchanged by any of this. The link revision takes six pins that the framework
uses for the SPI SD card and the SDRAM DQM lines, so it is only for hardware where those are free.
It has no SPI SD card, no sync on green on IO boards without an MCP23009, and no SDRAM byte write
masks. Do not run it on a board that wires DQM to the memory.

| Link lane | Contact | Net | FPGA pin | Type A | Type B |
|:---------:|:-------:|:-----------:|:--------:|:----------:|:----------:|
| LINK_IO[0] | 9  | Arduino_IO6 | AG8  | TXD output | RXD input  |
| LINK_IO[1] | 11 | Arduino_IO9 | AE15 | DTR output | DSR input  |
| LINK_IO[2] | 3  | Arduino_IO0 | AG13 | RTS output | CTS input  |
| LINK_IO[3] | 8  | Arduino_IO5 | U13  | RXD input  | TXD output |
| LINK_IO[4] | 10 | Arduino_IO7 | AH8  | DSR input  | DTR output |
| LINK_IO[5] | 4  | Arduino_IO1 | AF13 | CTS input  | RTS output |

Grounds are on the contacts 12-14 and 17. Everything else must be left open: 1 (KEY0), 2 (KEY1),
5 (SDRAM_CKE), 6/7 (IO board I2C), 15/16 (HPS I2C) and 18/19 (+5V). An unmodified HDMI cable will
not work, its contacts 2/5/8/11 are pair shields bonded to the shell. Use two HDMI breakout boards
and a metre of CAT5e wired contact number to contact number, both ends the same:

| Pair   | Conductor    | Contact | Carries    |
|:------:|:------------:|:-------:|:----------:|
| Blue   | Blue         | 9  | LINK_IO[0] |
| Blue   | White/Blue   | 12 | GND        |
| Orange | Orange       | 8  | LINK_IO[3] |
| Orange | White/Orange | 14 | GND        |
| Green  | Green        | 11 | LINK_IO[1] |
| Green  | White/Green  | 10 | LINK_IO[4] |
| Brown  | Brown        | 3  | LINK_IO[2] |
| Brown  | White/Brown  | 4  | LINK_IO[5] |

Remove any memory adapter from that connector first, its memory and pull-downs cannot share these
signals.

## Link Cable options

These appear in the `PSX_LinkCable` revision only.

`Link Port` picks the SNAC port or the six pin port. It is greyed out while a pad is set to SNAC,
since the two cannot share the port.

`Link Cable Wiring` applies to SNAC only. Type B transmits DTR on USER_IO[6] and RTS on USER_IO[2]
while Type A expects DSR on USER_IO[4] and CTS on USER_IO[5], so `Crossover` needs a cable that
crosses 6 to 4 and 2 to 5. With a straight 1:1 cable that leaves DSR dead in one direction and both
CTS lines floating high, which looks like a link that connects and then drops once traffic starts,
because nothing throttles the sender. Select `Straight` for a 1:1 cable. The six pin port is
symmetric and always wants a 1:1 cable.

`Link Drive` selects how the three transmitted lanes are driven. Open drain only pulls low and
leaves the rising edge to the FPGA weak pull up of about 25k. The official IO board parallels that
with 10k (RN4/RN5) and is quick enough, but the expansion connector and the SuperStation dock have
no pull up network, so the edge takes microseconds and the faster games lose bytes. `Push-Pull`
drives those lanes actively and fixes it. Each lane has one driver, so it is safe as long as the
two consoles are set to different types.

`Link Speed` stretches the psx-spx bit period by 1 + n/8. Slower is not safer, at 1.875x games
start pausing while they wait for data. With `Push-Pull` the link runs clean at 1.000x, which is
unmodified psx-spx timing.

Known good on the six pin port, one metre of CAT5e: `Push-Pull` at 1.000x or 1.625x. Open drain
fails on that port at any speed.
## Controller mapping reference
NeGcon based controllers

| DualShock (for reference) | NeGcon | Volume | Pachinko |
|:-------------------------:|:------:|:------:|:--------:|
| D-PAD                     | D-PAD  |        |          |
| RX Axis                   | Twist  | Paddle | Handle   |
| RY Axis                   | I      |        |          |
| LX Axis                   | L1     |        |          |
| LY Axis                   | II     |        |          |
| O                         | A      | B      |          |
| △                         | B      |        |          |
| R1                        | R1     |        |          |
| Start                     | Start  | A      | Button   |

Lightgun
  
| DualShock (for reference) |   Guncon  | Justifier |
|:-------------------------:|:---------:|:---------:|
| O                         | Trigger   | Trigger   |
| Start                     | A (Left)  | Start     |
| X                         | B (Right) | Special   |
  
## Status

Many games working

--

CPU    : 90%
- exception for read in invalid instruction and data area missing

GPU    : 90%
- mask bits not implemented for cpu2vram -> nothing yet found that uses it
- vram2vram read/modify/write race condition when copying to same line

IRQ    : 90%
- irq_SIO missing because unused        

PAD    : 90%
- full configurable multitap missing

Memctrl: register stubs only

SIO    : register stubs only

Timer  : 90%
- accuracy for dotclock and gates timer not tested

GTE    : 90%
- CPU <-> GTE Transfer pipeline delay not fully correct

MDEC   : 90%
- timing slightly too fast (4996/5376)
 
CD     : 90%
- accurate CD access model for correct seek times should be added
- drive and controller logic should be seperated
