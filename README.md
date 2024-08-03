PROJECT TITLE: 
Worker and Inventory Management App

PROJECT DESCRIPTION:
For any company to profit from a product, there must be a strategic plan in place to produce just enough to meet that need. This plan is known as Aggregate Planning, where our web application utilises Gurobi optimiser to give the best resource allocation while minimising costs in a multi product, multi workcentre environment. 

PROCESS:
This web application takes in product demand forecast over a time horizon, a worker-product type matrix with values of the number of products per time period, an initial number of workers and products based on the .xlsx template found in the application. After inputting the necessary info, you can click optimise to view the various optimal resource allocations through the graphs. You can customise the costs and filter the graphs to your liking, before exporting your results over to another Results.xlsx file. The project is also hosted on JuliaHub for scaling and deployment in Cloud.

TOOLS USED:
- Backend & Programming Language: Julia
- Frontend : Genie Framework
- Deployment: JuliaHub
- Excel: Data Import

INSTALLATION:

Clone the repository and install the dependencies.

```bash
using Pkg

# List of packages to install
packages = [
    "GenieFramework",
    "JuMP",
    "Gurobi",
    "HiGHS",
    "CSV",
    "DataFrames",
    "XLSX",
    "Random",
    "Stipple",
    "StippleUI",
    "StippleDownloads",
    "Test"
]

# Install each package
for pkg in packages
    Pkg.add(pkg)
end

# Specific setup for Gurobi, as it might need license and environment variables set up
Pkg.build("Gurobi")
```

First `cd` into the project directory then run:

```bash
$> julia --project -e 'using Pkg; Pkg.instantiate()'
```


Finally, run the app

```bash
$> julia --project
```

```julia
julia> using GenieFramework
julia> Genie.loadapp() # load app
julia> up() # start server
```
Finally, open your browser and navigate to `http://localhost:8000/` to use the app. #9999 on Julia Hub

IMPORTANT NOTES:
- This app uses a WLS Academic Gurobi License which expires on September. 2024 Replace gurobi.lic with another valid WLS Academic license gurobi.lic to continue using the application after expiry period.

CREDITS:
- TAN YAN ZU, JOE
- ANG CHING XUEN
- LUCAS TAN
- NATALIE YEN GABRIEL
- MATTHEW ANDREI SALATIN PURBA
- SHERMAN KHO JUN HUI

SPECIAL ACKNOWLEDGEMENT TO GENIE BUILDER DEVELOPERS FOR PROVIDING GENIE LICENSE AND PROFESSOR RAKESH FOR HIS DOMAIN KNOWLEDGE ON MANUFACTURING OPERATIONS.


