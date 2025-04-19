# Battle of Jutland – NetLogo Simulation

This project models the **Battle of Jutland** using [NetLogo](https://ccl.northwestern.edu/netlogo/).
The simulation starts at 7:15 UTC simulating the second crossing of the T. The goal of the simulation
was to investigate the following research question:

> **Research Question:**  
> Should Jellicoe have ordered the Grand fleet through the covering torpedo salvo to 
> remain in contact with the High Seas Fleet at dusk on May 31st?

Several variables, including the `German Disengage Signal Tick`, `British Delay Tick`, and
`British Signal` can be modified to examine changes in the model. Ultimately, this model confirms
the hypothesis that:

> **Hypothesis:**  
> Pursuing the German High Seas Fleet through the covering torpedo salvo would have resulted in a
> route of the German Fleet - a minor increase in British material losses but a dramatic increase
> in German material losses. 

---

## Project Overview

- **NetLogo Model**: A simulation of British and German fleet actions based on historical maneuvers and signal interpretation.
- **Input Data**: `.csv` files based on historical data specifying run configurations and fleet variables.
- **Python Plotting**: Post-simulation visualizations to evaluate key metrics like engagement outcomes, signal responses, and fleet behaviors.

---

## Directory Structure

```
BattleOfJutland/
│
├── input_data.csv                # Example CSV input file for fleet simulation
├── run_config.csv                # Run parameters or setup instructions
│
├── jutlandMain.nlogo             # The NetLogo model file
|
├── simulation_inputs/            # Input tables of data for simulation
│   ├── battleShipDamage.csv      # Input variables to initialize the damage model in the simulation
│   ├── orderOfBattle.csv         # Initialization of ship parameters based on historical data
│   ├── smoke.csv                 # Initialization of smoke variables
│
├── result_plotting/              # Python utilities for post-simulation analysis
│   ├── plot_generator.py         # Script to generate visual plots from output data
│   ├── make_venv.sh              # Shell script to set up a Python virtual environment
│   ├── requirements.txt          # Python dependencies for plotting
│
└── README.md                     # This file!!

```

---

## 📊 Plotting Results with Python

1. Open a terminal and navigate to the `result_plotting/` directory:

   ```bash
   cd result_plotting/
   ```

2. Set up a virtual environment and install dependencies:

   ```bash
   sh ./make_venv.sh
   ```

3. Activate the virtual environment:

   ```bash
   source msmg_venv/bin/activate
   ```

4. Run the plot generator:

   ```bash
   python3 plot_generator.py
   ```


Results will be generated in a new `plots` directory organized by plot types

---

## Credits

Developed by:
- Riley Patterson
- Emily Howell
- Sung Joon Park
- Alexandar Chee