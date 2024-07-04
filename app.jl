module App
# set up Genie development environment
using GenieFramework
using JuMP
using HiGHS
using CSV, DataFrames
using Random
Random.seed!(1234) # set seed
import Test
@genietools

const FILE_PATH = joinpath("public","uploads")
mkpath(FILE_PATH)

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
    println(workdays_n)

    #Initialise productivity
    productivity_K = [] 
    for col in 2:ncol(forecast)
        push!(productivity_K, rand(10:12))
    end

    return num_products_p,time_horizon_T,product_names,demand_D,workdays_n,productivity_K
end

function optimise(num_products_p,time_horizon_T,demand_D,workdays_n,productivity_K,cost_hiring_cH,cost_firing_cF,cost_inventory_cI,cost_labour_cR,cost_overtime_cO,cost_backlogging_cB)
    # Initialize the model
    model = Model(HiGHS.Optimizer)

    # Variables
    @variable(model, workerlevel_W[1:num_products_p,1:time_horizon_T] >= 0)       # Workers
    @variable(model, hired_H[1:num_products_p,1:time_horizon_T] >= 0)       # Hired workers
    @variable(model, fired_F[1:num_products_p,1:time_horizon_T] >= 0)       # Fired workers
    @variable(model, inventory_I[1:num_products_p,1:time_horizon_T] >= 0)       # Inventory as integer variables
    @variable(model, production_P[1:num_products_p,1:time_horizon_T] >= 0)       # Production
    @variable(model, overtime_O[1:num_products_p,1:time_horizon_T] >= 0)       # Overtime
    @variable(model, backlogging_B[1:num_products_p,1:time_horizon_T] >= 0)        # Production

    # Objective function: Minimize total cost
    @objective(model, Min, sum(cost_hiring_cH*hired_H + cost_firing_cF*fired_F 
    + cost_inventory_cI*inventory_I + cost_labour_cR*production_P 
    + cost_overtime_cO*overtime_O + cost_backlogging_cB*backlogging_B))

    # Constraints

    #only for period 1, W annd I-B eqns
    for p in 1:num_products_p
        @constraint(model, workerlevel_W[p,1] == hired_H[p,1] - fired_F[p,1])
        @constraint(model, inventory_I[p,1] - backlogging_B[p,1] == production_P[p,1] - demand_D[p][1])
    end    

    #P equations
    for p in 1:num_products_p
        for t in 2:time_horizon_T
            @constraint(model, workerlevel_W[p,t] 
            == workerlevel_W[p,t-1] + hired_H[p,t] - fired_F[p,t])
            @constraint(model, inventory_I[p,t] - backlogging_B[p,t] 
            == inventory_I[p,t-1] - backlogging_B[p,t-1] 
            + production_P[p,t] - demand_D[p][t])
        end
    end

    #for rest of period, W and I-B equations
    for p in 1:num_products_p
        for t in 1:time_horizon_T
            @constraint(model, production_P[p,t] 
            == productivity_K[p] * workdays_n[t] * workerlevel_W[p,t])
        end    
    end

    # Solve the model
    optimize!(model)

    #retrieve Values
    println("Objective value: ", objective_value(model))
    println("Workers: ", round.(Int,value.(workerlevel_W)))
    println("Hired: ", round.(Int,value.(hired_H)))
    println("Fired: ", round.(Int,value.(fired_F)))
    println("Inventory: ", round.(Int,value.(inventory_I)))
    println("Production: ", round.(Int,value.(production_P)))
    println("Overtime: ", round.(Int,value.(overtime_O)))
    println("Backlogging: ", round.(Int,value.(backlogging_B)))

    return objective_value(model), value.(workerlevel_W), value.(hired_H), value.(fired_F), value.(inventory_I), value.(production_P), value.(overtime_O), value.(backlogging_B)
end

# add reactive code to make the UI interactive
@app begin
    # reactive variables are tagged with @in and @out
    @in forecast = DataFrame()
    # Initialise Costs
    @in cost_hiring_cH = 5882    # Hiring cost per worker
    @in cost_firing_cF = 857    # Firing cost per worker
    @in cost_inventory_cI = 9 # Inventory holding cost per unit
    @in cost_labour_cR = 233  # Cost of Labour per production unit
    @in cost_overtime_cO = 349 # Cost of Overtime per overtime unit
    @in cost_backlogging_cB = 135  #Cost of Backlogging per overtime unit 

    @in press_optimise = false 

    @out backlogging = ["Yes", "No"]
    @in selected_backlogging = "Yes"
    # watch a variable and execute a block of code when
    # its value changes

    #Initialise read_forecast function variables, see Backedn.ipynb for more info 
    @in num_products_p = 4
    @in time_horizon_T = 12

    @out product_names = ["A","B","C","D"]
    @in selected_product = "A"

    @in demand_D = Any[[5668, 3916, 5312, 6720, 4092, 3108, 4656, 4772, 3408, 2936, 8284, 4516], [5952, 3744, 1552, 3032, 2372, 2292, 1568, 612, 3988, 2540, 6680, 3260], [2012, 2128, 2632, 1740, 1540, 2292, 2920, 3256, 2288, 2424, 2228, 2660], [924, 800, 964, 768, 648, 848, 828, 764, 720, 448, 700, 568]]
    @in workdays_n = Any[21, 22, 20, 23, 21, 21, 23, 23, 21, 22, 22, 22]
    @in productivity_K = Any[10, 10, 11, 12]
    @in date_list = Any["1/1/2024", "1/2/2024", "1/3/2024", "1/4/2024", "1/5/2024", "1/6/2024", "1/7/2024", "1/8/2024", "1/9/2024", "1/10/2024", "1/11/2024", "1/12/2024"]

    # Initialise optimise function variables, see Backend.ipynb for more info
    @in cost = 0
    @in worklevel_W = Vector{Vector{Float64}}()
    @in hired_H = Vector{Vector{Float64}}()
    @in fired_F = Vector{Vector{Float64}}()
    @in inventory_I = Vector{Vector{Float64}}()
    @in prodcution_P = Vector{Vector{Float64}}()
    @in overtime_O = Vector{Vector{Float64}}()
    @in backlogging_B = Vector{Vector{Float64}}()

    @onchange cost_hiring_cH,cost_firing_cF,cost_inventory_cI,cost_labour_cR,cost_overtime_cO,cost_backlogging_cB,demand_D, fileuploads begin
        # the values of result and msg in the UI will
        # be automatically updated
        result = optimise(num_products_p,time_horizon_T,demand_D,workdays_n,productivity_K,cost_hiring_cH,cost_firing_cF,cost_inventory_cI,cost_labour_cR,cost_overtime_cO,cost_backlogging_cB)
        cost = round(Int,result[1])
        worklevel_W = result[2]
        hired_H = result[3]
        fired_F = result[4]
        inventory_I = result[5]
        prodcution_P = result[6]
        overtime_O = result[7]
        backlogging_B = result[8]

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
            forecast = CSV.read(joinpath(FILE_PATH,filename),DataFrame)
        end
        upfiles = readdir(FILE_PATH)
    end
end 


# register a new route and the page that will be
# loaded on access
@page("/", "app.jl.html")
end