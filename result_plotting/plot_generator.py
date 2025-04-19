import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import seaborn
import os
import glob
from typing import TextIO

INPUT_TABLE_FILE_BASE = os.path.abspath("jutlandMain Monte Carlo-table-*.csv")
OUTPUT_PATH = os.path.join(os.getcwd(), "plots")

TIME_PLOTS = os.path.join(OUTPUT_PATH, "time_plots")
BOX_PLOTS_FLEET = os.path.join(OUTPUT_PATH, "box_plots_signal")
BOX_PLOTS_SIGNAL = os.path.join(OUTPUT_PATH, "box_plots_fleet")
HEAT_MAPS = os.path.join(OUTPUT_PATH, "heat_maps")
STD_DIR = os.path.join(OUTPUT_PATH, "standard_deviation_maps")
CORR_PLOTS = os.path.join(OUTPUT_PATH, "correlation_plots")

SIM_END_TIC = 100

def clean_plots(directory: str = OUTPUT_PATH):
    # Clean up any plots previously generated
    jpg_files = glob.glob(f"{directory}/**/*.jpg", recursive=True)
    for jpg in jpg_files:
        os.remove(os.path.join(directory, jpg))

# Read in data from all data files
csv_file_names = glob.glob(INPUT_TABLE_FILE_BASE)

df_list = []
run_num_offset = 0
for idx, file_name in enumerate(sorted(csv_file_names)):
    # read in data
    df_temp = pd.read_csv(file_name, skiprows=6)
    
    # Offset the run_id so they are still unique
    df_temp["[run number]"] += run_num_offset
    run_num_offset = df_temp["[run number]"].max() + 1

    # store data to list to be combined together later
    df_list.append(df_temp)
df = pd.concat(df_list, ignore_index=True)

if len(df.columns) == 15:
    df.columns = ['Run_id', 'Debug_Flag', 'British_Delay', 'German_Disengage_Delay', 'British_Signal',
                  'Simulation_Tick', 'Simulation_Time', 
                  'British_Ship_Count', 'British_Fleet_Health', 'British_Fleet_Damage_This_Tick', 'British_Gunnery_Count', 
                  'German_Ship_Count', 'German_Fleet_Health', 'German_Fleet_Damage_This_Tick', 'German_Gunnery_Count']

elif len(df.columns) == 23:
    df.columns = ['Run_id', 'Debug_Flag', 'British_Delay', 'German_Disengage_Delay', 'British_Signal',
                  'Simulation_Tick', 'Simulation_Time', 
                  
                  'British_Ship_Count',
                  'British_Ship_Count-destroyer', 'British_Ship_Count-battlecruiser',
                  'British_Ship_Count-cruiser','British_Ship_Count-battleship',
                  'British_Fleet_Health', 'British_Fleet_Damage_This_Tick', 'British_Gunnery_Count',
                  
                  'German_Ship_Count',
                  'German_Ship_Count-destroyer', 'German_Ship_Count-battlecruiser',
                  'German_Ship_Count-cruiser','German_Ship_Count-battleship',
                  'German_Fleet_Health', 'German_Fleet_Damage_This_Tick', 'German_Gunnery_Count']
    
elif len(df.columns) == 25:
    df.columns = ['Run_id', 'Debug_Flag', "cosmetics", "smoke-switch",
                  'British_Delay', 'German_Disengage_Delay', 'British_Signal',
                  'Simulation_Tick', 'Simulation_Time', 
                  
                  'British_Ship_Count',
                  'British_Ship_Count-destroyer', 'British_Ship_Count-battlecruiser',
                  'British_Ship_Count-cruiser','British_Ship_Count-battleship',
                  'British_Fleet_Health', 'British_Fleet_Damage_This_Tick', 'British_Gunnery_Count',
                  
                  'German_Ship_Count',
                  'German_Ship_Count-destroyer', 'German_Ship_Count-battlecruiser',
                  'German_Ship_Count-cruiser','German_Ship_Count-battleship',
                  'German_Fleet_Health', 'German_Fleet_Damage_This_Tick', 'German_Gunnery_Count']

else:
    raise ValueError("Unsupported number of MC variables. Please specify table format and retry.")

