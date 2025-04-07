import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import seaborn
import os
import glob

INPUT_TABLE_FILE = os.path.abspath("jutlandMain Monte Carlo-table.csv")
OUTPUT_PATH = os.path.join(os.getcwd(), "plots")

TIME_PLOTS = os.path.join(OUTPUT_PATH, "time_plots")
BOX_PLOTS = os.path.join(OUTPUT_PATH, "box_plots")
HEAT_MAPS = os.path.join(OUTPUT_PATH, "heat_maps")

# Use glob to find all .jpg files in the current directory
jpg_files = glob.glob('*.jpg', root_dir=OUTPUT_PATH)

# Loop through and remove each file
for jpg in jpg_files:
    os.remove(os.path.join(OUTPUT_PATH, jpg))

df = pd.read_csv(INPUT_TABLE_FILE, skiprows=6)
df.columns = ['Run_id', 'Debug_Flag', 'British_Delay', 'German_Disengage_Delay', 'British_Signal', 'Simulation_Tick', 
              'Simulation_Time', 'British_Ship_Count', 'British_Fleet_Health', 'British_Fleet_Damage_This_Tick', 'British_Gunnery_Count', 
              'German_Ship_Count', 'German_Fleet_Health', 'German_Fleet_Damage_This_Tick', 'German_Gunnery_Count']


######################################
### Plotting Sim Outputs over Time ###
######################################
def plot_all_over_time():
    group_vars = ["British_Delay", "German_Disengage_Delay"]
    british_signals = ["Disengage", "Engage"]
    plot_vars = ['British_Ship_Count', 'British_Fleet_Health', 'British_Gunnery_Count', 
              'German_Ship_Count', 'German_Fleet_Health', 'German_Gunnery_Count']
    
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

    for g_var in df_brit_avg[group_var].unique():
        group_data = df_brit_avg[(df_brit_avg[group_var] == g_var) & 
                                (df_brit_avg['British_Signal'] == british_signal) &
                                (df_brit_avg['Simulation_Tick'] < 35)]
        plt.plot(group_data['Simulation_Tick'], group_data["avg_plot_var"], label=f'{group_var} {g_var}')

    if len(x_axis) == 0: x_axis = 'Simulation Tick'
    if len(y_axis) == 0: y_axis = f"Average {plot_var.replace('_', ' ').title()}"
    plt.title(f'{y_axis} vs. {x_axis} (British Signal = {british_signal})')
    plt.xlabel(x_axis)
    plt.ylabel(y_axis)
    plt.legend(title=group_var.replace('_', ' ').title(), loc='upper left', bbox_to_anchor=(1, 1))
    plt.grid(True)
    plt.tight_layout()
    plt.savefig(os.path.join(TIME_PLOTS, f"{group_var}_vs_{plot_var}-{british_signal}.jpg"), format="jpg")
    plt.close()


#####################################
### Box Plots of Output Variables ###
#####################################
def plot_all_box_plots():
    group_vars = ["British_Delay", "German_Disengage_Delay"]
    british_signals = ["Disengage", "Engage"]
    plot_vars = ['Ship_Count', 'Fleet_Health', 'Gunnery_Count']
    
    for g_var in group_vars:
        for p_var in plot_vars:
            for b_sig in british_signals:
                box_plot(g_var, p_var, b_sig)

def get_min_max(plot_var, fleet="Both", data_frame=df):
    # Filter for the relevant columns and flatten the data
    british_ship_count = data_frame[f'British_{plot_var}'].values
    german_ship_count = data_frame[f'German_{plot_var}'].values

    if fleet.lower() == "british":
        return british_ship_count.min(), british_ship_count.max()
    
    if fleet.lower() == "german":
        return german_ship_count.min(), german_ship_count.max()
    
    # Find the global min and max across both British and German ship counts
    global_min = min(british_ship_count.min(), german_ship_count.min())
    global_max = max(british_ship_count.max(), german_ship_count.max())
    
    return global_min, global_max

def box_plot(group_var: str, plot_var: str, british_signal: str, x_axis: str = "", y_axis: str = ""):
    os.makedirs(BOX_PLOTS, exist_ok=True)

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
    plt.title(f'Distribution of {y_axis} vs. {x_axis}')
    plt.xticks(rotation=45)
    plt.ylim(np.floor(y_min * 0.9), np.floor(y_max * 1.1))
    plt.legend(title="Fleet", loc='upper left', bbox_to_anchor=(1, 1))
    plt.grid(True)
    plt.tight_layout()
    plt.savefig(os.path.join(BOX_PLOTS, f"{group_var}_vs_{plot_var}_boxplot-{british_signal}.jpg"), format="jpg")
    plt.close()


####################################
### Heat Maps of Input Variables ###
####################################
def plot_all_heat_maps():
    british_signals = ["Disengage", "Engage"]
    plot_vars = ['British_Ship_Count', 'British_Fleet_Health', 'British_Gunnery_Count', 
              'German_Ship_Count', 'German_Fleet_Health', 'German_Gunnery_Count']
    
    for p_var in plot_vars:
        for b_sig in british_signals:
            heat_map(p_var, b_sig)

def heat_map(plot_var: str, british_signal: str):
    os.makedirs(HEAT_MAPS, exist_ok=True)
    fleet, var_name = plot_var.split("_", 1)
    
    # Create a pivot table for final British ship count based on British_Delay and German_Disengage
    
    final_data = df.groupby(['Run_id']).last()
    var_min, var_max = get_min_max(var_name, "Both", data_frame=final_data)

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
    seaborn.heatmap(pivot_table, annot=True, cmap='inferno', fmt='.1f', cbar_kws={'label': 'Average British Ship Count'}, vmin=var_min, vmax=var_max)
    plt.title(f'Average Final {plot_var.replace("_", " ").title()} vs. British Delay and German Disengage')
    plt.xlabel('German Disengage')
    plt.ylabel('British Delay')
    plt.savefig(os.path.join(HEAT_MAPS, f"{plot_var}_heatmap-{british_signal}.jpg"), format="jpg")
    plt.close()


#####################################
### Correlation plot of variables ###
#####################################
def correlation_plot():
    os.makedirs(OUTPUT_PATH, exist_ok=True)

    # Select relevant columns for correlation analysis
    df['British_Signal_Numeric'] = df['British_Signal'].map({'Engage': 1, 'Disengage': 0})
    correlation_data = df[['British_Delay', 'German_Disengage_Delay', 'British_Signal_Numeric', 'British_Ship_Count', 'German_Ship_Count']]

    # Calculate correlation matrix
    corr_matrix = correlation_data.corr()

    # Plot the correlation matrix
    plt.figure(figsize=(8, 7))
    seaborn.heatmap(corr_matrix, annot=True, cmap='YlGnBu', fmt='.2f', cbar_kws={'label': 'Correlation'})
    plt.title('Correlation Matrix for Input Parameters and Ship Counts')
    plt.xticks(rotation=45)
    plt.yticks(rotation=45)
    plt.xticks([i for i in range(len(corr_matrix.columns))], [col.replace('_', ' ').title() for col in corr_matrix.columns])
    plt.yticks([i+1 for i in range(len(corr_matrix.index))], [idx.replace('_', ' ').title() for idx in corr_matrix.index])
    plt.tight_layout()
    # plt.subplots_adjust(left=0.2, right=0.9, top=0.9, bottom=0.2)
    plt.savefig(os.path.join(OUTPUT_PATH, f"corelation_matrix.jpg"), format="jpg")
    plt.close()

plot_all_over_time()
plot_all_box_plots()
plot_all_heat_maps()
correlation_plot()

