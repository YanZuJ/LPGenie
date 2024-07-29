module App
# set up Genie development environment
using GenieFramework
using JuMP
<<<<<<< HEAD
=======
using Gurobi
>>>>>>> main
using HiGHS
using CSV, DataFrames, XLSX
using Random
Random.seed!(1234) # set seed
using Stipple
using StippleUI
using StippleDownloads

import Stipple.opts
import Test
@genietools

# for upload 
const FILE_PATH = joinpath("public","uploads")
mkpath(FILE_PATH)

<<<<<<< HEAD
=======
# for gurobi license file 
const ENV["GRB_LICENSE_FILE"] = joinpath("gurobi.lic")

# for commas in between 3 digits for the total cost
function commas(num::Integer)
    str = string(num)
    return replace(str, r"(?<=[0-9])(?=(?:[0-9]{3})+(?![0-9]))" => ",")
end

# for download 
>>>>>>> main
function df_to_xlsx(df)
    io = IOBuffer()
    XLSX.writetable(io, df)
    take!(io)
end

function read_forecast(forecast)
    num_products_p = ncol(forecast) - 1  #to not include the time columnindex
    time_horizon_T = nrow(forecast)
    product_names = names(forecast)[2:end]

    #Initialise demand
    demand_D = [] #Initialise 
    for col in 2:ncol(forecast) #Extract each column as a seperate array and store it
        push!(demand_D,(forecast[:,col]))
    end

    #Initialise workdays 
    workdays_n = [] #Initialise 
    for row in 1:time_horizon_T
        push!(workdays_n, rand(20:23)) #push a random workday value between 20 to 23
    end

    #Initialise productivity
    productivity_K = [] 
    for col in 2:ncol(forecast)
        push!(productivity_K, rand(10:12))
    end

    #Initialise dates in correct format
    date_list = []
    date_input_format = DateFormat("dd/mm/yyyy")
    date_output_format = DateFormat("yyyy-mm-dd")
    for row in 1:time_horizon_T
        date_obj = Date(forecast[row,1],date_input_format)
        formatted_date_obj = Dates.format(date_obj,date_output_format)
        push!(date_list,formatted_date_obj)
    end

    return num_products_p,time_horizon_T,product_names,demand_D,workdays_n,productivity_K,date_list
end

