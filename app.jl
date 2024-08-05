module App
# set up Genie development environment
using GenieFramework
using JuMP
using Gurobi
using CSV, DataFrames, XLSX
using Stipple
using StippleUI
using StippleDownloads

import Stipple.opts
import Test
@genietools

# for upload 
const FILE_PATH = joinpath("public","uploads")
mkpath(FILE_PATH)

# for gurobi license file 
const ENV["GRB_LICENSE_FILE"] = joinpath("gurobi.lic")

# for commas in between 3 digits for the total cost
function commas(num::Integer)
    str = string(num)
    return replace(str, r"(?<=[0-9])(?=(?:[0-9]{3})+(?![0-9]))" => ",")
end

# for download 
function df_to_xlsx(worker_df,production_df)
    io = IOBuffer()
    XLSX.writetable(io, overwrite=true,
        Worker_Type =(collect(DataFrames.eachcol(worker_df)), DataFrames.names(worker_df)),
        Production =(collect(DataFrames.eachcol(production_df)), DataFrames.names(production_df))
    )
    take!(io)
end

function read_workertype(workerproduct_df)
    num_workertype_w=nrow(workerproduct_df)
    #println(num_workertype_w)
    worker_names= workerproduct_df[:,1]
    #println(worker_names) 
    productionrate_K = Matrix(workerproduct_df[1:end,2:end])
    #println(productionrate_K)
    return num_workertype_w, worker_names, productionrate_K
end

function read_forecast(demand_df)
    num_products_p = ncol(demand_df) - 1 #to not include the time columnindex
    #println(num_products_p)  
    time_horizon_T = nrow(demand_df)
    #println(time_horizon_T)
    date_list = demand_df[:,1]
    date_difference = date_list[2] - date_list[1]
    initial_date = date_list[1] - date_difference
    date_list = [initial_date; date_list]
    date_list = [string(date) for date in date_list]
    #println(date_list)
    product_names = names(demand_df)[2:end]
    #println(product_names)
    demand_data = Matrix(demand_df[:, 2:end])
    demand_D = transpose(demand_data)
    #println(demand_D)

    return num_products_p,time_horizon_T,product_names,demand_D,date_list
end

