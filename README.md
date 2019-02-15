# Fibaro-Kevin-Mode
## Preparing the data
You have to be in the same local network as your Fibaro HC2 (SSH) to download the data. 
You have to specify proper HC2 login/password and IP address in the scripts. 
Start date defaults to epoch start time. 
End date defaults to current date and time. 

### Getting the data from Fibaro energy panel API, transforming to light events and saving to CSV file
<code>energyPanelToCsv.py -o 'outputfile' --startdate 'YYYY-mm-dd, HH:MM' --enddate 'YYYY-mm-dd, HH:MM'</code>

CSV will look like this

<pre>

        timestamp state  lightID           lightName  roomID      roomName  sectionID     sectionName
id                                                                                                   
20719  1514899843    on       62  Main bedroom light      12  Main Bedroom         10  Sleeping floor
20722  1514899883   off       62  Main bedroom light      12  Main Bedroom         10  Sleeping floor

</pre>

### Saving data from Fibaro Event Panel to JSON file
<code>"eventsPanelToJson.py -o <outputfile> -l <lightIds> --startdate <'YYYY-mm-dd, HH:MM'> --enddate <'YYYY-mm-dd, HH:MM'>"</code>

### Preparing a CSV
<code>FetchDataFromFibaro.py -s "fibaro/file" -i "inputfile" -o "outputfile" --startdate 'YYYY-mm-dd, HH:MM' --enddate 'YYYY-mm-dd, HH:MM'</code>

If file is the data source you have to specify input file name. 

CSV will look like this

<pre>
          timestamp  deviceID state  newValue
id                                           
1542022  1549428954       185    off     0.0
1542027  1549429033       414    on      99.0
1542090  1549429374       226    on      99.0
1542636  1549434015       167    on      15.0
1542656  1549434099        62    on      49.0
</pre>