function optimise(num_products_p,time_horizon_T,demand_D,workdays_n,productivity_K,cost_hiring_cH,cost_firing_cF,cost_inventory_cI,cost_labour_cR,cost_overtime_cO,cost_backlogging_cB,cost_idle_cU,cost_subcontract_cS,product_names,date_list) #num_machines_M,timetaken_τ
    # Initialize the model
    model = Model(HiGHS.Optimizer)

    # Variables
    @variable(model, workerlevel_W[1:num_products_p,1:time_horizon_T] >= 0, Int)       # Workers
    @variable(model, hired_H[1:num_products_p,1:time_horizon_T] >= 0, Int)       # Hired workers
    @variable(model, fired_F[1:num_products_p,1:time_horizon_T] >= 0, Int)       # Fired workers
    @variable(model, inventory_I[1:num_products_p,1:time_horizon_T] >= 0, Int)       # Inventory as integer variables
    @variable(model, production_P[1:num_products_p,1:time_horizon_T] >= 0, Int)       # Production
    @variable(model, overtime_O[1:num_products_p,1:time_horizon_T] >= 0, Int)       # Overtime
    @variable(model, backlogging_B[1:num_products_p,1:time_horizon_T] >= 0, Int)  # Backlogging
    @variable(model, idle_U[1:num_products_p,1:time_horizon_T] >= 0, Int)         #Idle
    @variable(model, subcontract_S[1:num_products_p,1:time_horizon_T] >= 0, Int)         #Subcontract      

    # Objective function: Minimize total cost
    @objective(model, Min, sum(cost_hiring_cH*hired_H + cost_firing_cF*fired_F 
    + cost_inventory_cI*inventory_I + cost_labour_cR*production_P 
    + cost_overtime_cO*overtime_O + cost_idle_cU*idle_U+ cost_subcontract_cS*subcontract_S + cost_backlogging_cB*backlogging_B))

    # Constraints

    #only for period 1, W annd I-B eqns
    for p in 1:num_products_p
        @constraint(model, workerlevel_W[p,1] == hired_H[p,1] - fired_F[p,1])
        @constraint(model, inventory_I[p,1] - backlogging_B[p,1] == production_P[p,1] + subcontract_S[p,1]- demand_D[p][1])
    end    

    #for rest of period, W and I-B equations
    for p in 1:num_products_p
        for t in 2:time_horizon_T
            @constraint(model, workerlevel_W[p,t] 
            == workerlevel_W[p,t-1] + hired_H[p,t] - fired_F[p,t])
            @constraint(model, inventory_I[p,t] - backlogging_B[p,t] 
            == inventory_I[p,t-1] - backlogging_B[p,t-1] 
            + subcontract_S[p,t]+ production_P[p,t] - demand_D[p][t])
            @constraint(model, hired_H[p,t] + fired_F[p,t] <=  0.1*workerlevel_W[p,t])
        end
    end

    #P equations
    for p in 1:num_products_p
        for t in 1:time_horizon_T
            @constraint(model, production_P[p,t] 
            == productivity_K[p] * workdays_n[t] * workerlevel_W[p,t] + overtime_O[p,t] - idle_U[p,t])
            # for m in 1:num_machines_M
            #     total_time_taken += timetaken_τ[p][m] * production_P[p, t]
            # end
            # @constraint(model, total_time_taken <= workerlevel_W[p, t] * workdays_n[t] * 8)
        end    
    end

    # Solve the model
    optimize!(model)

    #prints value on terminal for debugging purposes
    println("Objective value: ", objective_value(model))
    println("Workers: ", round.(Int,value.(workerlevel_W)))
    println("Hired: ", round.(Int,value.(hired_H)))
    println("Fired: ", round.(Int,value.(fired_F)))
    println("Inventory: ", round.(Int,value.(inventory_I)))
    println("Production: ", round.(Int,value.(production_P)))
    println("Overtime: ", round.(Int,value.(overtime_O)))
    println("Backlogging: ", round.(Int,value.(backlogging_B)))
    println("Subcontract: ", round.(Int,value.(subcontract_S)))
    println("Idle: ", round.(Int,value.(idle_U)))

    #Update to rounded integer values 
    workerlevel_W = round.(Int,value.(workerlevel_W))
    hired_H = round.(Int,value.(hired_H))
    fired_F =  round.(Int,value.(fired_F))
    inventory_I = round.(Int,value.(inventory_I))
    production_P = round.(Int,value.(production_P))
    overtime_O = round.(Int,value.(overtime_O))
    backlogging_B = round.(Int,value.(backlogging_B))
    idle_U = round.(Int,value.(idle_U))
    subcontract_S = round.(Int,value.(subcontract_S))

    #retrieve values in a DataFrames for plotting of graphs
    worker_df = DataFrame(
        Product_Name = repeat(product_names, inner = time_horizon_T),
        Date = repeat(date_list, outer = num_products_p),
        Worker_Level = collect(Iterators.flatten(eachrow(workerlevel_W))),
        Workers_Hired = collect(Iterators.flatten(eachrow(hired_H))),
        Workers_Fired = collect(Iterators.flatten(eachrow(fired_F))),
    )

    production_df = DataFrame(
        Product_Name = repeat(product_names, inner = time_horizon_T),
        Date = repeat(date_list, outer = num_products_p),
        Demand = vcat(demand_D...),
        Inventory = collect(Iterators.flatten(eachrow(inventory_I))),
        Production = collect(Iterators.flatten(eachrow(production_P))),
        Overtime = collect(Iterators.flatten(eachrow(overtime_O))),
        Backlogging = collect(Iterators.flatten(eachrow(backlogging_B))),
        Idle = collect(Iterators.flatten(eachrow(idle_U))),
        Subcontract = collect(Iterators.flatten(eachrow(subcontract_S))),
    )

    export_df = DataFrame(
        Product_Name = repeat(product_names, inner = time_horizon_T),
        Date = repeat(date_list, outer = num_products_p),
        Demand = vcat(demand_D...),
        Worker_Level = collect(Iterators.flatten(eachrow(workerlevel_W))),
        Workers_Hired = collect(Iterators.flatten(eachrow(hired_H))),
        Workers_Fired = collect(Iterators.flatten(eachrow(fired_F))),
        Inventory = collect(Iterators.flatten(eachrow(inventory_I))),
        Production = collect(Iterators.flatten(eachrow(production_P))),
        Overtime = collect(Iterators.flatten(eachrow(overtime_O))),
        Backlogging = collect(Iterators.flatten(eachrow(backlogging_B))),
<<<<<<< HEAD
    )

    return objective_value(model), value.(workerlevel_W), value.(hired_H), value.(fired_F), value.(inventory_I), value.(production_P), value.(overtime_O), value.(backlogging_B), worker_df, production_df, export_df
