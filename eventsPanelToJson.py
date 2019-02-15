import sys, getopt
import requests
from datetime import datetime
from pytz import timezone
from calendar import timegm

# Script for fetching data from Fibaro API events panel and saving it to JSON file

HC2_IP = "192.168.1.15"
API = f"http://{HC2_IP}/api/panels/event"
USERNAME = "admin"
PASSWORD = "admin"
DIMMER_TYPE = "com.fibaro.FGD212"
DATE_FORMAT_PRETTY = '%Y-%m-%d, %H:%M'


def get_script_arguments(argv):
	outputfile = ''
	start_date_pretty = ''
	end_date_pretty = ''

	try:
		opts, args = getopt.getopt(argv, "ho:", ["help", "outputfile", "startdate=", "enddate="])
	except getopt.GetoptError:
		print("eventsPanelToJson.py -o <outputfile> --startdate <'YYYY-mm-dd, HH:MM'> --enddate <'YYYY-mm-dd, HH:MM'>")
		sys.exit(2)
	for opt, arg in opts:
		if opt in ('-h', "--help"):
			print("eventsPanelToJson.py -o <outputfile> --startdate <'YYYY-mm-dd, HH:MM'> --enddate <'YYYY-mm-dd, HH:MM'>")
			sys.exit()
		elif opt in ("-o", "--outputfile"):
			outputfile = arg
		elif opt == "--startdate":
			start_date_pretty = arg
		elif opt == "--enddate":
			end_date_pretty = arg

	if outputfile == '':
		raise getopt.GetoptError("Output file name missing!")
	if start_date_pretty == '':
		start_date_pretty = '1970-01-01, 00:00'
	if end_date_pretty == '':
		end_date_pretty = datetime.now().strftime(DATE_FORMAT_PRETTY)

	try:
		start_date = datetime.strptime(start_date_pretty, DATE_FORMAT_PRETTY)
		start_date = timezone('Europe/Amsterdam').localize(start_date)
		end_date = datetime.strptime(end_date_pretty, DATE_FORMAT_PRETTY)
		end_date = timezone('Europe/Amsterdam').localize(end_date)
	except ValueError:
		print("Something went wrong with date parsing...")
		sys.exit(2)

	if start_date > end_date:
		raise ValueError(f"Start date ({start_date_pretty}) is after end date ({end_date_pretty})")
		sys.exit(2)

	return {
		"output_file_name": outputfile,
		"start_date": start_date,
		"end_date": end_date
	}


def get_timestamp(date):
	return timegm(date.utctimetuple())


def get_pretty_date(date):
	return date.strftime("%Y-%m-%d, %H:%M")


def save_json(file_name, data):
	try:
		json_file = open(file_name, "w")
		json_file.write(data)
	except FileNotFoundError as e:
		print(f"Could not open the file \'{arguments['input_file_name']}\'\n{e}")
		sys.exit(2)
	finally:
		json_file.close()


arguments = get_script_arguments(sys.argv[1:])

output_file = arguments["output_file_name"]
start_date = arguments["start_date"]
end_date = arguments["end_date"]
lightIds = arguments["lightIds"]
start_date_timestamp = get_timestamp(start_date)
end_date_timestamp = get_timestamp(end_date)


print("\n\nResponse from Fibaro - GET from Events Panel")
print(f"Start date: {get_pretty_date(start_date)}\nEnd date: {get_pretty_date(end_date)}")
print(20 * "-" + "\n")

events_panel_response = requests.get(f'{API}?from={start_date_timestamp}&to={end_date_timestamp}', auth=(USERNAME, PASSWORD))
events_data = events_panel_response.text

print("Request completed!\n")
print(f"Saving JSON response to file: {output_file}")
save_json(output_file, events_data)
print("File saved!")
print(20 * "-" + "\n")