# df = df[df["smoke-switch"] == True]
df["British_Damage_Cumulative"] = df.groupby('Run_id')['British_Fleet_Damage_This_Tick'].cumsum()
df["German_Damage_Cumulative"] = df.groupby('Run_id')['German_Fleet_Damage_This_Tick'].cumsum()

def get_min_max(plot_var, fleet="Both", data_frame=df):
    # Filter for the relevant columns and flatten the data
    british_data = data_frame[f'British_{plot_var}'].values
    german_data = data_frame[f'German_{plot_var}'].values

    if fleet.lower() == "british":
        return british_data.min(), british_data.max()
    
    if fleet.lower() == "german":
        return german_data.min(), german_data.max()
    
    # Find the global min and max across both British and German ship counts
    global_min = min(british_data.min(), german_data.min())
    global_max = max(british_data.max(), german_data.max())
    
    return global_min, global_max


########################
### Print Statistics ###
########################
def print_stats():
    vars = ['British_Ship_Count', 'British_Fleet_Health', 'British_Gunnery_Count', 
                 "British_Damage_Cumulative",
                 'British_Ship_Count-destroyer', 'British_Ship_Count-battlecruiser',
                 'British_Ship_Count-cruiser','British_Ship_Count-battleship',
                 'German_Ship_Count', 'German_Fleet_Health', 'German_Gunnery_Count', 
                 "German_Damage_Cumulative",
                 'German_Ship_Count-destroyer', 'German_Ship_Count-battlecruiser',
                 'German_Ship_Count-cruiser','German_Ship_Count-battleship']
    
    with open(os.path.join(OUTPUT_PATH, "stats.txt"), "w") as f:
        for v in vars:
            print_var_mean(v, f)
    
def print_var_mean(var: str, file: TextIO = None):
    british_engage = df[df['British_Signal']=='Engage'].groupby(['Run_id']).last()
    british_dont_engage = df[df['British_Signal']=='Disengage'].groupby(['Run_id']).last()
    
    print(f'''
--- {var} ---
\tEngage: \t{british_engage[var].mean()} +/- {british_engage[var].std()}
\t   min: \t{british_engage[var].min()}
\t   max: \t{british_engage[var].max()}
\tDisengage: \t{british_dont_engage[var].mean()} +/- {british_dont_engage[var].std()}
\t   min: \t{british_dont_engage[var].min()}
\t   max: \t{british_dont_engage[var].max()}
\tPercentage Decrease: \t{((british_dont_engage[var].mean()-british_engage[var].mean())/british_dont_engage[var].mean())*100}
''', file=file)


######################################
### Plotting Sim Outputs over Time ###
######################################
def plot_all_over_time():
    clean_plots(TIME_PLOTS)

    group_vars = ["British_Delay", "German_Disengage_Delay"]
    british_signals = ["Disengage", "Engage"]
    plot_vars = ['British_Ship_Count', 'British_Fleet_Health', 'British_Gunnery_Count', 
                 "British_Fleet_Damage_This_Tick", "British_Damage_Cumulative",
                 'British_Ship_Count-destroyer', 'British_Ship_Count-battlecruiser',
                 'British_Ship_Count-cruiser','British_Ship_Count-battleship',
                 'German_Ship_Count', 'German_Fleet_Health', 'German_Gunnery_Count', 
                 "German_Fleet_Damage_This_Tick", "German_Damage_Cumulative",
                 'German_Ship_Count-destroyer', 'German_Ship_Count-battlecruiser',
                 'German_Ship_Count-cruiser','German_Ship_Count-battleship']
    
    for g_var in group_vars:
        for p_var in plot_vars:
            for b_sig in british_signals:
                plot_over_time(g_var, p_var, b_sig)

