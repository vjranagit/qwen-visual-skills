ARTIFACT: Animated system diagram
AUDIENCE: Homeowners who know basic heating terms
CORE IDEA: A thermostat calls for heat and the boiler circulates hot water through two rooms before return.
PARTS: Thermostat; Boiler control; Burner; Heat exchanger; Circulator pump; Radiator 1; Radiator 2; Return pipe
GROUPS: Control: Thermostat, Boiler control; Heat source: Burner, Heat exchanger, Circulator pump; Rooms: Radiator 1, Radiator 2, Return pipe
RELATIONSHIPS:
- Thermostat -> Boiler control: calls for heat
- Boiler control -> Burner: ignites burner
- Burner -> Heat exchanger: heats water
- Heat exchanger -> Circulator pump: supplies hot water
- Circulator pump -> Radiator 1: feeds living room
- Circulator pump -> Radiator 2: feeds bedroom
- Radiator 1 -> Return pipe: returns cooled water
- Radiator 2 -> Return pipe: returns cooled water
- Return pipe -> Heat exchanger: sends water to reheat
LOOPS/FEEDBACK:
- Thermostat -> Boiler control -> Burner: room temperature demand starts the heat cycle
BRANCHES/FAILURES:
- Boiler control -> Burner: burner starts only when heat is requested
NUMBERS: Typical supply water: 70 °C; typical return water: 50 °C
EMPHASIS: Show the thermostat feedback and both room branches joining the return.
TAKEAWAY: The thermostat controls heat while the pump serves both rooms in parallel.
MAP-TO-TEMPLATE: PARTS -> lanes; GROUPS -> lanes; RELATIONSHIPS -> links; LOOPS/FEEDBACK -> links; BRANCHES/FAILURES -> links; NUMBERS -> scenes; TAKEAWAY -> scenes
