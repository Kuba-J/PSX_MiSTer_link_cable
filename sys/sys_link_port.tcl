#============================================================
# LINK CABLE PORT
#============================================================
# Needs MISTER_LINK_CABLE=1 in the .qsf
# Remove any memory adapter from that connector before use.
set_location_assignment PIN_AG8  -to LINK_IO[0]
set_location_assignment PIN_AE15 -to LINK_IO[1]
set_location_assignment PIN_AG13 -to LINK_IO[2]
set_location_assignment PIN_U13  -to LINK_IO[3]
set_location_assignment PIN_AH8  -to LINK_IO[4]
set_location_assignment PIN_AF13 -to LINK_IO[5]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to LINK_IO[*]
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to LINK_IO[*]
set_instance_assignment -name CURRENT_STRENGTH_NEW "MAXIMUM CURRENT" -to LINK_IO[*]