def plot_over_time(group_var: str, plot_var: str, british_signal: str, x_axis: str = "", y_axis: str = ""):
    os.makedirs(TIME_PLOTS, exist_ok=True)

    plt.figure(figsize=(12, 6))
    df_brit_avg = df.groupby([group_var, 'British_Signal', 'Simulation_Tick']).agg(
        avg_plot_var=(plot_var, 'mean'),
    ).reset_index()

    ymin = df_brit_avg["avg_plot_var"][df_brit_avg['Simulation_Tick'] <= SIM_END_TIC].min()
    ymax = df_brit_avg["avg_plot_var"][df_brit_avg['Simulation_Tick'] <= SIM_END_TIC].max()

    for g_var in df_brit_avg[group_var].unique():
        group_data = df_brit_avg[(df_brit_avg[group_var] == g_var) & 
                                (df_brit_avg['British_Signal'] == british_signal) &
                                (df_brit_avg['Simulation_Tick'] <= SIM_END_TIC)]
        plt.plot(group_data['Simulation_Tick'], group_data["avg_plot_var"], label=f'{group_var} {g_var}')

    if len(x_axis) == 0: x_axis = 'Simulation Tick'
    if len(y_axis) == 0: y_axis = f"Average {plot_var.replace('_', ' ').title()}"
    plt.title(f'{y_axis} vs. {x_axis} (British Signal = {british_signal})')
    plt.xlabel(x_axis)
    plt.xlim(0, SIM_END_TIC)
    plt.ylabel(y_axis)
    plt.ylim(ymin, ymax)
    plt.legend(title=group_var.replace('_', ' ').title(), loc='upper left', bbox_to_anchor=(1, 1))
    plt.grid(True)
    plt.tight_layout()
    plt.savefig(os.path.join(TIME_PLOTS, f"{group_var}_vs_{plot_var}-{british_signal}.jpg"), format="jpg")
    plt.close()


#####################################
### Box Plots of Output Variables ###
#####################################
def plot_all_box_plots():
    clean_plots(BOX_PLOTS_FLEET)
    clean_plots(BOX_PLOTS_SIGNAL)

    group_vars = ["British_Delay", "German_Disengage_Delay"]
    plot_vars = ['Ship_Count', 'Fleet_Health', 'Gunnery_Count', "Damage_Cumulative",
                 'Ship_Count-destroyer', 'Ship_Count-battlecruiser',
                 'Ship_Count-cruiser','Ship_Count-battleship']
    british_signals = ["Disengage", "Engage"]
    fleets = ["British", "German"]

    for g_var in group_vars:
        for p_var in plot_vars:
            for b_sig, f_leet in zip(british_signals, fleets):
                box_plot_comp_fleet(g_var, p_var, b_sig)
                box_plot_comp_signal(g_var, p_var, f_leet)

def box_plot_comp_fleet(group_var: str, plot_var: str, british_signal: str, x_axis: str = "", y_axis: str = ""):
    os.makedirs(BOX_PLOTS_FLEET, exist_ok=True)

    y_min, y_max = get_min_max(plot_var)
    filtered_df = df[df['British_Signal'] == british_signal]
    box_plot_data = pd.DataFrame({
        f'British_{plot_var}': filtered_df.groupby('Run_id')[f'British_{plot_var}'].last(),
        f'German_{plot_var}': filtered_df.groupby('Run_id')[f'German_{plot_var}'].last(),
        group_var: filtered_df.groupby('Run_id')[group_var].first(),
    })

    plt.figure(figsize=(10, 6))
    seaborn.boxplot(x=group_var, y=f'British_{plot_var}', data=box_plot_data, color='pink', label='British Fleet')
    seaborn.boxplot(x=group_var, y=f'German_{plot_var}', data=box_plot_data, color='#99FF99', label='German Fleet')

    if len(x_axis) == 0: x_axis = group_var.replace("_", " ").title()
    if len(y_axis) == 0: y_axis = f'Final {plot_var.replace("_", " ").title()} Count'
    plt.xlabel(x_axis)
    plt.ylabel(y_axis)
    plt.title(f'{y_axis} vs. {x_axis} (British Signal = {british_signal})')
    plt.xticks(rotation=45)
    plt.ylim(np.floor(y_min * 0.9), np.floor(y_max * 1.1))
    plt.legend(title="Fleet", loc='upper left', bbox_to_anchor=(1, 1))
    plt.grid(True)
    plt.tight_layout()
    plt.savefig(os.path.join(BOX_PLOTS_FLEET, f"{group_var}_vs_{plot_var}_boxplot-{british_signal}.jpg"), format="jpg")
    plt.close()

