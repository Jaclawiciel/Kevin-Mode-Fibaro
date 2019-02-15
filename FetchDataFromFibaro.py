import sys, getopt
import numpy as np
import pandas as pd
import requests
import json
from datetime import datetime
from pytz import timezone
from calendar import timegm
from pprint import pprint

# Script for fetching data from Fibaro API events panel or from JSON file and saving it to CSV

HC2_IP = "192.168.1.15"
USERNAME = "admin"
PASSWORD = "admin"
DIMMER_TYPE = "com.fibaro.FGD212"
DATE_FORMAT_PRETTY = '%Y-%m-%d, %H:%M'


def getScriptArguments(argv):
	source = ''
	inputfile = ''
	outputfile = ''
	start_date_pretty = ''
	end_date_pretty = ''
	lightIds = ''

	try:
		opts, args = getopt.getopt(argv, "hs:i:o:l:", ["help", "source=", "inputfile=", "outputfile", "startdate=", "enddate=", "lightIds"])
	except getopt.GetoptError:
		print("FetchDataFromFibaro.py -s <fibaro/file> -i <inputfile> -o <outputfile> -l <lightIds> --startdate <'YYYY-mm-dd, HH:MM'> --enddate <'YYYY-mm-dd, HH:MM'>")
		sys.exit(2)
	for opt, arg in opts:
		if opt in ('-h', "--help"):
			print("FetchDataFromFibaro.py -s <fibaro/file> -i <inputfile> -o <outputfile> -l <lightIds> --startdate <'YYYY-mm-dd, HH:MM'> --enddate <'YYYY-mm-dd, HH:MM'>")
			sys.exit()
		elif opt in ("-s", "--source"):
			source = arg
		elif opt in ("-i", "--inputfile"):
			inputfile = arg
		elif opt in ("-o", "--outputfile"):
			outputfile = arg
		elif opt == "--startdate":
			start_date_pretty = arg
		elif opt == "--enddate":
			end_date_pretty = arg
		elif opt in ('-l', '--lightIds'):
			lightIds = arg

	if source not in ("fibaro", "file"):
		raise getopt.GetoptError("Wrong source! Please specify correct source...")
	if source == "file":
		if inputfile == '':
			raise getopt.GetoptError("Input file name missing!")
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
		"source": source,
		"input_file_name": inputfile,
		"output_file_name": outputfile,
		"start_date": start_date,
		"end_date": end_date,
		"lightIds": lightIds
	}


def getTimestamp(date):
	return timegm(date.utctimetuple())


def get_pretty_date(date):
	return date.strftime("%Y-%m-%d, %H:%M")


def save_to_file(file_name, data):
	try:
		file = open(file_name, "w")
		file.write(data)
	except FileNotFoundError as e:
		print(f"Could not open the file \'{arguments['input_file_name']}\'\n{e}")
		sys.exit(2)
	finally:
		file.close()


def get_json_from_file(file_name):
	json_data = ""
	try:
		json_file = open(arguments["input_file_name"], "rt")
		json_data = json.load(json_file)
	except FileNotFoundError as e:
		print(f"Could not open the file \'{arguments['input_file_name']}\'\n{e}")
		sys.exit(2)
	except json.JSONDecodeError as e:
		print(f"Could not decode JSON data from file \'{arguments['input_file_name']}\'\n{e}")
		sys.exit(2)
	finally:
		json_file.close()

	return json_data


arguments = getScriptArguments(sys.argv[1:])

start_date_timestamp = getTimestamp(arguments["start_date"])
end_date_timestamp = getTimestamp(arguments["end_date"])

print("Preparing lights usage data from Fibaro")
print(f"Start date: {get_pretty_date(arguments['start_date'])}\nEnd date: {get_pretty_date(arguments['end_date'])}")
print(20 * "-" + "\n")

events = ""
if arguments["source"] == "file":
	print(f"Loading JSON data from file {arguments['output_file_name']}...")
	events = get_json_from_file(arguments["input_file_name"])
elif arguments["source"] == "fibaro":
	print(f"Loading JSON data from Fibaro API ({API})...")
	json_data = requests.get(f'{API}?from={start_date_timestamp}&to={end_date_timestamp}', auth=(USERNAME, PASSWORD))
	events = json_data.json()

print("Data loading complete!")
print("Preparing data...")
events = pd.DataFrame(events, columns=['id', 'timestamp', 'deviceID', 'state', 'newValue', 'deviceType'])
events.set_index('id', inplace=True)
events.sort_index(inplace=True)
lights_only = events['deviceType'] == DIMMER_TYPE
start_timestamp_limited = events['timestamp'] >= start_date_timestamp
end_timestamp_limited = events['timestamp'] <= end_date_timestamp
events = events[lights_only][start_timestamp_limited][end_timestamp_limited]
events.loc[events.newValue > 0, 'state'] = "on"
events.loc[events.newValue == 0, 'state'] = "off"
events.drop("deviceType", axis=1, inplace=True)

print("Data ready!\n")
print(events.head())

print("Saving data to CSV...")
save_to_file(arguments['output_file_name'], events.to_csv())
print("Data saved!")
