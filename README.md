## Project Title 
Worker and Inventory Management App

## Project Description
For any company to profit from a product, there must be a strategic plan in place to produce just enough to meet that need. This plan is known as Aggregate Planning, where our web application utilises an optimiser to give the best resource allocation while minimising costs in a multi product, multi workcentre environment. 

## Process
This web application takes in product demand forecast over a time horizon, a worker-product type matrix with values of the number of products per time period, an initial number of workers and products based on the .xlsx template found in the application. After inputting the necessary info, you can click optimise to view the various optimal resource allocations through the graphs. You can customise the costs and filter the graphs to your liking, before exporting your results over to another Results.xlsx file. The project is also hosted on JuliaHub online for scaling and deployment in Cloud.

## Tools Used
- Backend & Programming Language: Julia
- Frontend : Genie Framework
- Deployment: JuliaHub
- Excel: Data Import
- Gurobi: Optimisation Software

## Installation

If you're downloading from Github, clone the repository to a folder.

1. Please ensure you have Julia installed. Julia can be installed here: https://julialang.org/downloads/ 
On Julia itself, run the code below and install the dependencies.

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

2. First `cd` into the project directory in Julia by:

```bash
cd("C:\\file\\path\\to\\code\\LPGenie") #Note the double \\ and ("")
```

3. For Gurobi specifically, the GRB_LICENSE_FILE environment variable have to be pointed to the `gurobi.lic` file in LPGenie folder.

```bash
ENV["GRB_LICENSE_FILE"] = "C:\\file\\path\\to\\code\\LPGenie\\gurobi.lic"
```

4. Then instantiate the project of its dependencies by

```bash
using Pkg; Pkg.instantiate()
```

5. Finally, run the app

```julia
using GenieFramework
Genie.loadapp() # load app
up() # start server
```

To open the application again, please repeat steps 3-5
Open your browser and navigate to `http://localhost:8000/` to use the app. 

## Important Notes
- This app uses a WLS Academic Gurobi License which expires on September. 2024 Replace gurobi.lic with another valid WLS Academic license gurobi.lic to continue using the application after expiry period.
- This folder includes a UploadTemplateFinal.xlsx which contains test data to upload into the application.
- This web application allows you to deploy online and it will be accessible via a link on JuliaHub. When deploying, **charges will apply.** Our JuliaHub repsository can be found here: https://juliahub.com/ui/Projects/b3766e7a-9051-4568-99de-dadd00abc8e4/138840a2-88ef-4f32-b6e8-a4951841a968.
To deploy, switch to Source -> Connect. **Ensure you have input your payment details in JuliaHub before deploying.**
- This folder includes trialangela.ipynb and trialjoe.ipynb as backend workings for our testings. You may ignore these files
  
## Credits
- Tan Yan Zu, Joe
- Ang Ching Xuen
- Lucas Tan
- Natalie Yen Gabriel
- Matthew Andrew Salatin Purba
- Sherman Kho Jun Hui

Special Acknowledgement to Genie Builder Developments for giving EDU Licenses to build the frontend of our project, and both Professor Zeyu and Rakesh for their knowledge and expertise in Systems Design and Manufacturing Operations respectively. This project is part of Term 5 Engineering Systems Architecture module in Singapore University of Technology and Design 2024.