def box_plot_comp_signal(group_var: str, plot_var: str, fleet: str, x_axis: str = "", y_axis: str = ""):
    os.makedirs(BOX_PLOTS_SIGNAL, exist_ok=True)

    df_disengage = df[df['British_Signal'] == 'Disengage']
    df_engage = df[df['British_Signal'] == 'Engage']
    box_plot_data = pd.DataFrame({
        "Disengage": df_disengage.groupby('Run_id')[f'{fleet}_{plot_var}'].last(),
        "Engage": df_engage.groupby('Run_id')[f'{fleet}_{plot_var}'].last(),
        group_var: df.groupby('Run_id')[group_var].first(),
    })

    plt.figure(figsize=(10, 6))
    seaborn.boxplot(x=group_var, y=f'Disengage', data=box_plot_data, color='orange', label='British Signal = Disengage', showfliers=False)
    seaborn.boxplot(x=group_var, y=f'Engage', data=box_plot_data, color='cyan', label='British Signal = Engage', showfliers=False)

    if len(x_axis) == 0: x_axis = group_var.replace("_", " ").title()
    if len(y_axis) == 0: y_axis = f'Final {plot_var.replace("_", " ").title()} Count'
    plt.xlabel(x_axis)
    plt.ylabel(y_axis)
    plt.title(f'{y_axis} vs. {x_axis} (Fleet = {fleet})')
    plt.xticks(rotation=45)
    plt.legend(title="Fleet", loc='upper left', bbox_to_anchor=(1, 1))
    plt.grid(True)
    plt.tight_layout()
    plt.savefig(os.path.join(BOX_PLOTS_SIGNAL, f"{group_var}_vs_{plot_var}_boxplot-{fleet}.jpg"), format="jpg")
    plt.close()


####################################
### Heat Maps of Input Variables ###
####################################
def plot_all_heat_maps():
    clean_plots(HEAT_MAPS)
    british_signals = ["Disengage", "Engage"]
    plot_vars = ['British_Ship_Count', 'British_Fleet_Health', 'British_Gunnery_Count', "British_Damage_Cumulative",
              'German_Ship_Count', 'German_Fleet_Health', 'German_Gunnery_Count', "German_Damage_Cumulative"]
    
    for p_var in plot_vars:
        for b_sig in british_signals:
            heat_map(p_var, b_sig)

def heat_map(plot_var: str, british_signal: str):
    os.makedirs(HEAT_MAPS, exist_ok=True)
    fleet, var_name = plot_var.split("_", 1)
    
    # Create a pivot table for final British ship count based on British_Delay and German_Disengage
    
    final_data = df.groupby(['Run_id']).last()
    var_min, var_max = get_min_max(var_name, fleet, data_frame=final_data)

    filtered_df = df[df['British_Signal'] == british_signal]
    final_data = filtered_df.groupby('Run_id').last()
    pivot_table = final_data.pivot_table(
        index='British_Delay', 
        columns='German_Disengage_Delay', 
        values=plot_var, 
        aggfunc='mean'
    )

    # Plot a heatmap
    plt.figure(figsize=(10, 6))
    seaborn.heatmap(pivot_table, annot=True, cmap='inferno', fmt='.1f', cbar_kws={'label': f'Average Final {plot_var.replace("_", " ").title()}'}, vmin=var_min, vmax=var_max)
    plt.title(f'Average Final {plot_var.replace("_", " ").title()} vs. British Delay and German Disengage (British Signal = {british_signal})')
    plt.xlabel('German Disengage')
    plt.ylabel('British Delay')
    plt.savefig(os.path.join(HEAT_MAPS, f"{plot_var}_heatmap-{british_signal}.jpg"), format="jpg")
    plt.close()


###########################
### Standard Deviations ###
###########################
def plot_all_standard_deviations():
    clean_plots(STD_DIR)
    british_signals = ["Disengage", "Engage"]
    plot_vars = ['British_Ship_Count', 'British_Fleet_Health', 'British_Gunnery_Count', "British_Damage_Cumulative",
              'German_Ship_Count', 'German_Fleet_Health', 'German_Gunnery_Count', "German_Damage_Cumulative"]
    
    for p_var in plot_vars:
        for b_sig in british_signals:
            standard_deviation_map(p_var, b_sig)