=======
        Idle = collect(Iterators.flatten(eachrow(idle_U))),
        Subcontract = collect(Iterators.flatten(eachrow(subcontract_S))),
    )

    return objective_value(model), value.(workerlevel_W), value.(hired_H), value.(fired_F), value.(inventory_I), value.(production_P), value.(overtime_O), value.(backlogging_B), value.(idle_U), value.(subcontract_S), worker_df, production_df, export_df
>>>>>>> main
end

# add reactive code to make the UI interactive
@app begin

    #debug for prod
    @in msg = "" #this is for total costs
    @in N = 0
    @in result = 0
    # @out machine_df = CSV.read("dummydata1.csv", DataFrame)
    # @out timetaken_τ=[]
    # for col in 2:ncol(machine_df)
    #     push!(timetaken_τ, machine_df[:,col])
    # end 
    # @out num_machines_M = nrow(machine_df)
    # reactive variables are tagged with @in and @out
    @in forecast = DataFrame()
    # Initialise Costs
    @in cost_hiring_cH = 5882    # Hiring cost per worker
    @in cost_firing_cF = 857    # Firing cost per worker
    @in cost_inventory_cI = 9 # Inventory holding cost per unit
    @in cost_labour_cR = 233  # Cost of Labour per production unit
    @in cost_overtime_cO = 349 # Cost of Overtime per overtime unit
    @in cost_backlogging_cB = 135  #Cost of Backlogging per overtime unit
    @in cost_idle_cU= 250 #Cost of Idle per worker
    @in cost_subcontract_cS= 250 #cost of Subcontract 

    # watch a variable and execute a block of code when
    # its value changes

    #Initialise read_forecast function variables, see Backedn.ipynb for more info 
    @in num_products_p = 4
    @in time_horizon_T = 12

    @out product_names = ["XC60_Gent", "XC60_China", "Kuga", "Mondeo"]
    @in selected_product = "XC60_Gent"

    @in demand_D = [[5668, 3916, 5312, 6720, 4092, 3108, 4656, 4772, 3408, 2936, 8284, 4516], [5952, 3744, 1552, 3032, 2372, 2292, 1568, 612, 3988, 2540, 6680, 3260], [2012, 2128, 2632, 1740, 1540, 2292, 2920, 3256, 2288, 2424, 2228, 2660], [924, 800, 964, 768, 648, 848, 828, 764, 720, 448, 700, 568]]
    @in workdays_n = [21, 22, 20, 23, 21, 21, 23, 23, 21, 22, 22, 22]
    @in productivity_K = [10, 10, 11, 12]
    @in date_list = ["2024-01-01", "2024-02-01", "2024-03-01", "2024-04-01", "2024-05-01", "2024-06-01", "2024-07-01", "2024-08-01", "2024-09-01", "2024-10-01", "2024-11-01", "2024-12-01"]

    # Initialise optimise function variables, see Backend.ipynb for more info
    @in cost = 0
    @in cost_str = "" #for total cost: ___, in string because of commas 
    @in worklevel_W = Matrix{Float64}(undef,4,12)
    @in hired_H = Matrix{Float64}(undef,4,12)
    @in fired_F = Matrix{Float64}(undef,4,12)
    @in inventory_I = Matrix{Float64}(undef,4,12)
    @in prodcution_P = Matrix{Float64}(undef,4,12)
    @in overtime_O = Matrix{Float64}(undef,4,12)
    @in backlogging_B = Matrix{Float64}(undef,4,12)
    @in idle_U = Matrix{Float64}(undef,4,12)
    @in subcontract_S = Matrix{Float64}(undef,4,12)

    # Initialise start and end date to for dropdown
    @in start_date = "2023-12-30"
    @in end_date = "2025-01-02"

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
    @in export_df = DataFrame()

<<<<<<< HEAD
=======
    # Initialise download button as false, once button is pressed, download_df becomes true.
