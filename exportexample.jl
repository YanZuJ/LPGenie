using Stipple, Stipple.ReactiveTools
using StippleUI
using StippleDownloads

using DataFrames
using XLSX

import Stipple.opts
import StippleUI.Tables.table

#Download the libraries above in your julia app
#Feel free to run the julia code to see how the export button works

function df_to_xlsx(df)
    io = IOBuffer()
    XLSX.writetable(io, df)
    take!(io)
end

@app begin
    @out table = DataTable(DataFrame(:a => rand(1:10, 5), :b => rand(1:10, 5)))
    @in text = "The quick brown fox jumped over the ..."

    @event download_text begin
        download_text(__model__, :text)
    end

    @event download_df begin
        try
            download_binary(__model__, df_to_xlsx(table.data), "file.xlsx"; client = event["_client"])
        catch ex
            println(ex)
        end
    end
end

function ui()
    row(cell(class = "st-module", [

        row([
            cell(textfield(class = "q-pr-md", "Download text", :text, placeholder = "no output yet ...", :outlined, :filled, type = "textarea"))
            cell(table(class = "q-pl-md", :table))
        ])
              
        row([
            cell(col = 1, "Without client info")
            cell(btn("Text File", icon = "download", @on(:click, :download_text), color = "primary", nocaps = true))
            cell(col = 1, "With client info")
            cell(btn(class = "q-ml-lg", "Excel File", icon = "download", @on(:click, :download_df, :addclient), color = "primary", nocaps = true))
        ])
    ]))
end

@page("/", ui)

up(open_browser = true)