def standard_deviation_map(plot_var: str, british_signal: str):
    os.makedirs(STD_DIR, exist_ok=True)
    fleet, var_name = plot_var.split("_", 1)
    
    # Create a pivot table for final British ship count based on British_Delay and German_Disengage
    
    final_data = df.groupby(['Run_id']).last()
    # var_min, var_max = get_min_max(var_name, fleet, data_frame=final_data)

    filtered_df = df[(df['British_Signal'] == british_signal) & (df["smoke-switch"] == True)]
    final_data = filtered_df.groupby(['Run_id','British_Delay','German_Disengage_Delay']).last()
    pivot_table = final_data.pivot_table(
        index='British_Delay', 
        columns='German_Disengage_Delay', 
        values=plot_var,
        aggfunc='std'
    )

    # Plot a heatmap
    plt.figure(figsize=(10, 6))
    seaborn.heatmap(pivot_table, annot=True, cmap='inferno', fmt='.1f', cbar_kws={'label': 'Average British Ship Count'})
    plt.title(f'Average Final {plot_var.replace("_", " ").title()} vs. British Delay and German Disengage (British Signal = {british_signal})')
    plt.xlabel('German Disengage')
    plt.ylabel('British Delay')
    plt.savefig(os.path.join(STD_DIR, f"{plot_var}_std-{british_signal}.jpg"), format="jpg")
    plt.close()


#####################################
### Correlation plot of variables ###
#####################################
def plot_all_correlation_plots():
    clean_plots(CORR_PLOTS)
    fleets = ["british", "german", "british_german"]
    levels = ["basic", "adv"]

    for f in fleets:
        for l in levels:
            correlation_plot(f"{f}_{l}")

def correlation_plot(var_subset: str = "british_german_adv"):
    os.makedirs(CORR_PLOTS, exist_ok=True)

    # Select relevant columns for correlation analysis
    df['British_Signal_Numeric'] = df['British_Signal'].map({'Engage': 1, 'Disengage': 0})
    
    # Determine what variables we should include in the plot
    filter_vars = ['British_Delay', 'German_Disengage_Delay', 'British_Signal_Numeric']
    if ("british" in var_subset):
        filter_vars += ['British_Ship_Count', 'British_Fleet_Health', 
                        'British_Fleet_Damage_This_Tick', 'British_Gunnery_Count']
    if ("british" in var_subset and "adv" in var_subset):
        filter_vars += ['British_Ship_Count-destroyer', 'British_Ship_Count-battlecruiser', 
                        'British_Ship_Count-cruiser','British_Ship_Count-battleship',
                        'British_Fleet_Damage_This_Tick']
    if ("german" in var_subset):
        filter_vars += ['German_Ship_Count', 'German_Fleet_Health', 
                        'German_Fleet_Damage_This_Tick', 'German_Gunnery_Count']
    if ("german" in var_subset and "adv" in var_subset):
        filter_vars += ['German_Ship_Count-destroyer', 'German_Ship_Count-battlecruiser', 
                        'German_Ship_Count-cruiser','German_Ship_Count-battleship',
                        'German_Fleet_Damage_This_Tick']
    
    correlation_data = df[filter_vars]

    # Calculate correlation matrix
    corr_matrix = correlation_data.corr()

    # Plot the correlation matrix
    plt.figure(figsize=(14, 12))
    seaborn.heatmap(corr_matrix, annot=True, cmap='YlGnBu', fmt='.2f', annot_kws={"size": 10}, cbar_kws={'label': 'Correlation'})
    plt.title('Correlation Matrix for Input Parameters and Ship Counts')
    plt.xticks(rotation=45, fontsize=10)
    plt.yticks(rotation=45, fontsize=10)
    plt.xticks([i for i in range(len(corr_matrix.columns))], [col.replace('_', ' ').title() for col in corr_matrix.columns])
    plt.yticks([i+1 for i in range(len(corr_matrix.index))], [idx.replace('_', ' ').title() for idx in corr_matrix.index])
    plt.tight_layout()
    # plt.subplots_adjust(left=0.2, right=0.9, top=0.9, bottom=0.2)
    plt.savefig(os.path.join(CORR_PLOTS, f"corelation_matrix-{var_subset}.jpg"), format="jpg")
    plt.close()


if __name__ == "__main__":
    print_stats()
    plot_all_over_time()
    plot_all_box_plots()
    plot_all_heat_maps()
    plot_all_standard_deviations()
    plot_all_correlation_plots()