>>>>>>> main
    @in download_df = false  

    # Initialise button state as false, when pressed = true in the UI
    @in press_optimise = false

    # Initialise toggle backlogging as false, when toggled = true in UI
    @in disable_backlogging = false
    # end

    # @page("/", "app.jl.html")
    # end
    @onchange disable_backlogging begin
        cost_backlogging_cB = 999999999
    end

    @in optimisation_ready = false  #optimisation_ready triggers the initial plots of the first product after optimisation is pressed 
    @onbutton press_optimise begin
        @info "Running Optimisation..."
        notify(__model__,"Running Optimisation...") 
        optimise_result = optimise(num_products_p,time_horizon_T,demand_D,workdays_n,productivity_K,cost_hiring_cH,cost_firing_cF,cost_inventory_cI,cost_labour_cR,cost_overtime_cO,cost_backlogging_cB,cost_idle_cU,cost_subcontract_cS, product_names, date_list) #num_machines_M,timetaken_τ
        elapsed_time = @elapsed optimise(num_products_p,time_horizon_T,demand_D,workdays_n,productivity_K,cost_hiring_cH,cost_firing_cF,cost_inventory_cI,cost_labour_cR,cost_overtime_cO,cost_backlogging_cB,cost_idle_cU,cost_subcontract_cS, product_names, date_list) #num_machines_M,timetaken_τ
        elapsed_time = round(elapsed_time,digits=3)
        notify(__model__,"Optimisation Completed. Time taken: $(elapsed_time) seconds")   
        cost = optimise_result[1]
        cost_str = commas(cost)
        worklevel_W = optimise_result[2]
        hired_H = optimise_result[3]
        fired_F = optimise_result[4]
        inventory_I = optimise_result[5]
        prodcution_P = optimise_result[6]
        overtime_O = optimise_result[7]
        backlogging_B = optimise_result[8]
<<<<<<< HEAD
        worker_df = optimise_result[9]
        production_df = optimise_result[10]
        export_df = optimise_result[11]
=======
        idle_U = optimise_result[9]
        subcontract_S = optimise_result[10]
        worker_df = optimise_result[11]
        production_df = optimise_result[12]
        export_df = optimise_result[13]

>>>>>>> main
        @info "Optimisation Completed"
        press_optimise = false
        optimisation_ready = true
    end

    @onchange selected_product, start_date, end_date, optimisation_ready begin
        # filters the production and worker dataframe, and convert each column into a vector (list) corresponding to the filtered values, see Backend.ipynb for more info
        notify(__model__,"Plotting Graphs...")
        worker_df_copy = copy(worker_df)
        filter_worker_df = filter!(row -> row.Product_Name == selected_product &&  start_date <= row.Date <= end_date, worker_df_copy)
        workerlevel_plot = filter_worker_df.Worker_Level
        hired_plot = filter_worker_df.Workers_Hired
        fired_plot = filter_worker_df.Workers_Fired

        production_df_copy = copy(production_df)
        filter_production_df = filter!(row -> row.Product_Name == selected_product &&  start_date <= row.Date <= end_date, production_df_copy)
        demand_plot = filter_production_df.Demand
        inventory_plot = filter_production_df.Inventory
        production_plot = filter_production_df.Production
        overtime_plot = filter_production_df.Overtime
        backlogging_plot = filter_production_df.Backlogging
<<<<<<< HEAD
        notify(__model__,"Graphs Completed!")
    end   

    @onchange download_df begin
=======
        idle_plot = filter_production_df.Idle
        subcontract_plot = filter_production_df.Subcontract
        notify(__model__,"Graphs Completed!")
    end   

    @onbutton download_df begin
>>>>>>> main
        if ! isempty(export_df)
            @info "File downloaded"
            notify(__model__,"Downloading File...")
            download_binary(__model__, df_to_xlsx(export_df), "Results.xlsx")
        else 
<<<<<<< HEAD
            notify(__model__,"No results detected! Please click Optimise first and refresh the app!")
=======
            notify(__model__,"No results detected! Please click Optimise first!")
>>>>>>> main
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
            forecast = CSV.read(joinpath(FILE_PATH,filename),DataFrame) #reading of files here
            num_products_p,time_horizon_T,product_names,demand_D,workdays_n,productivity_K,date_list = read_forecast(forecast)
            selected_product = product_names[1] #defaults to first product after uploading
        end
        upfiles = readdir(FILE_PATH)
    end
end 

# register a new route and the page that will be
# loaded on access
@page("/", "app.jl.html")
end