function optimise(num_products_p,num_workertype_w,time_horizon_T,demand_D,productionrate_K,cost_hiring_cH, cost_firing_cF,cost_inventory_cI,cost_labour_cR,cost_overtime_cO,cost_backlogging_cB,cost_idle_cU,cost_subcontract_cS,product_names,date_list,worker_names, initial_inventory_I0, initial_worker_W0)
    model = Model(Gurobi.Optimizer)

    # Variables
    @variable(model, workerlevel_W[1:num_workertype_w,1:num_products_p, 0:time_horizon_T] >= 0, Int) # Workers
    @variable(model, hired_H[1:num_workertype_w,0:time_horizon_T] >= 0, Int)       # Hired workers
    @variable(model, fired_F[1:num_workertype_w,0:time_horizon_T] >= 0, Int)       # Fired workers
    @variable(model, inventory_I[1:num_products_p, 0:time_horizon_T] >= 0, Int)     # Inventory
    @variable(model, production_P[1:num_products_p, 0:time_horizon_T] >= 0, Int)    # Production
    @variable(model, overtime_O[1:num_products_p, 0:time_horizon_T] >= 0, Int)      # Overtime
    @variable(model, backlogging_B[1:num_products_p, 0:time_horizon_T] >= 0, Int)   # Backlogging
    @variable(model, idle_U[1:num_products_p, 0:time_horizon_T] >= 0, Int)          # Idle
    @variable(model, subcontract_S[1:num_products_p, 0:time_horizon_T] >= 0, Int) #Subcontract
    @variable(model, regularproduction_R[1:num_products_p, 0:time_horizon_T] >= 0, Int) #Regular Production
    @variable(model, aggregated_workerlevel_Wwt[1:num_workertype_w, 0:time_horizon_T])    #Worker Level but 2D

    # Objective
    @objective(model, Min,
        sum(cost_hiring_cH * hired_H[w, t] + cost_firing_cF * fired_F[w, t] for w in 1:num_workertype_w, t in 0:time_horizon_T) +
        sum(cost_inventory_cI * inventory_I[p, t] + cost_labour_cR * production_P[p, t] +
            cost_overtime_cO * overtime_O[p, t] + cost_idle_cU * idle_U[p, t] +
            cost_subcontract_cS * subcontract_S[p, t] + cost_backlogging_cB * backlogging_B[p, t]
            for p in 1:num_products_p, t in 0:time_horizon_T)
    )

    # Constraints
    for w in 1:num_workertype_w
        for t in 1:time_horizon_T
            @constraint(model, aggregated_workerlevel_Wwt[w, t] == sum(workerlevel_W[w, p, t] for p in 1:num_products_p))
        end
    end

    #set initial values of workertype variables for 0 for time period 0

    for w in 1:num_workertype_w
        @constraint(model, aggregated_workerlevel_Wwt[w, 0] == initial_worker_W0[w])
        @constraint(model, hired_H[w,0] == 0)
        @constraint(model, fired_F[w,0] == 0)
    end

    #set initial values of production variables to 0 for time period 0

    for p in 1:num_products_p
        @constraint(model, inventory_I[p,0] == initial_inventory_I0[p])
        @constraint(model, backlogging_B[p,0] == 0 )
        @constraint(model, overtime_O[p,0] == 0)
        @constraint(model, subcontract_S[p,0] == 0)
        @constraint(model, production_P[p,0] == 0)
        @constraint(model, regularproduction_R[p,0] == 0)
        @constraint(model, idle_U[p,0] == 0)
    end     

    for w in 1:num_workertype_w
        for t in 1: time_horizon_T
            @constraint(model, aggregated_workerlevel_Wwt[w,t] == aggregated_workerlevel_Wwt[w, t-1] + hired_H[w,t] - fired_F[w,t])
            @constraint(model, hired_H[w,t] + fired_F[w,t] <= 0.2*aggregated_workerlevel_Wwt[w,t])   
        end    
    end

    for w in 1:num_workertype_w
        for p in 1:num_products_p
            for t in 1:time_horizon_T
                @constraint(model, regularproduction_R[p,t] <= productionrate_K[w,p]*workerlevel_W[w,p,t]) 
            end
        end
    end

    # Worker level constraints for subsequent periods
    for p in 1:num_products_p
        for t in 1:time_horizon_T
            @constraint(model, production_P[p,t] == regularproduction_R[p,t] + overtime_O[p,t] - idle_U[p,t])
            @constraint(model, overtime_O[p,t] <= 0.2*regularproduction_R[p,t])
        end
    end

    # Inventory and backlogging constraints for subsequent periods
    for p in 1:num_products_p
        for t in 1:time_horizon_T
            @constraint(model, inventory_I[p,t] - backlogging_B[p,t] == inventory_I[p,t-1] - backlogging_B[p,t-1] + production_P[p,t] + subcontract_S[p,t] - demand_D[p,t])    
        end
    end

    # Solve the model
    optimize!(model)

    #update to rounded to int values
    production_P_round = round.(Int,value.(production_P))
    overtime_O_round = round.(Int,value.(overtime_O))
    backlogging_B_round = round.(Int,value.(backlogging_B))
    idle_U_round = round.(Int,value.(idle_U))
    subcontract_S_round = round.(Int,value.(subcontract_S))
    inventory_I_round = round.(Int,value.(inventory_I))
    zero_column_round = round.(Int,zeros(num_products_p,1)) #for demand, because it is 4x24, didnt include the intiial time period
    demand_D_round = hcat(zero_column_round, demand_D)
    fired_F_round = round.(Int,value.(fired_F))
    hired_H_round = round.(Int,value.(hired_H))
    aggregated_workerlevel_Wwt_round = round.(Int,value.(aggregated_workerlevel_Wwt)) #transforms demand into 4x25

    # for debugging purposes
    println("Objective value: ", objective_value(model))
    println("Workers: ", aggregated_workerlevel_Wwt_round)
    println("Hired: ", hired_H_round)
    println("Fired: ", fired_F_round)
    println("Inventory: ", inventory_I_round)
    println("Production: ", production_P_round)
    println("Overtime: ", overtime_O_round)
    println("Backlogging: ", backlogging_B_round)
    println("Idle: ", idle_U_round)
    println("Subcontract: ", subcontract_S_round)

    production_df = DataFrame(
        Product_Name = repeat(product_names, inner = time_horizon_T+1), #to include the initial date (NOT in forecast)
        Date = repeat(date_list, outer = num_products_p),
        Demand = collect(Iterators.flatten(eachrow(demand_D_round))),
        Inventory = collect(Iterators.flatten(eachrow(inventory_I_round))),
        Production = collect(Iterators.flatten(eachrow(production_P_round))),
        Overtime = collect(Iterators.flatten(eachrow(overtime_O_round))),
        Backlogging = collect(Iterators.flatten(eachrow(backlogging_B_round))),
        Idle = collect(Iterators.flatten(eachrow(idle_U_round))),
        Subcontract = collect(Iterators.flatten(eachrow(subcontract_S_round))),
    )

    worker_df = DataFrame(
    Worker_Type = repeat(worker_names, inner = time_horizon_T+1),
    Date = repeat(date_list, outer = num_workertype_w),
    Workers_Fired = collect(Iterators.flatten(eachrow(fired_F_round))),
    Workers_Hired = collect(Iterators.flatten(eachrow(hired_H_round))),
    Worker_Level = collect(Iterators.flatten(eachrow(aggregated_workerlevel_Wwt_round)))
    )

    return objective_value(model), aggregated_workerlevel_Wwt_round, hired_H_round, fired_F_round, inventory_I_round, production_P_round, overtime_O_round, backlogging_B_round, idle_U_round, subcontract_S_round, worker_df, production_df
