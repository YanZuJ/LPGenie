module App
# set up Genie development environment
using GenieFramework
using JuMP
using HiGHS
using CSV, DataFrames
import Test
@genietools

const FILE_PATH = joinpath("public","uploads")
mkpath(FILE_PATH)

function optimise(demand ,c_H , c_F ,c_I)
    workdays = [26, 24, 20, 18, 22, 23, 14, 21, 23, 24, 21, 13]
    productivity = 0.308
    T = length(demand)

    # Initialize the model
    model = Model(HiGHS.Optimizer)

    # Variables
    @variable(model, W[1:T] >= 0, Int)       # Workers
    @variable(model, H[1:T] >= 0)       # Hired workers
    @variable(model, F[1:T] >= 0)       # Fired workers
    @variable(model, I[1:T] >= 0)       # Inventory 
    @variable(model, P[1:T] >= 0)       # Production

    # Objective function: Minimize total cost
    @objective(model, Min, sum(c_H * H[t] + c_F * F[t] + c_I * I[t] for t in 1:T))

    # Constraints
    @constraint(model, W[1] == H[1] - F[1])
    for t in 2:T
    @constraint(model, W[t] == W[t-1] + H[t] - F[t])
    end

    for t in 1:T
    @constraint(model, P[t] == workdays[t] * W[t] * productivity)
    @constraint(model, I[t] == (t == 1 ? 0 : I[t-1]) + P[t] - demand[t])
    end

    # Solve the model
    optimize!(model)

    # Retrieve and print the results
    println("Objective value: ", objective_value(model))
    println("Workers: ", round.(Int,value.(W)))
    println("Hired: ", round.(Int,value.(H)))
    println("Fired: ", round.(Int,value.(F)))
    println("Inventory: ", round.(Int,value.(I)))
    println("Production: ", round.(Int,value.(P)))

    #return result
    return objective_value(model),value.(W),value.(H),value.(F),value.(I),value.(P),T
end    

# add reactive code to make the UI interactive
@app begin
    # reactive variables are tagged with @in and @out
    @in c_H = 100
    @in c_F = 200
    @in c_I = 0.10

    @out t = ["Months","Weeks","Days"]
    @in selected_t = "Months"

    @out backlogging = ["Yes", "No"]
    @in selected_backlogging = "No"

    @in demand = [850, 1260, 510, 980, 770, 850, 1050, 1550, 1350, 1000, 970, 680]
    # watch a variable and execute a block of code when
    # its value changes
    @in msg = ""
    @in cost = 0
    @in W = []
    @in H = []
    @in F = []
    @in I = []
    @in P = []
    @in T = 0
    @onchange c_H , c_F , c_I, demand, fileuploads begin
        # the values of result and msg in the UI will
        # be automatically updated
        result = optimise(demand,c_H,c_F,c_I)
        cost = round(Int,result[1])
        W = result[2]
        H = result[3]
        F = result[4]
        I = result[5]
        P = result[6]
        T = result[7]

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
            data = CSV.read(joinpath(FILE_PATH,filename),DataFrame)
            demand = data[:,1] #convert 1 column of row into a DataFrame
        end
        upfiles = readdir(FILE_PATH)
    end
end 


# register a new route and the page that will be
# loaded on access
@page("/", "app.jl.html")
end