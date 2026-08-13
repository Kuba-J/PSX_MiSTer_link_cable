#============================================================
# SPI SD and SDRAM DQM
#============================================================
set_location_assignment PIN_AE15 -to SD_SPI_CS
set_location_assignment PIN_AH8  -to SD_SPI_MISO
set_location_assignment PIN_AG8  -to SD_SPI_CLK
set_location_assignment PIN_U13  -to SD_SPI_MOSI
set_instance_assignment -name CURRENT_STRENGTH_NEW "MAXIMUM CURRENT" -to SD_SPI*
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SD_SPI*
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to SD_SPI*

set_location_assignment PIN_AG13 -to SDRAM_DQML
set_location_assignment PIN_AF13 -to SDRAM_DQMH