end 

# add reactive code to make the UI interactive
@app begin
    #debug for prod
    @in msg = ""
    @in N = 0
    @in result = 0

    # reactive variables are tagged with @in and @out
    @in forecast = DataFrame()

    # Initialise Costs, data for graphs
    @in cost_hiring_cH = 5882    # Hiring cost per worker
    @in cost_firing_cF = 896    # Firing cost per worker
    @in cost_inventory_cI = 9 # Inventory holding cost per unit
    @in cost_labour_cR = 233  # Cost of Labour per production unit
    @in cost_overtime_cO = 349 # Cost of Overtime per overtime unit
    @in cost_backlogging_cB = 135  #Cost of Backlogging per overtime unit 
    @in cost_idle_cU= 250  #Cost of Idle per worker
    @in cost_subcontract_cS= 350  #cost of Subcontract 
    @in productionrate_K = Any[120 137 86 137; 122 140 100 150; 130 125 90 120]
    @in num_products_p = 4
    @in num_workertype_w = 3
    @in date_list = ["2023-12-01", "2024-01-01", "2024-02-01", "2024-03-01", "2024-04-01", "2024-05-01", "2024-06-01", "2024-07-01", "2024-08-01", "2024-09-01", "2024-10-01", "2024-11-01", "2024-12-01", "2025-01-01", "2025-02-01", "2025-03-01", "2025-04-01", "2025-05-01", "2025-06-01", "2025-07-01", "2025-08-01", "2025-09-01", "2025-10-01", "2025-11-01", "2025-12-01"]
    @in time_horizon_T = 24
    @in demand_D = Any[5860 7500 5896 2964 5188 1464 3880 4192 2580 5328 5208 6032 4344 6728 5084 4264 5840 3716 5352 3032 3040 4596 2460 3916; 2392 4300 2468 6064 2304 1092 3640 132 3684 4956 3612 2760 2784 3468 30 3128 3504 4660 1648 2804 3872 440 5660 1840; 2128 2860 556 2340 3004 1776 2032 2464 1068 2936 1736 1448 2364 2684 2116 3604 2932 3072 1552 1628 3232 2120 2708 2176; 616 812 612 1276 728 900 576 472 652 624 576 576 1180 628 720 780 984 652 1004 664 560 932 824 452]
    @in initial_inventory_I0 = Any[150 120 30 0]
    @in initial_worker_W0 = Any[56 42 50]

    @out product_names = ["XC_60 Gent", "XC_60 China", "Kuga", "Mondeo"]
    @in selected_product = "XC_60 Gent"
    @out worker_names = ["Assembler", "Packer", "Tester"]
    @in selected_worker = "Assembler"

    # Initialise optimise function variables, see Backend.ipynb for more info
    @in cost = 0
    @in cost_str = "" #for total cost: ___, in string because of commas 
    @in worklevel_W = Matrix{Float64}(undef,4,24)
    @in hired_H = Matrix{Float64}(undef,4,24)
    @in fired_F = Matrix{Float64}(undef,4,24)
    @in inventory_I = Matrix{Float64}(undef,4,24)
    @in production_P = Matrix{Float64}(undef,4,24)
    @in overtime_O = Matrix{Float64}(undef,4,24)
    @in backlogging_B = Matrix{Float64}(undef,4,24)
    @in idle_U = Matrix{Float64}(undef,4,24)
    @in subcontract_S = Matrix{Float64}(undef,4,24)
    @in elapsed_time = 0.000

    # Initialise start and end date to for dropdown
    @in start_date = "2023-11-30"
    @in end_date = "2026-01-02"

    @in workerlevel_plot = []
    @in hired_plot = []
    @in fired_plot = []
    @in idle_plot = []
    @in subcontract_plot = []

    @in demand_plot = []
    @in inventory_plot = []
    @in production_plot = []
    @in overtime_plot = []
    @in backlogging_plot = []

    #Initialise data frame from optimisation results, and data plot for selected product plots 
    @in worker_df = DataFrame()
    @in production_df = DataFrame()

    # Initialise download button as false, once button is pressed, download_df becomes true.
    @in download_df = false  

    # Initialise button state as false, when pressed = true in the UI
    @in press_optimise = false

    # Initialise toggle backlogging as false, when toggled = true in UI
    @in disable_backlogging = false
    # end

    # Initialise upload template as false, when toggled = true in UI
    @in download_template = false

    @onchange disable_backlogging begin
        cost_backlogging_cB = 999999999
    end

    @in optimisation_ready = false  #optimisation_ready triggers the initial plots of the first product after optimisation is pressed 
    @onbutton press_optimise begin
        @info "Running Optimisation..."
        notify(__model__,"Running Optimisation...") 
        optimise_result = optimise(num_products_p,num_workertype_w,time_horizon_T,demand_D,productionrate_K,cost_hiring_cH, cost_firing_cF,cost_inventory_cI,cost_labour_cR,cost_overtime_cO,cost_backlogging_cB,cost_idle_cU,cost_subcontract_cS,product_names,date_list,worker_names,initial_inventory_I0,initial_worker_W0) #num_machines_M,timetaken_τ
        elapsed_time = @elapsed optimise(num_products_p,num_workertype_w,time_horizon_T,demand_D,productionrate_K,cost_hiring_cH, cost_firing_cF,cost_inventory_cI,cost_labour_cR,cost_overtime_cO,cost_backlogging_cB,cost_idle_cU,cost_subcontract_cS,product_names,date_list,worker_names,initial_inventory_I0,initial_worker_W0) #num_machines_M,timetaken_τ
        elapsed_time = round(elapsed_time,digits=3)
        notify(__model__,"Optimisation Completed. Time taken: $(elapsed_time) seconds")  
        cost = optimise_result[1] #objective_value(model)
        cost_str = commas(cost)
        worklevel_W = optimise_result[2] #aggregated_workerlevel_Wwt_round
        hired_H = optimise_result[3] #hired_H_round
        fired_F = optimise_result[4] #fired_F_round
        inventory_I = optimise_result[5] #inventory_I_round
        production_P = optimise_result[6] #production_P_round
        overtime_O = optimise_result[7] #overtime_O_round
        backlogging_B = optimise_result[8] #backlogging_B_round
        idle_U = optimise_result[9] #idle_U_round
        subcontract_S = optimise_result[10] #subcontract_S_round
        worker_df = optimise_result[11] #worker_df
        production_df = optimise_result[12] #production_df
        @info "Optimisation Completed"
        press_optimise = false
        optimisation_ready = true
    end

    @onchange selected_product,selected_worker, start_date, end_date, optimisation_ready begin
        # filters the production and worker dataframe, and convert each column into a vector (list) corresponding to the filtered values, see Backend.ipynb for more info
        notify(__model__,"Plotting Graphs...")
        worker_df_copy = copy(worker_df)
        filter_worker_df = filter!(row -> row.Worker_Type == selected_worker &&  start_date <= row.Date <= end_date, worker_df_copy)
        workerlevel_plot = filter_worker_df.Worker_Level
        hired_plot = filter_worker_df.Workers_Hired
        fired_plot = filter_worker_df.Workers_Fired
        date_list = filter_worker_df.Date

        production_df_copy = copy(production_df)
        filter_production_df = filter!(row -> row.Product_Name == selected_product &&  start_date <= row.Date <= end_date, production_df_copy)
        demand_plot = filter_production_df.Demand
        inventory_plot = filter_production_df.Inventory
        production_plot = filter_production_df.Production
        overtime_plot = filter_production_df.Overtime
        backlogging_plot = filter_production_df.Backlogging
        idle_plot = filter_production_df.Idle
        subcontract_plot = filter_production_df.Subcontract
        notify(__model__,"Graphs Completed!")
    end   

    @onbutton download_df begin
        if ! isempty(worker_df) && !isempty(production_df)
            @info "File downloaded"
            notify(__model__,"Exporting Results...")
            download_binary(__model__, df_to_xlsx(worker_df,production_df), "Results.xlsx")
        else 
            notify(__model__,"No results detected! Please click Optimise first!")
        end
    end

    @onbutton download_template begin
        try
            notify(__model__, "Downloading Template...")
            template = joinpath("UploadTemplate.xlsx")
            io = IOBuffer()
            open(template, "r") do file
                write(io, read(file))
            end
            seekstart(io)
            download_binary(__model__,take!(io), "UploadTemplate.xlsx")
        catch ex
            println("Error during download: ", ex)
        end
    end

    @onchange fileuploads begin
        #file uploading
        @show fileuploads
        if ! isempty(fileuploads)
            @info "File was uploaded: " fileuploads
            notify(__model__,"File was uploaded: $(fileuploads)")
            filename = fileuploads["name"]

            try
                isdir(FILE_PATH) || mkpath(FILE_PATH)
                mv(fileuploads["path"], joinpath(FILE_PATH, filename), force=true)
            catch e
                @error "Error processing file: $e"
                notify(__model__,"Error processing file: $(fileuploads["name"])")
            end

            fileuploads = Dict{AbstractString,AbstractString}()

            demand_df = DataFrame(XLSX.readtable(joinpath(FILE_PATH,filename),"demand"))
            num_products_p,time_horizon_T,product_names,demand_D,date_list = read_forecast(demand_df)

            workerproduct_df = DataFrame(XLSX.readtable(joinpath(FILE_PATH,filename),"workerproduct"))
            num_workertype_w, worker_names, productionrate_K = read_workertype(workerproduct_df)

            initial_inventory_df = DataFrame(XLSX.readtable(joinpath(FILE_PATH,filename),"initial_inventory"))
            initial_inventory_I0 = Matrix(initial_inventory_df[!,1:end])

            initial_worker_df = DataFrame(XLSX.readtable(joinpath(FILE_PATH,filename),"initial_worker"))
            initial_worker_W0 = Matrix(initial_worker_df[!,1:end])
            
            println(worker_names)
            selected_product, selected_worker = product_names[1], worker_names[1] #defaults to first product after uploading  #defaults to first workertype after uploading
        end
        upfiles = readdir(FILE_PATH)
    end
end 

# register a new route and the page that will be
# loaded on access
@page("/", "app.jl.html")
end